-- Mission de jour du 25/11/2026 (Claude), bloc 2 — APPLIQUÉE en production le 25/11/2026 au soir (feu vert de Fred, contrôlée en lecture).
-- CHRONIQUE DE L'EMPIRE (décision de Fred, 25/11/2026) : le journal des événements s'ouvre sur deux onglets, « Mes événements »
-- (le journal actuel) et « L'empire » : la chronique publique du pays du joueur (sa nationalité), comme les faits divers et la
-- vie publique. Lue côté serveur, filtrée par pays, de la plus récente à la plus ancienne. Elle ne révèle rien qu'un joueur ne
-- puisse savoir. Comptes de test exclus.
--
-- AUCUNE ÉCRITURE NOUVELLE : chronique_empire_lire() compose la chronique à la lecture, depuis les sources qui existent déjà.
--   • actes illégaux connus (crim_affaires) : détectés, ou portés en plainte, ou rumeur (une rumeur circule par nature) ;
--   • arrestations (detentions) ; verdicts (jugements) ; affaires transmises au tribunal par la police (plaintes_en_cours,
--     origine « police » : déjà annoncées sur le forum du tribunal) ;
--   • faits publics déjà consignés (chronique_nationale : décisions, conférences, subventions, élections, Assemblée, actes de
--     procédure publics — audiences, condamnations… via justice_faits_publics) ;
--   • incidents climatiques commencés (climat_evenements alertés, non annulés) ;
--   • bagarres terminées (batailles hors faune) ; rencontres avec l'ours, le loup ou la meute en forêt (sovarka_foret_rencontres).
-- ANONYMAT : l'auteur d'un acte n'apparaît que s'il est publiquement connu POUR CET ACTE : affaire identifiée, ou arrestation ou
-- jugement qui citent cette affaire (sa plainte). Jamais un indice partiel : sinon, « auteur » est NULL. Un arrêté, un jugé ou
-- un mis en cause transmis au tribunal est nommé (c'est public). Les victimes ne sont pas nommées (sauf la cible d'une rumeur,
-- qui circule avec elle). Les bagarres et les rencontres en forêt sont anonymes.
-- Le texte est composé par l'écran (phrases courtes, plateau-chronique-empire.js) à partir des faits rendus ici.
-- Sans cette migration, l'onglet « L'empire » n'apparaît pas (aucune erreur pour le joueur).
--
-- Contrôles en lecture après application :
--   SELECT has_function_privilege('authenticated', 'public.chronique_empire_lire(timestamptz,integer)', 'EXECUTE');  -- vrai
--   SELECT has_function_privilege('anon', 'public.chronique_empire_lire(timestamptz,integer)', 'EXECUTE');           -- faux
--   SELECT position('chronique_empire_v1' in pg_get_functiondef('public.chronique_empire_lire(timestamptz,integer)'::regprocedure)) > 0;  -- vrai
BEGIN;

-- Un acte criminel est-il publiquement attribué à son auteur ? (affaire identifiée, ou arrestation / jugement qui la citent)
CREATE OR REPLACE FUNCTION public.chronique_auteur_public_interne(c public.crim_affaires)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT c.auteur IS NOT NULL AND (coalesce(c.identifie, false)
      OR (c.plainte_id IS NOT NULL AND (
           EXISTS (SELECT 1 FROM public.detentions d WHERE d.nom = c.auteur AND coalesce(d.motifs::text, '') LIKE '%"' || c.plainte_id || '"%')
        OR EXISTS (SELECT 1 FROM public.jugements j WHERE j.accuse = c.auteur AND coalesce(j.data::text, '') LIKE '%"' || c.plainte_id || '"%')))) /* chronique_empire_v1 */
$function$;

