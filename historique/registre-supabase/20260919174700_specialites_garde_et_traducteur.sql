-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919174700
-- Nom original      : specialites_garde_et_traducteur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:47:00 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 0ecc88625868bb3ba26579e77fc760bd
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
-- SPECIALITES — Garde du corps (Boris Ketou) et Traducteur (Raymond Hialiste).
--
-- OU VIVENT LES FAITS COLLECTES : renseignements_connus, titulaire
-- 'cellule:<id>'. Meme convention que 'etat:<pays>' deja livree au lot 1 :
-- colonne texte libre, aucune table nouvelle, et l'index (titulaire,
-- jour_expiration) rend l'agregation du rapport quotidien immediate.
-- La DEDUPLICATION se fait sur fait_objectif_ref, qui est exactement le champ
-- prevu pour cela par la migration d'origine -- « nouvelle information » a donc
-- un sens precis et verifiable : aucune ligne de cette cellule ne porte deja
-- cette reference.
--
-- REGLE COMMUNE : une collecte sans information nouvelle ne produit AUCUN
-- risque de trace. agent_trace_deposer n'est appele que si au moins un fait a
-- reellement ete enregistre.

-- --------------------------------------------------------------------------
-- D. GARDE DU CORPS — renseignement militaire de terrain, automatique.
-- Reconnaissance canonique 75. Meme ville uniquement. Pas de radar national.
-- REUTILISE le moteur militaire existant, sans en creer un second :
-- militaire_camouflage_groupe, militaire_chance_detection,
-- militaire_modif_distance, militaire_degrader.
-- Difference assumee avec militaire_observer : ni guerre active ni jumelles
-- exigees -- l'operation de renseignement ne requiert pas la guerre (GD), et un
-- agent sous couverture ne porte pas de jumelles de campagne.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.agent_garde_observer(p_agent_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_reco constant numeric := 75;
  a record; r record;
  v_bande text; v_modif integer; v_camo numeric; v_chance integer; v_jet integer;
  v_ref text; v_deg jsonb; v_nb integer := 0;
BEGIN
  SELECT ag.*, c.statut AS statut_cellule, c.pays_proprietaire, c.id AS cel
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id AND ag.role = 'garde';
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.leader_courant IS NOT NULL OR a.ville IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_non_pose'); END IF;

  FOR r IN
    SELECT c.data->>'pays' AS pays_cible,
           sol->>'ville' AS ville, sol->>'buildingId' AS bat,
           count(*)::integer AS effectif,
           avg(coalesce((sol->'formation'->>'reconnaissance')::numeric, 0)) AS reco_moy,
           count(*) FILTER (WHERE EXISTS (
             SELECT 1 FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) ac
              WHERE ac->>'produitMilitaire' = 'tenue_camouflage'))::integer AS equipes
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE c.data->>'pays' IS DISTINCT FROM a.pays_proprietaire   -- jamais ses propres forces
       AND coalesce(sol->>'ville','') = a.ville                   -- MEME VILLE uniquement
     GROUP BY 1, 2, 3
  LOOP
    v_bande := public.militaire_bande_distance(a.pays_couverture, a.ville, a.building_id,
                                               a.pays_couverture, r.ville, r.bat);
    v_modif := public.militaire_modif_distance(v_bande);
    IF v_modif IS NULL THEN CONTINUE; END IF;                     -- hors portee
    v_camo   := public.militaire_camouflage_groupe(r.reco_moy, r.effectif, r.equipes);
    v_chance := public.militaire_chance_detection(c_reco, v_camo, v_modif, 0);
    v_jet    := floor(random() * 100)::integer + 1;               -- RNG SERVEUR
    CONTINUE WHEN v_jet > v_chance;                               -- echec : RIEN, aucune trace

    v_ref := 'forces:' || r.pays_cible || ':' || r.ville || ':' || coalesce(r.bat, '-')
             || ':' || (now() AT TIME ZONE 'Europe/Paris')::date;
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.renseignements_connus rc
                           WHERE rc.titulaire = 'cellule:' || a.cel
                             AND rc.fait_objectif_ref = v_ref);

    -- L'information est DEGRADEE a l'ecriture par le moteur existant : les
    -- effectifs exacts ne quittent jamais la base.
    v_deg := public.militaire_degrader(v_bande, r.effectif, r.pays_cible, r.ville, r.bat);

    INSERT INTO public.renseignements_connus
      (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
       fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
    VALUES ('rg_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' ||
            substr(md5(random()::text), 1, 8),
            'cellule:' || a.cel,
            'Forces reperees a ' || r.ville ||
            coalesce(' (' || (v_deg->>'batiment') || ')', '') || ' : ' ||
            (v_deg->>'libelle') || ' — ' ||
            CASE WHEN (v_deg->>'nationalite_sure')::boolean THEN (v_deg->>'nationalite')
                 ELSE 'nationalite incertaine' END || '.',
            r.pays_cible, 'renseignement_militaire', a.nom_couverture, 'observation',
            v_ref, 0, 0, 2147483647);
    v_nb := v_nb + 1;
  END LOOP;

  IF v_nb > 0 THEN PERFORM public.agent_trace_deposer(p_agent_id); END IF;
  RETURN jsonb_build_object('ok', true, 'faits', v_nb);
END;
$function$;

-- --------------------------------------------------------------------------
-- A. TRADUCTEUR — ecoute des traces/rumeurs VRAIES de sa ville.
-- Fenetre : les 7 derniers jours, portee exactement par jour_expiration
-- (toute trace est ecrite avec jour + 7). Il peut donc apprendre des faits
-- ANTERIEURS a son arrivee, tant qu'ils sont encore dans la fenetre.
-- Maximum 3 nouveaux renseignements par jour, et AUCUNE garantie : s'il n'y a
-- rien d'exploitable, il rapporte 0. Jamais de rumeur de remplissage.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.agent_traducteur_ecouter(p_agent_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_max constant integer := 3;
  a record; t record; v_jour integer; v_nb integer := 0; v_ref text;
BEGIN
  SELECT ag.*, c.statut AS statut_cellule, c.id AS cel
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id AND ag.role = 'traducteur';
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.leader_courant IS NOT NULL OR a.ville IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_non_pose'); END IF;

  v_jour := public.jour_de_jeu_pays(a.pays_couverture);

  FOR t IN
    SELECT at.id, at.auteur, at.cible, at.type_action, at.jour
      FROM public.actions_tracables at
     WHERE at.country = a.pays_couverture
       AND at.city = a.ville                       -- sa ville, rien d'autre
       AND at.jour_expiration >= v_jour            -- fenetre de 7 jours
       AND at.auteur <> a.nom_couverture           -- jamais ses propres traces
       AND NOT EXISTS (SELECT 1 FROM public.renseignements_connus rc
                        WHERE rc.titulaire = 'cellule:' || a.cel
                          AND rc.fait_objectif_ref = 'actions_tracables:' || at.id)
     -- Ponderation par RECENCE, comme poidsRecence du moteur existant : une
     -- trace plus recente sort plus souvent, sans qu'aucune ne soit exclue.
     ORDER BY random() * (1 + (at.jour::numeric / greatest(v_jour, 1))) DESC
     LIMIT c_max
  LOOP
    v_ref := 'actions_tracables:' || t.id;
    INSERT INTO public.renseignements_connus
      (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
       fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
    VALUES ('rt_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' ||
            substr(md5(random()::text), 1, 8),
            'cellule:' || a.cel,
            'On rapporte a ' || a.ville || ' que ' || t.auteur || ' serait implique dans : '
              || t.type_action || coalesce(' (vise : ' || t.cible || ')', '') || '.',
            t.auteur, 'rumeur_locale', a.nom_couverture, 'observation',
            v_ref, 0, 0, 2147483647);
    v_nb := v_nb + 1;
  END LOOP;

  IF v_nb > 0 THEN PERFORM public.agent_trace_deposer(p_agent_id); END IF;
  RETURN jsonb_build_object('ok', true, 'faits', v_nb);
END;
$function$;

REVOKE ALL ON FUNCTION public.agent_garde_observer(text)      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.agent_traducteur_ecouter(text)  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.agent_garde_observer(text)     TO service_role;
GRANT EXECUTE ON FUNCTION public.agent_traducteur_ecouter(text) TO service_role;
