-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918151610
-- Nom original      : combat_engagement_et_decisions
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 15:16:10 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 52148f57efb224d7327b89d36d948fde
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
-- =========================================================================================
-- OUVERTURE D'UNE BATAILLE (19 septembre 2026)
-- =========================================================================================
-- Le roster est construit a partir des POSITIONS CANONIQUES : personne n'est declare par le
-- navigateur. Un combattant entre dans la bataille s'il est REELLEMENT dans la piece, appartient
-- a l'un des deux camps, et dispose d'au moins 1 PA -- a 0 PA il est deja hors de combat, par
-- definition du moteur.
--
-- INITIATIVE : 'simultane' si un contact mutuel non consomme existe pour cette zone (les deux
-- camps se sont vus), 'a' sinon -- l'attaquant qui engage sans contact mutuel beneficie donc de
-- la surprise, exactement comme le decrit le cas A de la detection passive.
CREATE OR REPLACE FUNCTION public.militaire_bataille_engager()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_moi text; a record; v_camp_b text; v_id bigint; v_contact bigint;
  v_init text; v_na integer; v_nb integer; v_leader_b text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT country, current_city, current_building, current_room, pa INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  IF a.country IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.services_militaires
                  WHERE personnage = v_moi AND fin_ts IS NULL) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_militaire');
  END IF;

  IF EXISTS (SELECT 1 FROM public.batailles WHERE statut = 'en_cours'
              AND pays = a.country AND ville = a.current_city
              AND batiment = a.current_building AND piece = a.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_deja_en_cours');
  END IF;

  -- Camp adverse : un pays EN GUERRE avec le mien ayant des soldats reellement poses ici.
  SELECT c.data->>'pays' INTO v_camp_b
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE c.data->>'pays' IS DISTINCT FROM a.country
     AND sol->>'ville' = a.current_city AND sol->>'buildingId' = a.current_building
     AND sol->>'roomId' = a.current_room AND (sol->>'leaderCourant') IS NULL
     AND EXISTS (SELECT 1 FROM public.guerres g WHERE g.statut = 'active'
                  AND ((g.data->>'attaquant' = a.country AND g.data->>'attaque' = c.data->>'pays')
                    OR (g.data->>'attaque'  = a.country AND g.data->>'attaquant' = c.data->>'pays')))
   LIMIT 1;
  IF v_camp_b IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_ennemi_ici'); END IF;

  SELECT id INTO v_contact FROM public.contacts_militaires
   WHERE consomme_le IS NULL AND ville = a.current_city AND batiment = a.current_building
     AND ((pays_a = a.country AND pays_b = v_camp_b) OR (pays_a = v_camp_b AND pays_b = a.country))
   ORDER BY etabli_le DESC LIMIT 1;
  v_init := CASE WHEN v_contact IS NOT NULL THEN 'simultane' ELSE 'a' END;

  INSERT INTO public.batailles (pays, ville, batiment, piece, camp_a, camp_b, initiative,
                                leader_a, contact_id, statut, round_courant)
  VALUES (a.country, a.current_city, a.current_building, a.current_room, a.country, v_camp_b,
          v_init, v_moi, v_contact, 'en_cours', 0)
  RETURNING id INTO v_id;

  PERFORM public.militaire_bataille_recruter(v_id, a.country, a.current_city, a.current_building, a.current_room);
  PERFORM public.militaire_bataille_recruter(v_id, v_camp_b, a.current_city, a.current_building, a.current_room);

  SELECT count(*) INTO v_na FROM public.militaire_bataille_combattants(v_id, a.country);
  SELECT count(*) INTO v_nb FROM public.militaire_bataille_combattants(v_id, v_camp_b);
  IF v_na = 0 OR v_nb = 0 THEN
    DELETE FROM public.batailles WHERE id = v_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'effectif_insuffisant',
      'mon_camp', v_na, 'adverse', v_nb);
  END IF;

  -- Leader adverse : un PJ militaire de ce camp present ici, s'il y en a un. Un camp peut n'en
  -- avoir aucun -- il combattra alors entierement sur doctrine.
  SELECT e.personnage INTO v_leader_b FROM public.batailles_engagements e
   WHERE e.bataille_id = v_id AND e.camp = v_camp_b AND e.personnage IS NOT NULL LIMIT 1;

  UPDATE public.batailles
     SET effectif_initial_a = v_na, effectif_initial_b = v_nb, leader_b = v_leader_b,
         repli_a = public.militaire_position_repli(v_moi, a.current_city, a.current_building, a.current_room),
         repli_b = public.militaire_position_repli(v_leader_b, a.current_city, a.current_building, a.current_room)
   WHERE id = v_id;

  IF v_contact IS NOT NULL THEN
    UPDATE public.contacts_militaires SET consomme_le = now(), bataille_id = v_id WHERE id = v_contact;
  END IF;

  RETURN jsonb_build_object('ok', true, 'bataille_id', v_id, 'initiative', v_init,
    'mon_camp', a.country, 'camp_adverse', v_camp_b, 'mon_effectif', v_na, 'effectif_adverse', v_nb);
