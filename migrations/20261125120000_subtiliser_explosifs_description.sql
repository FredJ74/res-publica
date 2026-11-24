-- Mission de nuit du 25/11/2026 (Claude), bloc 3 — NON APPLIQUÉE : à valider par Fred.
-- « Subtiliser des explosifs » (caserne, fn acheter_bombe_illegale) : le serveur applique ce que promet la description
-- (décision de Fred du 24/11 au soir).
--
-- ATTENTION — l'ordre cliqué n'est PAS résolu par crime_acheter_explosifs (c'est l'achat au marché noir, ordre
-- marche_noir, inchangé ici) mais par militaire_subtiliser_tenter (plateau-router.js → doSubtiliserExplosifsMilitaires →
-- sbMilitaireSubtiliserTenter). Relevé en production le 25/11 : score = 50 + 2 × (DUP − 10) − (ISN − 45)/3 + palier de
-- réputation criminelle (5/10/15) + jet ; réussite à 66 (35 % de base), échec DÉTECTÉ seulement si le score est sous 20 ;
-- ni discrétion, ni malus de Sovarka, ni bonus de carrière, ni détection à 55 %.
--
-- Nouvelle règle (briques du moteur commun du crime, aucun moteur nouveau) :
--   chance = 35 (subtiliser_base) + bonus de DIS (crim_bonus_dis_interne : +1 par tranche de 3 au-dessus de 50)
--          + réputation criminelle (paliers existants de l'ordre : +5 dès 20, +10 dès 40, +15 dès 70)
--          + 15 carrière criminelle (subtiliser_carriere, comme les autres crimes)
--          − malus ISN de la ville (crime_malus_isn_interne, commun aux ordres illégaux)
--          − 10 en Sovarka (subtiliser_soviet)
--          − dissuasion des hommes armés présents (securite_malus_lieu_interne, #135, une fois),
--          bornée 5 à 75 (subtiliser_min, subtiliser_max).
--   Un seul jet 1-100 : réussite si jet ≤ chance. Échec : jet de détection = taux de l'infraction (infractions.detect_rate,
--   55 %) − 20 caché − 10 masqué (detection_cache, detection_masque), plancher detection_min (5). Seul un échec DÉTECTÉ
--   mène à l'arrestation (barème militaire existant, QHS en Sovarka), motif « Vol d'explosifs militaires ».
--   La DUP ne compte plus (la description ne la promet pas).
-- crim_subtiliser_chance_interne(nom) est la SEULE formule : l'ordre et l'affichage « Vos chances réelles » (bloc 4) la lisent.
-- Motif : infractions.acheter_bombe_illegale renommé « Vol d'explosifs militaires » (plateau-core.js identique).
--
-- Contrôles en lecture après application :
--   SELECT libelle FROM public.infractions WHERE id = 'acheter_bombe_illegale';                -- Vol d'explosifs militaires
--   SELECT cle, valeur FROM public.crim_parametres WHERE cle LIKE 'subtiliser_%' ORDER BY cle;  -- 5 lignes
--   SELECT position('subtiliser_description_v1' in prosrc) > 0 FROM pg_proc WHERE proname = 'militaire_subtiliser_tenter';  -- vrai
--   SELECT has_function_privilege('authenticated', 'public.crim_subtiliser_chance_interne(text)', 'EXECUTE');  -- faux
BEGIN;

UPDATE public.infractions SET libelle = 'Vol d''explosifs militaires'
 WHERE id = 'acheter_bombe_illegale' AND libelle <> 'Vol d''explosifs militaires';

INSERT INTO public.crim_parametres (cle, valeur) VALUES
  ('subtiliser_base', 35), ('subtiliser_min', 5), ('subtiliser_max', 75), ('subtiliser_carriere', 15), ('subtiliser_soviet', -10)
ON CONFLICT (cle) DO NOTHING;

-- La chance réelle, détaillée (base, modificateurs, bornes) : lue par l'ordre et par l'affichage des chances.
CREATE OR REPLACE FUNCTION public.crim_subtiliser_chance_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; v_rep integer; v_dis integer; v_rep_b integer; v_car integer; v_isn integer; v_sov integer; v_dissu integer;
        v_brut integer; v_taux integer;
BEGIN
  SELECT country, current_city, career, reputation_criminelle INTO d FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND THEN RETURN NULL; END IF;
  v_dis := public.crim_bonus_dis_interne(public.crim_stat_interne(p_nom, 'dis', 50));
  v_rep := greatest(0, least(100, coalesce(d.reputation_criminelle, 0)));
  v_rep_b := CASE WHEN v_rep >= 70 THEN 15 WHEN v_rep >= 40 THEN 10 WHEN v_rep >= 20 THEN 5 ELSE 0 END;
  v_car := CASE WHEN d.career = 'criminal_c' THEN public.crim_param_interne('subtiliser_carriere', 15)::integer ELSE 0 END;
  v_isn := public.crime_malus_isn_interne(d.country, d.current_city);
  v_sov := CASE WHEN d.country = 'soviet' THEN public.crim_param_interne('subtiliser_soviet', -10)::integer ELSE 0 END;
  v_dissu := coalesce(public.securite_malus_lieu_interne(p_nom), 0);
  v_brut := public.crim_param_interne('subtiliser_base', 35)::integer + v_dis + v_rep_b + v_car - v_isn + v_sov - v_dissu;
  v_taux := greatest(public.crim_param_interne('subtiliser_min', 5)::integer, least(public.crim_param_interne('subtiliser_max', 75)::integer, v_brut));
  RETURN jsonb_build_object('taux', v_taux, 'base', public.crim_param_interne('subtiliser_base', 35)::integer, 'discretion', v_dis,
    'reputation', v_rep_b, 'carriere', v_car, 'isn', -v_isn, 'sovarka', v_sov, 'dissuasion', -v_dissu); /* subtiliser_description_v1 */
END $$;

-- Chance de détection d'un échec : taux de l'infraction, moins la cachette et le masque (paramètres de la détection commune).
CREATE OR REPLACE FUNCTION public.crim_subtiliser_detection_interne(p_nom text)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_mode text := public.crim_mode_action_interne(p_nom);
BEGIN
  RETURN greatest(public.crim_param_interne('detection_min', 5)::integer,
    coalesce((SELECT detect_rate FROM public.infractions WHERE id = 'acheter_bombe_illegale'), 55)
    - CASE WHEN v_mode IN ('cache', 'cache_masque') THEN public.crim_param_interne('detection_cache', 20)::integer ELSE 0 END
    - CASE WHEN v_mode IN ('masque', 'cache_masque') THEN public.crim_param_interne('detection_masque', 10)::integer ELSE 0 END); /* subtiliser_description_v1 */
END $$;

CREATE OR REPLACE FUNCTION public.militaire_subtiliser_tenter(p_pays text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_pj public.personnages_donnees%ROWTYPE;
  v_chance jsonb; v_taux integer; v_jet integer; v_det integer; v_jet_det integer; v_jets jsonb;
  v_stock jsonb; v_objet jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_pj FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF coalesce(v_pj.current_building,'') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- LE PA EST DEBITE AVANT LE JET, comme pour toute tentative : on paie l'essai, pas le resultat.
  IF coalesce(v_pj.pa, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', 2);
  END IF;

  v_chance := public.crim_subtiliser_chance_interne(v_moi);
  v_taux := (v_chance ->> 'taux')::integer;
  -- Jets imposés pour les bancs seulement (session postgres), comme la résolution commune.
  v_jets := CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.subtiliser_jets', true), '')::jsonb END;
  v_jet := coalesce((v_jets ->> 0)::integer, floor(random() * 100)::integer + 1);

  UPDATE public.personnages_donnees SET pa = greatest(0, coalesce(pa,0) - 2) WHERE name = v_moi;

  IF v_jet > v_taux THEN
    v_det := public.crim_subtiliser_detection_interne(v_moi);
    v_jet_det := coalesce((v_jets ->> 1)::integer, floor(random() * 100)::integer + 1);
    RETURN jsonb_build_object('ok', true, 'reussite', false, 'detecte', v_jet_det <= v_det, 'score', v_jet,
      'taux', v_taux, 'jet', v_jet, 'detection', v_det)
      || CASE WHEN v_jet_det <= v_det THEN jsonb_build_object('arrestation',
           public.arrestation_flagrant_interne(v_moi, 'vol_materiel_militaire', false, 'subtilisation', 'Vol d''explosifs militaires',
             public.crim_peine_jours_interne('vol_materiel_militaire', v_pj.country) /* crim_bareme_militaire_v1 : barème commun, ×2 en Sovarka */,
             v_pj.country = 'soviet' /* crim_qhs_militaire_v1 */, 'caserne'))
         ELSE '{}'::jsonb END;
  END IF;

  -- REUSSITE. Le stock est decremente AVANT que l'objet n'existe : jamais d'explosif cree de rien.
  v_stock := public.caserne_stock_mouvement(p_pays, 'explosif_militaire', -1, NULL);
  IF coalesce((v_stock->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'reussite', false, 'detecte', false,
      'score', v_jet, 'taux', v_taux, 'jet', v_jet, 'raison', 'stock_insuffisant');
  END IF;

  -- ...et c'est le SERVEUR qui le pose dans l'inventaire, plus le navigateur.
  v_objet := jsonb_build_object(
    'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
    'type', 'arme', 'sousType', 'militaire', 'origineMilitaire', true,
    'lot', coalesce(v_stock->'lots'->0->>'lot', 'legacy'),
    'produitMilitaire', 'explosif_militaire', 'name', 'Explosif militaire',
    'icon', 'ti-bomb', 'legal', true, 'imageUrl', NULL,
    'desc', 'Explosif militaire. Lot ' || coalesce(v_stock->'lots'->0->>'lot', 'legacy') || '.');

  UPDATE public.personnages_donnees
     SET inventory = (CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END)
                     || jsonb_build_array(v_objet)
   WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'reussite', true, 'detecte', false,
    'score', v_jet, 'taux', v_taux, 'jet', v_jet, 'objet', v_objet, 'lot', v_objet->>'lot'); /* subtiliser_description_v1 */
END;
$function$;

REVOKE ALL ON FUNCTION public.crim_subtiliser_chance_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.crim_subtiliser_detection_interne(text) FROM PUBLIC, anon, authenticated;

COMMIT;
