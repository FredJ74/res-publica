-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927174800
-- Nom original      : socle_pnj_contre_espionnage_dup_au_socle
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 17:48:00 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 42be61590991f49511aa69539c0325fd
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CONVERGENCE RENSEIGNEMENT, ETAPE 5 (suite) — LE CONTRE-ESPIONNAGE LIT LA DUP AU SOCLE
--
-- Seul changement : la DUP de l'agent vient de pnj_membres.car_dup au lieu de la colonne metier.
-- La FORMULE est intacte -- contre_espionnage_modificateur(PER_instructeur, DUP_agent, IS_national),
-- soit 3*(PER - DUP) + (IS - 50)/2 -- et la PER de l'instructeur continue de venir de sa fiche.
-- COALESCE sur l'ancienne colonne : une ligne non raccordee se comporte exactement comme avant.
--
-- L'IDENTITE REELLE N'EST PAS DAVANTAGE EXPOSEE. `vrai_nom` etait deja lu ici, et il ne part pas au
-- client : il est transmis a contre_espionnage_memoriser, qui decide selon le PALIER atteint ce que
-- le contre-espionnage a le droit de savoir. Ce chemin est inchange.
CREATE OR REPLACE FUNCTION public.contre_espionnage_resoudre(
  p_pays text, p_couverture text, p_instructeur text, p_ref text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  v_ag record; v_per numeric; v_is numeric;
  v_mod integer; v_de integer; v_score integer; v_palier integer;
  v_avant integer; v_apres integer;
BEGIN
  SELECT COALESCE(m.car_dup, ag.dup) AS dup, ag.vrai_nom, ag.nom_couverture, c.pays_proprietaire
    INTO v_ag
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN public.pnj_membres m ON m.id = ag.pnj_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE pe.pays IS NOT DISTINCT FROM p_pays
     AND ag.nom_couverture = p_couverture
     AND ag.statut IN ('actif', 'detenu')
     AND c.statut = 'active';
  IF v_ag.dup IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_agent');
  END IF;

  SELECT public.assemblee_stat_base(d.stats, 'PER') INTO v_per
    FROM public.personnages_donnees d WHERE d.name = p_instructeur;
  v_per := coalesce(v_per, 8);
  v_is  := public.is_national(p_pays);

  v_mod    := public.contre_espionnage_modificateur(v_per, v_ag.dup, v_is);
  v_de     := floor(random() * 100)::integer + 1;
  v_score  := greatest(0, least(100, v_de + v_mod));
  v_palier := public.contre_espionnage_palier(v_score);

  v_avant := public.contre_espionnage_niveau_connu(p_pays, p_couverture);
  v_apres := public.contre_espionnage_memoriser(p_pays, p_couverture, v_palier,
               v_ag.vrai_nom, v_ag.pays_proprietaire, p_instructeur, p_ref);

  RETURN jsonb_build_object('ok', true, 'score', v_score, 'palier', v_palier,
    'niveau_avant', v_avant, 'niveau', v_apres,
    'progression', v_apres > v_avant);
END; $$;

-- COMPARATEUR DE LA FAMILLE. Il verifie ce que le socle doit garantir, et SEULEMENT cela : quatre
-- identites, un profil unique, la classe, la propriete institutionnelle, le raccordement de chaque
-- occurrence de mission, et l'alignement de la DUP des missions ACTIVES sur le socle. Il ne compare
-- pas la position : elle n'est pas basculee, et un comparateur qui verifierait un axe non bascule
-- mentirait sur ce qu'il prouve.
CREATE OR REPLACE FUNCTION public.pnj_comparer_agents()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_div jsonb; v_prof jsonb; v_nb integer;
BEGIN
  v_prof := public.pnj_metier_profil('agent');
  SELECT count(*) INTO v_nb FROM public.pnj_membres WHERE famille = 'agent' AND statut = 'actif';

  WITH attendu AS (SELECT i.role, i.vrai_nom FROM public.renseignement_identites_reelles i),
  socle AS (SELECT m.* FROM public.pnj_membres m WHERE m.famille = 'agent'),
  cmp AS (
    SELECT COALESCE(a.role, replace(s.id, 'agent-', '')) AS role,
      CASE
        WHEN s.id IS NULL THEN 'identite_absente_du_socle'
        WHEN a.role IS NULL THEN 'surnumeraire_au_socle'
        WHEN s.nom IS DISTINCT FROM a.vrai_nom THEN 'nom_reel'
        WHEN s.classe IS DISTINCT FROM 'beta' THEN 'classe'
        WHEN public.pnj_caracteristiques_base(s.id) IS DISTINCT FROM v_prof THEN 'profil'
        WHEN s.proprietaire_institution IS DISTINCT FROM 'renseignement' THEN 'institution'
        WHEN s.pa IS DISTINCT FROM 12 THEN 'pa'
        ELSE NULL END AS divergence
      FROM attendu a FULL OUTER JOIN socle s
        ON s.id = public.renseignement_pnj_id(a.role))
  SELECT COALESCE(jsonb_agg(jsonb_build_object('role', role, 'divergence', divergence)
           ORDER BY role) FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_div FROM cmp;

  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_div) = 0 AND v_nb = 4
          AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement WHERE pnj_id IS NULL)
          AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                            JOIN public.pnj_membres m ON m.id = a.pnj_id
                           WHERE a.statut = 'actif' AND a.dup IS DISTINCT FROM m.car_dup),
    'identites_au_socle', v_nb, 'attendues', 4,
    'profil', v_prof, 'divergences', v_div,
    'occurrences_de_mission', (SELECT count(*) FROM public.agents_renseignement),
    'missions_non_raccordees', (SELECT count(*) FROM public.agents_renseignement WHERE pnj_id IS NULL),
    'missions_actives', (SELECT count(*) FROM public.agents_renseignement WHERE statut = 'actif'),
    'dup_active_desalignee', (SELECT count(*) FROM public.agents_renseignement a
                                JOIN public.pnj_membres m ON m.id = a.pnj_id
                               WHERE a.statut = 'actif' AND a.dup IS DISTINCT FROM m.car_dup),
    'observation_axe_position', (SELECT autorite FROM public.pnj_axes_autorite
                                  WHERE famille = 'agent' AND axe = 'position_leader'));
END; $$;

REVOKE ALL ON FUNCTION public.pnj_comparer_agents()           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.renseignement_pnj_id(text)      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.renseignement_autorite_de_perimetre(text, text)
  FROM PUBLIC, anon, authenticated;