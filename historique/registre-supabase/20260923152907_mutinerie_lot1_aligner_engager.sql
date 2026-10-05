-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260923152907
-- Nom original      : mutinerie_lot1_aligner_engager
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-23 15:29:07 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ad6a84058898b931dfd1a8e9a23056d6
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
CREATE OR REPLACE FUNCTION public.militaire_bataille_engager()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_moi text; a record; v_id bigint; v_contact bigint; v_init text;
  v_camps text[]; v_camp text; v_na integer; v_total integer; v_mon_camp text;
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

  -- MON CAMP : mon camp mutin s'il existe, mon pays sinon. Jamais fourni par le client.
  v_mon_camp := coalesce(public.mutinerie_camp_de(v_moi), a.country);

  -- (a) ENNEMIS ETRANGERS : predicat d'origine, inchange. Reserve aux forces loyalistes ;
  --     une force mutine ne combat pas encore l'etranger (lot suivant).
  IF v_mon_camp = a.country THEN
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
  ELSE
    v_camps := '{}';
  END IF;

  -- (b) ADVERSAIRES DU MEME PAYS : uniquement si une mutinerie separe reellement les deux camps.
  SELECT v_camps || coalesce(array_agg(c), '{}') INTO v_camps
    FROM unnest(public.mutinerie_camps_presents(a.country, a.current_city,
                                                a.current_building, a.current_room)) c
   WHERE c IS DISTINCT FROM v_mon_camp
     AND (public.mutinerie_est_camp(c) OR public.mutinerie_est_camp(v_mon_camp));

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
  VALUES (a.country, a.current_city, a.current_building, a.current_room, v_mon_camp, v_camps[1],
          v_init, v_moi, v_contact, 'en_cours', 0)
  RETURNING id INTO v_id;

  PERFORM public.militaire_bataille_recruter(v_id, v_mon_camp, a.current_city, a.current_building, a.current_room);
  FOREACH v_camp IN ARRAY v_camps LOOP
    PERFORM public.militaire_bataille_recruter(v_id, v_camp, a.current_city, a.current_building, a.current_room);
  END LOOP;

  SELECT count(*) INTO v_na    FROM public.militaire_bataille_combattants(v_id, v_mon_camp);
  SELECT count(*) INTO v_total FROM public.batailles_engagements
   WHERE bataille_id = v_id AND camp <> v_mon_camp AND sorti_round IS NULL;
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
    'mon_camp', v_mon_camp, 'camps_adverses', v_camps, 'mon_effectif', v_na,
    'effectif_adverse', v_total,
    'groupes', (SELECT count(*) FROM public.batailles_groupes WHERE bataille_id = v_id));
END;
$function$;