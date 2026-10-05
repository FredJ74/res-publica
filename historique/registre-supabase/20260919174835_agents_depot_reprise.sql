-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919174835
-- Nom original      : agents_depot_reprise
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:48:35 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 93b83d8597954ce17907660ec6ccc5fe
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
-- DEPOT / REPRISE D'UN AGENT PAR UN PJ CHEF DE GROUPE.
--
-- REUTILISATION DU CONTRAT EXISTANT, pas d'un second systeme : exactement les
-- deux etats des soldats PNJ. Un agent SUIT un chef (leader_courant renseigne,
-- position vide, position effective derivee du chef) OU il est POSE
-- (leader_courant vide, position renseignee). Il ne se deplace jamais seul, et
-- ne se teleporte jamais vers la cellule ou le ministere.
--
-- QUI PEUT LE DEPLACER : un PJ de l'EMPIRE PROPRIETAIRE de la cellule. Un
-- joueur etranger ne sait meme pas que c'est un agent -- lui permettre de
-- l'emporter n'aurait aucun sens. Decision technique, aisement elargie.
--
-- Un agent detenu, mort ou disparu ne peut evidemment pas etre repris.

CREATE OR REPLACE FUNCTION public.agent_prendre(p_agent_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT country, current_city, current_building, current_room INTO d
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT ag.*, c.pays_proprietaire, c.statut AS statut_cellule INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id FOR UPDATE;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cellule_inactive'); END IF;
  IF a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_indisponible', 'statut', a.statut); END IF;
  IF d.country IS DISTINCT FROM a.pays_proprietaire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_empire'); END IF;
  IF a.leader_courant IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_en_groupe', 'leader', a.leader_courant); END IF;

  -- Il faut etre PHYSIQUEMENT la ou l'agent se trouve pour le prendre.
  IF d.current_city IS DISTINCT FROM a.ville
     OR d.current_building IS DISTINCT FROM a.building_id
     OR d.current_room IS DISTINCT FROM a.room_id THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit');
  END IF;

  UPDATE public.agents_renseignement
     SET leader_courant = v_moi, ville = NULL, building_id = NULL, room_id = NULL, maj_le = now()
   WHERE id = p_agent_id;
  RETURN jsonb_build_object('ok', true, 'agent', p_agent_id, 'leader', v_moi);
END;
$function$;

CREATE OR REPLACE FUNCTION public.agent_deposer(p_agent_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT country, current_city, current_building, current_room INTO d
    FROM public.personnages_donnees WHERE name = v_moi;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_indefinie'); END IF;

  SELECT ag.*, c.statut AS statut_cellule INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id FOR UPDATE;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.leader_courant IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_agent'); END IF;
  IF a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_indisponible', 'statut', a.statut); END IF;

  -- Depose a la position REELLE du chef. Il y reste, immobile, jusqu'a ce qu'un
  -- PJ vienne le reprendre.
  UPDATE public.agents_renseignement
     SET leader_courant = NULL, ville = d.current_city,
         building_id = d.current_building, room_id = d.current_room, maj_le = now()
   WHERE id = p_agent_id;
  RETURN jsonb_build_object('ok', true, 'agent', p_agent_id,
    'ville', d.current_city, 'batiment', d.current_building, 'piece', d.current_room);
END;
$function$;

-- Ce que le chef porte avec lui (pour l'interface du groupe).
CREATE OR REPLACE FUNCTION public.agents_de_mon_groupe()
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', ag.id, 'couverture', ag.nom_couverture, 'role', ag.role, 'statut', ag.statut)
           ORDER BY ag.role), '[]'::jsonb)
    INTO v_res FROM public.agents_renseignement ag
   WHERE ag.leader_courant = v_moi;
  RETURN jsonb_build_object('ok', true, 'agents', v_res);
END;
$function$;

-- Le garde interroge desormais la distance avec le VRAI pays des forces
-- observees : depuis le correctif positionnel, cela donne la bonne bande meme
-- entre nations differentes, et ne depend plus d'un contournement.
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
     WHERE c.data->>'pays' IS DISTINCT FROM a.pays_proprietaire
       AND coalesce(sol->>'ville','') = a.ville
     GROUP BY 1, 2, 3
  LOOP
    v_bande := public.militaire_bande_distance(a.pays_couverture, a.ville, a.building_id,
                                               r.pays_cible, r.ville, r.bat);
    v_modif := public.militaire_modif_distance(v_bande);
    IF v_modif IS NULL THEN CONTINUE; END IF;
    v_camo   := public.militaire_camouflage_groupe(r.reco_moy, r.effectif, r.equipes);
    v_chance := public.militaire_chance_detection(c_reco, v_camo, v_modif, 0);
    v_jet    := floor(random() * 100)::integer + 1;
    CONTINUE WHEN v_jet > v_chance;

    v_ref := 'forces:' || r.pays_cible || ':' || r.ville || ':' || coalesce(r.bat, '-')
             || ':' || (now() AT TIME ZONE 'Europe/Paris')::date;
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.renseignements_connus rc
                           WHERE rc.titulaire = 'cellule:' || a.cel
                             AND rc.fait_objectif_ref = v_ref);

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

REVOKE ALL ON FUNCTION public.agent_prendre(text)          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.agent_deposer(text)          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.agents_de_mon_groupe()       FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.agent_prendre(text)        TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.agent_deposer(text)        TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.agents_de_mon_groupe()     TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.agent_garde_observer(text)    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.agent_garde_observer(text) TO service_role;