CREATE OR REPLACE FUNCTION public.chronique_empire_lire(p_avant timestamptz DEFAULT NULL, p_limite integer DEFAULT 40)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); v_pays text; v_depuis timestamptz := now() - interval '30 days';
        v_avant timestamptz := coalesce(p_avant, now() + interval '1 minute'); v_n integer := greatest(1, least(coalesce(p_limite, 40), 100));
        v_liste jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(public.personnage_nationalite(a), d.country) INTO v_pays FROM public.personnages_donnees d WHERE d.name = a;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu'); END IF;

  WITH faits AS (
    -- Actes illégaux connus.
    SELECT c.cree_le AS quand, 'acte'::text AS cat, c.acte AS cle, c.ville, c.batiment, c.piece,
           CASE WHEN public.chronique_auteur_public_interne(c) THEN c.auteur END AS auteur,
           jsonb_build_object('cible', CASE WHEN c.acte LIKE '%rumeur%' THEN coalesce(c.cible, c.cible_pnj) END, 'issue', c.issue) AS params,
           'acte-' || c.id AS ref
      FROM public.crim_affaires c
     WHERE c.pays = v_pays AND c.cree_le >= v_depuis AND c.cree_le < v_avant
       AND (coalesce(c.detecte, false) OR c.plainte_id IS NOT NULL OR c.acte LIKE '%rumeur%')
       AND NOT public.est_compte_test(c.auteur) AND NOT public.est_compte_test(c.cible)
    UNION ALL
    -- Arrestations.
    SELECT d.created_at, 'arrestation', CASE WHEN d.qhs THEN 'qhs' ELSE 'prison' END, d.city, NULL, NULL, d.nom,
           jsonb_build_object('motif', d.raison), 'arrestation-' || d.id
      FROM public.detentions d
     WHERE d.country = v_pays AND d.created_at >= v_depuis AND d.created_at < v_avant AND NOT public.est_compte_test(d.nom)
    UNION ALL
    -- Verdicts.
    SELECT j.created_at, 'verdict', 'jugement', j.city, 'tribunal', NULL, j.accuse,
           jsonb_build_object('motif', j.motif, 'peine', j.peine), 'verdict-' || j.id
      FROM public.jugements j
     WHERE j.country = v_pays AND j.created_at >= v_depuis AND j.created_at < v_avant AND NOT public.est_compte_test(j.accuse)
    UNION ALL
    -- Affaires transmises au tribunal par la police (annoncées sur le forum du tribunal).
    SELECT p.created_at, 'proces', 'affaire_transmise', coalesce(p.city, 'capitale'), 'tribunal', NULL, p.data::jsonb ->> 'cible',
           jsonb_build_object('motif', p.data::jsonb ->> 'motif'), 'proces-' || p.id
      FROM public.plaintes_en_cours p
     WHERE p.country = v_pays AND p.created_at >= v_depuis AND p.created_at < v_avant AND p.data IS JSON OBJECT
       AND p.data::jsonb ->> 'origine' = 'police' AND NOT public.est_compte_test(p.data::jsonb ->> 'cible')
    UNION ALL
    -- Faits publics déjà consignés (décisions, procès, élections…).
    SELECT n.created_at, 'public', n.type, n.city, NULL, NULL, NULL, jsonb_build_object('texte', n.libelle), 'public-' || n.id
      FROM public.chronique_nationale n
     WHERE n.country = v_pays AND n.created_at >= v_depuis AND n.created_at < v_avant AND nullif(btrim(n.libelle), '') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(CASE WHEN jsonb_typeof(n.personnages) = 'array' THEN n.personnages ELSE '[]'::jsonb END) x
                        WHERE public.est_compte_test(x))
    UNION ALL
    -- Incidents climatiques commencés.
    SELECT e.debut, 'climat', e.type, e.ville, NULL, NULL, NULL, '{}'::jsonb, 'climat-' || e.id
      FROM public.climat_evenements e
     WHERE e.pays = v_pays AND NOT e.annule AND e.alerte_le IS NOT NULL AND e.debut <= now() AND e.debut >= v_depuis AND e.debut < v_avant
    UNION ALL
    -- Bagarres (anonymes).
    SELECT b.debut_ts, 'bagarre', 'bagarre', b.ville, b.batiment, b.piece, NULL, jsonb_build_object('issue', b.issue), 'bagarre-' || b.id
      FROM public.batailles b
     WHERE b.pays = v_pays AND b.statut = 'terminee' AND b.debut_ts >= v_depuis AND b.debut_ts < v_avant
       AND coalesce(b.contexte ->> 'type', b.contexte ->> 'source', '') <> 'faune'
       AND NOT public.est_compte_test(b.leader_a) AND NOT public.est_compte_test(b.leader_b)
    UNION ALL
    -- Rencontres avec l'ours, le loup ou la meute dans la forêt de Krasnov (anonymes).
    SELECT r.cree_le, 'foret', r.creature, 'ville_b', 'zone-production', NULL, NULL, jsonb_build_object('issue', r.statut), 'foret-' || r.id
      FROM public.sovarka_foret_rencontres r
     WHERE v_pays = 'soviet' AND r.creature IN ('ours', 'loup', 'meute') AND r.cree_le >= v_depuis AND r.cree_le < v_avant
       AND NOT public.est_compte_test(r.bucheron)
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('quand', f.quand, 'cat', f.cat, 'cle', f.cle, 'ville', f.ville, 'batiment', f.batiment,
           'piece', f.piece, 'auteur', f.auteur, 'params', jsonb_strip_nulls(f.params), 'ref', f.ref) ORDER BY f.quand DESC, f.ref), '[]'::jsonb)
    INTO v_liste
    FROM (SELECT * FROM faits ORDER BY quand DESC, ref LIMIT v_n) f;
  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'faits', v_liste); /* chronique_empire_v1 */
END $function$;

REVOKE ALL ON FUNCTION public.chronique_auteur_public_interne(public.crim_affaires) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.chronique_empire_lire(timestamptz, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chronique_empire_lire(timestamptz, integer) TO authenticated;

COMMIT;