END;
$$;

-- Recrutement du roster d'un camp depuis la position canonique.
CREATE OR REPLACE FUNCTION public.militaire_bataille_recruter(
  p_bataille_id bigint, p_camp text, p_ville text, p_bat text, p_piece text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- PJ militaires de ce camp, physiquement ici, avec au moins 1 PA.
  INSERT INTO public.batailles_engagements (bataille_id, camp, personnage, compagnie_id, section_id, grade, pa_initial)
  SELECT p_bataille_id, p_camp, pd.name, sm.compagnie_id, sm.section_id, sm.grade, pd.pa
    FROM public.personnages_donnees pd
    JOIN public.services_militaires sm ON sm.personnage = pd.name AND sm.fin_ts IS NULL
   WHERE pd.country = p_camp AND pd.current_city = p_ville
     AND pd.current_building = p_bat AND pd.current_room = p_piece
     AND coalesce(pd.pa, 0) > 0
  ON CONFLICT DO NOTHING;

  -- Soldats PNJ de ce camp : poses ici, ou menes par un chef lui-meme ici.
  INSERT INTO public.batailles_engagements (bataille_id, camp, compagnie_id, section_id, matricule, grade, pa_initial)
  SELECT p_bataille_id, p_camp, c.id, s->>'id', sol->>'matricule', 'soldat', (sol->>'pa')::integer
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE c.data->>'pays' = p_camp
     AND NOT coalesce((sol->>'pj')::boolean, false)
     AND coalesce((sol->>'pa')::integer, 0) > 0
     AND (
       (sol->>'ville' = p_ville AND sol->>'buildingId' = p_bat AND sol->>'roomId' = p_piece
        AND (sol->>'leaderCourant') IS NULL)
       OR EXISTS (SELECT 1 FROM public.personnages_donnees chef
                   WHERE chef.name = sol->>'leaderCourant' AND chef.current_city = p_ville
                     AND chef.current_building = p_bat AND chef.current_room = p_piece))
  ON CONFLICT DO NOTHING;
END;
$$;

-- Derniere position canonique connue AVANT la zone de combat. NULL si l'historique n'en offre
-- aucune : dans ce cas le camp ne pourra pas se replier, et on ne lui invente pas de destination.
CREATE OR REPLACE FUNCTION public.militaire_position_repli(
  p_nom text, p_ville text, p_bat text, p_piece text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object('ville', h.city, 'batiment', h.building_id, 'piece', h.room_id)
    FROM public.historique_deplacements h
   WHERE p_nom IS NOT NULL AND h.name = p_nom
     AND NOT (h.city = p_ville AND h.building_id = p_bat AND h.room_id = p_piece)
   ORDER BY h.created_at DESC LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.militaire_bataille_recruter(bigint, text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_position_repli(text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_bataille_engager() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_bataille_engager() TO authenticated;