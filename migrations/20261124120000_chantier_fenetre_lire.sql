-- APPLIQUÉE en production le 24/11/2026 (contrôlée : anon refusé, authenticated autorisé) (mission « Purge », bloc C, Fred, 24/11/2026).
-- Fenêtre du chantier simplifiée (points C.1 à C.3) : l'écran affiche le plafond d'heures, le gain et les quantités
-- vendables que le SERVEUR décide, jamais un calcul à lui (AGENTS.md, « Une seule réalité »). Il n'existait aucune
-- lecture : seuls chantier_commande('travailler') et vendre_materiaux_chantier décidaient, au moment de l'action.
--
-- Nouvelle fonction de LECTURE, sans aucun effet : public.chantier_fenetre_lire(p_terrain_id text).
--  * Travail : le nombre d'heures que le joueur peut faire MAINTENANT est obtenu en rejouant la vraie
--    chantier_travailler (mêmes bornes : heures ouvertes, jour d'avance, PA, trésorerie, intempéries) dans une
--    sous-transaction annulée aussitôt : rien n'est écrit, et la règle ne peut pas diverger. Le salaire horaire et le
--    gain par heure viennent de la même réponse.
--  * Heures du jour (« Encore X heures à faire aujourd'hui ») : mêmes formules que chantier_travailler (capacité,
--    palier d'appel de fonds), jour d'avance par la fonction existante chantier_avance_heures_interne.
--  * Matériaux : besoin du jour (chantier_besoin_jour_interne), stock du chantier, prix de rachat (même règle que
--    vendre_materiaux_chantier), quantité possédée (inventaire du joueur), plafond vendable = ce qui manque pour le
--    jour, ce que le joueur possède et ce que la trésorerie peut payer.
-- Rejouable (CREATE OR REPLACE). Aucune table, aucune donnée, aucune fonction existante modifiée. Rien du goulag.
BEGIN;

CREATE OR REPLACE FUNCTION public.chantier_fenetre_lire(p_terrain_id text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
-- chantier_fenetre_lire_v1
DECLARE acteur text := public.mon_personnage(); a record; t record; etat jsonb; ch jsonb; emplacement text;
  v_taux numeric; v_min numeric; v_taux_paye numeric; v_capacite numeric := 0; v_plafond numeric := 0; v_prog numeric;
  v_utiles numeric := 0; v_faites numeric; v_avance numeric := 0; v_treso numeric; v_besoin jsonb; v_num integer;
  essai jsonb; raison text; v_max integer := 0; m text; v_prix numeric; v_possede numeric; v_stock numeric; v_b numeric;
  v_payables numeric; mats jsonb := '{}'::jsonb; v_termine boolean; present boolean;
BEGIN
  IF acteur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT name, country, current_city, current_building, pa, inventory, hospitalisation INTO a
    FROM public.personnages_donnees WHERE name = acteur;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  SELECT * INTO t FROM public.terrains_etat WHERE country = a.country AND
    (id = p_terrain_id OR building_id = p_terrain_id AND data::jsonb->>'city' = a.current_city) ORDER BY (id = p_terrain_id) DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_introuvable'); END IF;
  etat := t.data::jsonb;
  emplacement := CASE WHEN jsonb_typeof(etat->'chantier') = 'object' THEN 'chantier' ELSE 'chantierReamenagement' END;
  ch := etat->emplacement;
  IF ch IS NULL OR jsonb_typeof(ch) <> 'object' THEN RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent'); END IF;

  -- Heures du jour : mêmes formules que chantier_travailler (chantier_heures_ouvertes_v1, chantier_jour_avance_v1).
  SELECT valeur INTO v_taux FROM public.entreprises_constantes WHERE cle = 'chantier_taux_horaire';
  SELECT valeur INTO v_min FROM public.entreprises_constantes WHERE cle = 'chantier_salaire_minimum';
  v_taux_paye := greatest(coalesce((ch->>'tauxHoraire')::numeric, v_taux), coalesce(v_min, 50));
  v_prog := greatest(0, coalesce((ch->>'progressionJours')::numeric, 0));
  IF coalesce(v_taux, 0) > 0 AND coalesce((ch->>'dureeJours')::numeric, 0) > 0 THEN
    v_capacite := (coalesce((ch->>'coutTravail')::numeric, 0) / v_taux) / (ch->>'dureeJours')::numeric;
    v_plafond := CASE WHEN (ch->>'totalVerse')::numeric >= (ch->>'coutTotal')::numeric THEN (ch->>'dureeJours')::numeric
      WHEN (ch->>'totalVerse')::numeric >= ceil((ch->>'coutTotal')::numeric * .7) THEN (ch->>'dureeJours')::numeric * 2 / 3
      WHEN (ch->>'totalVerse')::numeric >= ceil((ch->>'coutTotal')::numeric * .35) THEN (ch->>'dureeJours')::numeric / 3 ELSE 0 END;
    v_utiles := floor(v_capacite * least(1, greatest(0, v_plafond - coalesce((ch->>'progressionJours')::numeric, 0))));
    BEGIN
      v_avance := coalesce(public.chantier_avance_heures_interne(ch, v_capacite, v_plafond, v_utiles), 0);
    EXCEPTION WHEN OTHERS THEN v_avance := 0;
    END;
  END IF;
  v_faites := greatest(0, coalesce((ch->>'heuresFaites')::numeric, 0));
  v_treso := greatest(0, coalesce((ch->>'tresorerie')::numeric, 0));

  -- Présence et disponibilité : mêmes refus que chantier_commande('travailler') et vendre_materiaux_chantier.
  present := a.current_city IS NOT DISTINCT FROM etat->>'city' AND a.current_building IS NOT DISTINCT FROM t.building_id;
  IF NOT present THEN raison := 'pas_sur_place';
  ELSIF coalesce(a.hospitalisation->>'dateFinParis', '') > (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN raison := 'acteur_incapacite';
  ELSIF EXISTS (SELECT 1 FROM public.detention_active(acteur)) THEN raison := 'acteur_detenu';
  ELSIF coalesce(etat->>'succession_gel', '') <> '' THEN raison := 'terrain_gele';
  END IF;

  -- Travail : la vraie chantier_travailler, rejouée puis annulée (aucune écriture ne survit à ce bloc).
  IF raison IS NULL THEN
    BEGIN
      essai := public.chantier_travailler(acteur, t.country, t.id, 2147483647);
      RAISE EXCEPTION 'chantier_fenetre_lecture_seule' USING ERRCODE = 'RPLS0';
    EXCEPTION
      WHEN SQLSTATE 'RPLS0' THEN NULL;
      WHEN OTHERS THEN essai := jsonb_build_object('ok', false, 'raison', 'travail_indisponible');
    END;
    IF coalesce((essai->>'ok')::boolean, false) THEN
      v_max := greatest(0, coalesce((essai->>'heures')::integer, 0));
      v_taux_paye := coalesce((essai->>'taux')::numeric, v_taux_paye);
    ELSE
      raison := coalesce(essai->>'raison', 'travail_indisponible');
      IF raison = 'aucune_heure_travaillable' THEN
        raison := CASE WHEN coalesce((essai->>'utilesRestantes')::numeric, 0) <= 0 THEN 'aucune_heure_ouverte'
                       WHEN coalesce((essai->>'pa')::numeric, 0) < 1 THEN 'pa_insuffisants'
                       WHEN coalesce((essai->>'payables')::numeric, 0) < 1 THEN 'tresorerie_insuffisante'
                       ELSE raison END;
      END IF;
    END IF;
  END IF;

  -- Matériaux : règle de vendre_materiaux_chantier (prix du propriétaire, sinon prix de base + 10 %).
  v_termine := coalesce((ch->>'dureeJours')::numeric, 0) > 0 AND v_prog >= (ch->>'dureeJours')::numeric;
  v_num := floor(v_prog)::integer + 1;
  BEGIN v_besoin := public.chantier_besoin_jour_interne(ch, v_num); EXCEPTION WHEN OTHERS THEN v_besoin := NULL; END;
  FOREACH m IN ARRAY ARRAY['bois', 'minerai', 'metal'] LOOP
    v_prix := coalesce((ch->'prixAchatPJ'->>m)::numeric, (SELECT ceil(prix_base * 1.10) FROM public.ressources_economie WHERE cle = m));
    SELECT coalesce(sum(greatest(0, floor(coalesce((x->>'qty')::numeric, 0)))), 0) INTO v_possede
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(a.inventory) = 'array' THEN a.inventory ELSE '[]'::jsonb END) x
     WHERE x->>'stackKey' = m AND coalesce((x->>'stackable')::boolean, false);
    v_stock := greatest(0, coalesce((ch->'stockMateriaux'->>m)::numeric, 0));
    v_b := greatest(0, coalesce((v_besoin->>m)::numeric, 0));
    v_payables := CASE WHEN coalesce(v_prix, 0) <= 0 THEN 2147483647 ELSE floor(v_treso / v_prix) END;
    mats := mats || jsonb_build_object(m, jsonb_build_object('prix', v_prix, 'stock', v_stock, 'besoin', v_b,
      'manque', greatest(0, v_b - v_stock), 'possede', v_possede, 'payables', v_payables,
      'max', CASE WHEN v_termine OR NOT present OR raison IN ('acteur_incapacite', 'acteur_detenu', 'terrain_gele') THEN 0
                  ELSE greatest(0, least(greatest(0, v_b - v_stock), v_possede, v_payables)) END,
      'maxDon', CASE WHEN v_termine OR NOT present OR raison IN ('acteur_incapacite', 'acteur_detenu', 'terrain_gele') THEN 0
                  ELSE greatest(0, least(greatest(0, v_b - v_stock), v_possede)) END));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'terrain', t.id, 'surPlace', present,
    'travail', jsonb_build_object('capacite', floor(v_capacite), 'faitesJour', least(v_faites, v_utiles),
      'restantesJour', greatest(0, v_utiles - v_faites), 'restantesAvance', v_avance,
      'taux', v_taux_paye, 'pa', coalesce(a.pa, 0), 'max', v_max, 'raison', CASE WHEN v_max > 0 THEN NULL ELSE raison END),
    'materiaux', mats, 'accepteMateriaux', NOT v_termine);
END $function$;

REVOKE ALL ON FUNCTION public.chantier_fenetre_lire(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chantier_fenetre_lire(text) TO authenticated;
COMMIT;
