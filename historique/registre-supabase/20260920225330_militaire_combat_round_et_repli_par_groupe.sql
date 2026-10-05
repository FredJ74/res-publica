-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920225330
-- Nom original      : militaire_combat_round_et_repli_par_groupe
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 22:53:30 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 0241724678cd1cfa682dcea2978a29e3
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
-- =====================================================================
-- BOUCLE DE ROUND ET REPLI PAR GROUPE (21 septembre 2026)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. ENGAGEMENT — tous les camps hostiles presents, plus de LIMIT 1
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_bataille_recruter(
  p_bataille_id bigint, p_camp text, p_ville text, p_bat text, p_piece text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
BEGIN
  INSERT INTO public.batailles_engagements
    (bataille_id, camp, personnage, compagnie_id, section_id, grade, pa_initial, groupe_id)
  SELECT p_bataille_id, p_camp, pd.name, sm.compagnie_id, sm.section_id, sm.grade, pd.pa,
         coalesce(sm.compagnie_id, 'solo') || ':' || coalesce(sm.section_id, pd.name)
    FROM public.personnages_donnees pd
    JOIN public.services_militaires sm ON sm.personnage = pd.name AND sm.fin_ts IS NULL
   WHERE pd.country = p_camp AND pd.current_city = p_ville
     AND pd.current_building = p_bat AND pd.current_room = p_piece
     AND coalesce(pd.pa, 0) > 0
  ON CONFLICT DO NOTHING;

  INSERT INTO public.batailles_engagements
    (bataille_id, camp, compagnie_id, section_id, matricule, grade, pa_initial, groupe_id)
  SELECT p_bataille_id, p_camp, c.id, s->>'id', sol->>'matricule', 'soldat',
         (sol->>'pa')::integer, c.id || ':' || (s->>'id')
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE c.data->>'pays' = p_camp
     AND NOT coalesce((sol->>'pj')::boolean, false)
     AND coalesce((sol->>'pa')::integer, 0) > 0
     AND ((sol->>'ville' = p_ville AND sol->>'buildingId' = p_bat AND sol->>'roomId' = p_piece
           AND (sol->>'leaderCourant') IS NULL)
       OR EXISTS (SELECT 1 FROM public.personnages_donnees chef
                   WHERE chef.name = sol->>'leaderCourant' AND chef.current_city = p_ville
                     AND chef.current_building = p_bat AND chef.current_room = p_piece))
  ON CONFLICT DO NOTHING;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_recruter(bigint, text, text, text, text) FROM PUBLIC, anon, authenticated;


-- Constitue les groupes a partir des engages : effectif initial, chef PJ
-- eventuel, position de repli.
CREATE OR REPLACE FUNCTION public.militaire_bataille_groupes_constituer(p_bataille_id bigint)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE v_n integer;
BEGIN
  INSERT INTO public.batailles_groupes
    (bataille_id, groupe_id, camp, compagnie_id, section_id, leader, effectif_initial, repli)
  SELECT e.bataille_id, e.groupe_id, min(e.camp), min(e.compagnie_id), min(e.section_id),
         -- Le chef est le PJ du groupe le plus grade present ; NULL si le
         -- groupe n'est mene que par des PNJ.
         (SELECT p.personnage FROM public.batailles_engagements p
           WHERE p.bataille_id = e.bataille_id AND p.groupe_id = e.groupe_id
             AND p.personnage IS NOT NULL
           ORDER BY CASE p.grade WHEN 'commandant' THEN 1 WHEN 'capitaine' THEN 2
                                 WHEN 'lieutenant' THEN 3 ELSE 4 END, p.id LIMIT 1),
         count(*),
         (SELECT public.militaire_position_repli(p.personnage, b.ville, b.batiment, b.piece)
            FROM public.batailles_engagements p
            JOIN public.batailles b ON b.id = p.bataille_id
           WHERE p.bataille_id = e.bataille_id AND p.groupe_id = e.groupe_id
             AND p.personnage IS NOT NULL LIMIT 1)
    FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id
   GROUP BY e.bataille_id, e.groupe_id
  ON CONFLICT (bataille_id, groupe_id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_groupes_constituer(bigint) FROM PUBLIC, anon, authenticated;


CREATE OR REPLACE FUNCTION public.militaire_bataille_engager()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_moi text; a record; v_id bigint; v_contact bigint; v_init text;
  v_camps text[]; v_camp text; v_na integer; v_total integer;
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

  -- TOUS les pays en guerre avec le mien ayant des soldats reellement poses
  -- ici. Plus de LIMIT 1 : une bataille peut opposer plus de deux forces.
  SELECT coalesce(array_agg(DISTINCT c.data->>'pays'), '{}') INTO v_camps
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE c.data->>'pays' IS DISTINCT FROM a.country
     AND sol->>'ville' = a.current_city AND sol->>'buildingId' = a.current_building
     AND sol->>'roomId' = a.current_room AND (sol->>'leaderCourant') IS NULL
     AND EXISTS (SELECT 1 FROM public.guerres g WHERE g.statut = 'active'
                  AND ((g.data->>'attaquant' = a.country AND g.data->>'attaque' = c.data->>'pays')
                    OR (g.data->>'attaque'  = a.country AND g.data->>'attaquant' = c.data->>'pays')));
  IF coalesce(array_length(v_camps, 1), 0) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_ennemi_ici');
  END IF;

  SELECT id INTO v_contact FROM public.contacts_militaires
   WHERE consomme_le IS NULL AND ville = a.current_city AND batiment = a.current_building
     AND ((pays_a = a.country AND pays_b = ANY(v_camps)) OR (pays_a = ANY(v_camps) AND pays_b = a.country))
   ORDER BY etabli_le DESC LIMIT 1;
  v_init := CASE WHEN v_contact IS NOT NULL THEN 'simultane' ELSE 'a' END;

  INSERT INTO public.batailles (pays, ville, batiment, piece, camp_a, camp_b, initiative,
                                leader_a, contact_id, statut, round_courant)
  VALUES (a.country, a.current_city, a.current_building, a.current_room, a.country, v_camps[1],
          v_init, v_moi, v_contact, 'en_cours', 0)
  RETURNING id INTO v_id;

  PERFORM public.militaire_bataille_recruter(v_id, a.country, a.current_city, a.current_building, a.current_room);
  FOREACH v_camp IN ARRAY v_camps LOOP
    PERFORM public.militaire_bataille_recruter(v_id, v_camp, a.current_city, a.current_building, a.current_room);
  END LOOP;

  SELECT count(*) INTO v_na    FROM public.militaire_bataille_combattants(v_id, a.country);
  SELECT count(*) INTO v_total FROM public.batailles_engagements
   WHERE bataille_id = v_id AND camp <> a.country AND sorti_round IS NULL;
  IF v_na = 0 OR v_total = 0 THEN
    DELETE FROM public.batailles_engagements WHERE bataille_id = v_id;
    DELETE FROM public.batailles WHERE id = v_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'effectif_insuffisant',
      'mon_camp', v_na, 'adverse', v_total);
  END IF;

  PERFORM public.militaire_bataille_groupes_constituer(v_id);
  UPDATE public.batailles SET effectif_initial_a = v_na, effectif_initial_b = v_total,
         repli_a = public.militaire_position_repli(v_moi, a.current_city, a.current_building, a.current_room)
   WHERE id = v_id;

  IF v_contact IS NOT NULL THEN
    UPDATE public.contacts_militaires SET consomme_le = now(), bataille_id = v_id WHERE id = v_contact;
  END IF;

  RETURN jsonb_build_object('ok', true, 'bataille_id', v_id, 'initiative', v_init,
    'mon_camp', a.country, 'camps_adverses', v_camps, 'mon_effectif', v_na,
    'effectif_adverse', v_total,
    'groupes', (SELECT count(*) FROM public.batailles_groupes WHERE bataille_id = v_id));
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_engager() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_bataille_engager() TO authenticated, service_role;


-- ---------------------------------------------------------------------
-- 2. REPLI D'UN GROUPE — et de lui seul
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.militaire_bataille_decrocher(bigint, text, jsonb, integer);

CREATE FUNCTION public.militaire_bataille_decrocher_groupe(
  p_bataille_id bigint, p_groupe_id text, p_round integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE r record; v_repli jsonb; v_data jsonb; v_sec jsonb; v_sols jsonb; v_n integer := 0;
BEGIN
  SELECT g.repli INTO v_repli FROM public.batailles_groupes g
   WHERE g.bataille_id = p_bataille_id AND g.groupe_id = p_groupe_id;
  IF v_repli IS NULL THEN RETURN 0; END IF;   -- sans position de repli, on tient

  FOR r IN SELECT e.* FROM public.batailles_engagements e
            WHERE e.bataille_id = p_bataille_id AND e.groupe_id = p_groupe_id
              AND e.sorti_round IS NULL
  LOOP
    IF r.personnage IS NOT NULL THEN
      UPDATE public.personnages_donnees
         SET current_city = v_repli->>'ville', current_building = v_repli->>'batiment',
             current_room = v_repli->>'piece'
       WHERE name = r.personnage;
    ELSE
      SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = r.compagnie_id FOR UPDATE;
      SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
       WHERE s->>'id' = r.section_id;
      CONTINUE WHEN v_sec IS NULL;
      SELECT coalesce(jsonb_agg(
               CASE WHEN sol->>'matricule' = r.matricule AND (sol->>'leaderCourant') IS NULL
                    THEN sol || jsonb_build_object('ville', v_repli->>'ville',
                                 'buildingId', v_repli->>'batiment', 'roomId', v_repli->>'piece')
                    ELSE sol END ORDER BY pos), '[]'::jsonb)
        INTO v_sols FROM jsonb_array_elements(
          CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END)
          WITH ORDINALITY AS t(sol, pos);
      UPDATE public.compagnies_militaires
         SET data = public.militaire_sections_remplacer(v_data, r.section_id,
                      v_sec || jsonb_build_object('soldats', v_sols))
       WHERE id = r.compagnie_id;
    END IF;
    UPDATE public.batailles_engagements
       SET sorti_round = p_round, etat_final = 'replie' WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;

  UPDATE public.batailles_groupes
     SET sorti_round = p_round, attente_depuis = NULL
   WHERE bataille_id = p_bataille_id AND groupe_id = p_groupe_id;
  RETURN v_n;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_decrocher_groupe(bigint, text, integer) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 3. ARBITRAGE DES GROUPES — seuil, fenetre de 90 s, repli automatique
-- ---------------------------------------------------------------------
-- Rend le nombre de groupes ENCORE EN ATTENTE d'une decision humaine.
-- Tant qu'il en reste un, le round suivant ne part pas : c'est ainsi que la
-- fenetre de decision ne se paie pas en morts.
CREATE OR REPLACE FUNCTION public.militaire_bataille_arbitrer_groupes(
  p_bataille_id bigint, p_round integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE g record; v_attente integer := 0;
BEGIN
  FOR g IN SELECT * FROM public.batailles_groupes
            WHERE bataille_id = p_bataille_id AND sorti_round IS NULL
  LOOP
    -- Un groupe qui a deja tranche « replier » decroche.
    IF g.decision = 'replier' THEN
      PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, p_round);
      CONTINUE;
    END IF;
    -- Un groupe qui a deja tranche « tenir » continue : rien a faire.
    IF g.decision = 'tenir' THEN CONTINUE; END IF;

    IF NOT public.militaire_groupe_sous_seuil(p_bataille_id, g.groupe_id) THEN
      CONTINUE;                                  -- pas encore a 50 % de pertes
    END IF;

    IF g.leader IS NULL THEN
      -- Groupe mene par un PNJ : repli automatique, sans attente.
      PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, p_round);
      CONTINUE;
    END IF;

    IF g.attente_depuis IS NULL THEN
      -- Ouverture de la fenetre de 90 secondes pour le chef PJ.
      UPDATE public.batailles_groupes SET attente_depuis = now()
       WHERE bataille_id = p_bataille_id AND groupe_id = g.groupe_id;
      v_attente := v_attente + 1;
    ELSIF now() - g.attente_depuis >= interval '90 seconds' THEN
      -- Delai ecoule sans reponse : repli automatique du groupe.
      PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, p_round);
    ELSE
      v_attente := v_attente + 1;                -- la fenetre court encore
    END IF;
  END LOOP;
  RETURN v_attente;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_arbitrer_groupes(bigint, integer) FROM PUBLIC, anon, authenticated;