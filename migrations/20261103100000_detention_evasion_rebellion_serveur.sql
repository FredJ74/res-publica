-- =============================================================================================
-- ÉVASION ET RÉBELLION TIRÉES PAR LE SERVEUR (Claude, 03/11/2026)
-- =============================================================================================
-- Relevé du 03/11 (RELAIS.md, points 1 et 2) : « Tenter de s'évader » et « Se rebeller » étaient
-- décidés par le navigateur (jets Math.random, une tentative par jour tenue dans `state`, amende
-- de 500 FR retirée de `state.arg` sans être versée, grilles écrites par l'écran dans
-- `niveaux_prison`). Pire : `detention_clore_evasion()` était exécutable par l'écran, si bien
-- qu'un détenu pouvait s'évader quand il voulait en l'appelant directement.
--
-- Deux portes font désormais tout, dans une seule transaction :
--   . detention_tenter_evasion(p_pa, p_cost, p_benediction)
--   . detention_se_rebeller(p_pa, p_cost)
-- Formules conservées à l'identique (aucune décision de game design nouvelle) :
--   évasion   = clamp(round(10 + 2(DUP-10) - (ISN-45)/3 [+5 bénédiction]), 2, 40),
--               puis + bonus du déserteur (10 par jour de détention, plafond 50), maximum 90 ;
--               échec : +1 jour de peine et amende de 500 FR (versée au Trésor) ;
--               réussite : clôture « evasion », avis de recherche = motifs d'origine + « Évasion »
--               (2 jours) + reliquat.
--   rébellion = min(60, 3 VOL + FOR du codétenu / 2) ; grilles −4 à −10 dans tous les cas ;
--               réussite : DIS +6, PV −10, +1 jour ; échec : PV −25, DIS −15, QHS 30 jours.
-- Écarts assumés, techniques :
--   . la tentative du jour est tenue par la LIGNE de détention (`derniere_tentative_evasion`,
--     jour de Paris), que l'écran ne peut pas écrire — plus par `est_emprisonne`, qu'il réécrit ;
--   . le bonus du déserteur se calcule sur la détention en cours (jour de jeu − jour d'entrée),
--     son ancien compteur n'étant persisté nulle part ;
--   . la FOR du codétenu lue dans `employes` est bornée à 20 (bonus ≤ 10) ;
--   . la baisse de POP nationale de la rébellion réussie, jamais enregistrée nulle part, n'est
--     pas reprise.
-- Les grilles des cellules ne sont plus écrivables par l'écran.
-- =============================================================================================

ALTER TABLE public.detentions ADD COLUMN IF NOT EXISTS derniere_tentative_evasion date;

-- ---------------------------------------------------------------------------------------------
-- Grilles des cellules : moteur sans autorité.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.prison_grilles_endommager_interne(p_pays text, p_ville text, p_degats integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text := p_pays || '_' || coalesce(p_ville, 'capitale'); v_avant integer; v_apres integer;
BEGIN
  INSERT INTO public.niveaux_prison (id, data, updated_at)
  VALUES (v_id, jsonb_build_object('niveau', 100), now())
  ON CONFLICT (id) DO NOTHING;
  SELECT coalesce(CASE WHEN jsonb_typeof(data -> 'niveau') = 'number' THEN (data ->> 'niveau')::numeric END, 100)::integer
    INTO v_avant FROM public.niveaux_prison WHERE id = v_id FOR UPDATE;
  v_apres := greatest(0, v_avant - greatest(0, coalesce(p_degats, 0)));
  -- Insurrection : les grilles cèdent, puis sont remises à neuf (comportement d'origine).
  UPDATE public.niveaux_prison
     SET data = coalesce(data, '{}'::jsonb) || jsonb_build_object('niveau', CASE WHEN v_apres <= 0 THEN 100 ELSE v_apres END),
         updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('niveau', v_apres, 'degats', v_avant - v_apres, 'insurrection', v_apres <= 0);
END $function$;

-- ---------------------------------------------------------------------------------------------
-- Tenter de s'évader.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.detention_tenter_evasion(p_pa integer, p_cost integer, p_benediction boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; p public.personnages_donnees%ROWTYPE; v_det record; v_paie jsonb;
  v_jour_paris date := (now() AT TIME ZONE 'Europe/Paris')::date; v_deja date;
  v_ville text; v_pays text; v_isn numeric; v_dup numeric; v_taux integer; v_bonus integer := 0;
  v_jet integer; v_motifs jsonb; v_reliquat integer; v_entree jsonb; v_rech jsonb; v_prol jsonb;
  v_amende integer; v_fiche record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  IF v_det.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_detenu'); END IF;
  SELECT derniere_tentative_evasion, coalesce(motifs, '[]'::jsonb) INTO v_deja, v_motifs
    FROM public.detentions WHERE id = v_det.id FOR UPDATE;
  IF v_deja = v_jour_paris THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'une_tentative_par_jour'); END IF;

  v_paie := public.payer_ordre_interne(v_moi, 'tentative_evasion', p_pa, p_cost);
  IF NOT coalesce((v_paie ->> 'ok')::boolean, false) THEN RETURN v_paie; END IF;
  UPDATE public.detentions SET derniere_tentative_evasion = v_jour_paris WHERE id = v_det.id;

  v_pays := coalesce(v_det.country, p.country, 'republic');
  v_ville := coalesce(v_det.city, p.current_city, 'capitale');
  v_isn := coalesce((SELECT CASE WHEN jsonb_typeof(data -> 'isn') = 'number' THEN (data ->> 'isn')::numeric END
                       FROM public.indices_villes WHERE id = v_pays || '_' || v_ville), 30);
  v_dup := coalesce(CASE WHEN jsonb_typeof(p.stats -> 'DUP') = 'number' THEN (p.stats ->> 'DUP')::numeric END, 8);
  v_taux := greatest(2, least(40, round(10 + (v_dup - 10) * 2 - (v_isn - 45) / 3
                                        + CASE WHEN p_benediction THEN 5 ELSE 0 END)))::integer;
  -- Bonus du déserteur : appliqué APRÈS le plafond ordinaire de 40 %, maximum absolu 90 %.
  IF p.requisition ->> 'statut' = 'deserteur' THEN
    v_bonus := least(50, greatest(0, coalesce(p.day, 1) - coalesce(v_det.jour_debut, coalesce(p.day, 1))) * 10);
    v_taux := least(90, v_taux + v_bonus);
  END IF;
  v_jet := floor(random() * 100)::integer + 1;

  IF v_jet <= v_taux THEN
    -- Évasion réussie n'est pas une libération : jour_fin n'est jamais réécrit.
    v_reliquat := greatest(0, coalesce(v_det.jour_fin, coalesce(p.day, 1)) - coalesce(p.day, 1));
    PERFORM public.detention_clore_interne(v_moi, 'evasion');
    v_entree := jsonb_build_object(
      'id', 'rech-evasion-' || replace(gen_random_uuid()::text, '-', ''),
      'type', 'condamnation', 'country', v_pays,
      'motifs', v_motifs || jsonb_build_array(jsonb_build_object(
          'type', 'Évasion', 'jour_fait', coalesce(p.day, 1), 'city', v_ville, 'jours', 2,
          'source', 'evasion', 'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
      'detention_precedente_id', v_det.id, 'reliquat_jours', v_reliquat,
      'jour_condamnation', coalesce(p.day, 1));
    v_rech := public.recherche_inscrire(v_entree);
    IF NOT coalesce((v_rech ->> 'ok')::boolean, false) THEN
      RAISE EXCEPTION 'detention_tenter_evasion : avis de recherche refusé (%)', v_rech ->> 'raison';
    END IF;
    RETURN jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_jet,
      'detention_id', v_det.id, 'reliquat_jours', v_reliquat, 'recherche', v_rech -> 'recherche',
      'paiement', v_paie);
  END IF;

  -- Échec : +1 jour de peine et 500 FR d'amende, versés au Trésor.
  v_prol := public.detention_prolonger_interne(v_moi, jsonb_build_array(jsonb_build_object(
      'type', 'Tentative d''évasion échouée', 'jour_fait', coalesce(p.day, 1), 'city', v_ville, 'jours', 1,
      'source', 'evenement_detention',
      'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))), false);
  v_amende := public.amende_imposer_interne('evasion-' || replace(gen_random_uuid()::text, '-', ''), v_pays, v_moi, 500);
  SELECT pa, liquide, arg, est_emprisonne INTO v_fiche FROM public.personnages_donnees WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_jet,
    'amende', v_amende, 'jour_fin', v_prol -> 'jour_fin', 'jours_ajoutes', v_prol -> 'jours_ajoutes',
    'pa', v_fiche.pa, 'liquide', v_fiche.liquide, 'arg', v_fiche.arg, 'est_emprisonne', v_fiche.est_emprisonne,
    'paiement', v_paie);
END $function$;

-- ---------------------------------------------------------------------------------------------
-- Se rebeller.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.detention_se_rebeller(p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; p public.personnages_donnees%ROWTYPE; v_det record; v_paie jsonb;
  v_ville text; v_pays text; v_vol numeric; v_for numeric; v_taux integer; v_jet integer; v_degats integer;
  v_grilles jsonb; v_dis numeric; v_hp integer; v_res jsonb; v_r jsonb; v_fiche record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  IF v_det.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_detenu'); END IF;

  v_paie := public.payer_ordre_interne(v_moi, 'se_rebeller', p_pa, p_cost);
  IF NOT coalesce((v_paie ->> 'ok')::boolean, false) THEN RETURN v_paie; END IF;

  v_pays := coalesce(v_det.country, p.country, 'republic');
  v_ville := coalesce(v_det.city, p.current_city, 'capitale');
  v_vol := coalesce(CASE WHEN jsonb_typeof(p.stats -> 'VOL') = 'number' THEN (p.stats ->> 'VOL')::numeric END, 8);
  SELECT greatest(0, least(20, coalesce(CASE WHEN jsonb_typeof(e -> 'stats' -> 'FOR') = 'number'
                                             THEN (e -> 'stats' ->> 'FOR')::numeric END, 0)))
    INTO v_for
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.employes) = 'array' THEN p.employes ELSE '[]'::jsonb END) e
   WHERE e ->> 'job' = 'codetenu' LIMIT 1;
  v_taux := least(60, floor(v_vol * 3 + floor(coalesce(v_for, 0) / 2)))::integer;
  v_jet := floor(random() * 100)::integer + 1;
  v_degats := floor(random() * 7)::integer + 4;
  v_grilles := public.prison_grilles_endommager_interne(v_pays, v_ville, v_degats);

  v_res := CASE WHEN jsonb_typeof(p.resources) = 'object' THEN p.resources ELSE '{}'::jsonb END;
  v_dis := coalesce(CASE WHEN jsonb_typeof(v_res -> 'dis') = 'number' THEN (v_res ->> 'dis')::numeric END, 50);

  IF v_jet <= v_taux THEN
    v_hp := greatest(1, coalesce(p.hp, 100) - 10);
    UPDATE public.personnages_donnees
       SET hp = v_hp, resources = v_res || jsonb_build_object('dis', least(100, v_dis + 6))
     WHERE name = v_moi;
    v_r := public.detention_prolonger_interne(v_moi, jsonb_build_array(jsonb_build_object(
        'type', 'Rébellion en cellule', 'jour_fait', coalesce(p.day, 1), 'city', v_ville, 'jours', 1,
        'source', 'evenement_detention',
        'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))), false);
    SELECT est_emprisonne INTO v_fiche FROM public.personnages_donnees WHERE name = v_moi;
    RETURN jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_jet,
      'grilles', v_grilles, 'hp', v_hp, 'dis', least(100, v_dis + 6),
      'jour_fin', v_r -> 'jour_fin', 'jours_ajoutes', v_r -> 'jours_ajoutes',
      'est_emprisonne', v_fiche.est_emprisonne, 'paiement', v_paie);
  END IF;

  -- Rébellion matée : transfert au QHS, 30 jours, par la porte existante (appel interne).
  v_hp := greatest(1, coalesce(p.hp, 100) - 25);
  UPDATE public.personnages_donnees
     SET hp = v_hp, resources = v_res || jsonb_build_object('dis', greatest(0, v_dis - 15))
   WHERE name = v_moi;
  v_r := public.detention_transferer_qhs('Rebellion en cellule matee - transfert QHS', 30, v_det.city,
           jsonb_build_array(jsonb_build_object('type', 'Rébellion en cellule matée — transfert QHS',
             'jour_fait', coalesce(p.day, 1), 'city', v_ville, 'jours', 30, 'source', 'evenement_detention',
             'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))));
  IF NOT coalesce((v_r ->> 'ok')::boolean, false) THEN
    RAISE EXCEPTION 'detention_se_rebeller : transfert QHS impossible (%)', v_r ->> 'raison';
  END IF;
  SELECT est_emprisonne INTO v_fiche FROM public.personnages_donnees WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_jet,
    'grilles', v_grilles, 'hp', v_hp, 'dis', greatest(0, v_dis - 15),
    'qhs', true, 'detention_id', v_r ->> 'detention_id', 'jour_fin', v_r -> 'jour_fin',
    'est_emprisonne', v_fiche.est_emprisonne, 'paiement', v_paie);
END $function$;

-- ---------------------------------------------------------------------------------------------
-- Droits.
-- ---------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.prison_grilles_endommager_interne(text, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.detention_tenter_evasion(integer, integer, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.detention_se_rebeller(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.detention_tenter_evasion(integer, integer, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.detention_se_rebeller(integer, integer) TO authenticated;

-- Les deux anciennes portes ne sont plus appelées que de l'intérieur.
REVOKE ALL ON FUNCTION public.detention_clore_evasion() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.detention_transferer_qhs(text, integer, text, jsonb) FROM PUBLIC, anon, authenticated;

-- Grilles : lecture publique conservée, écriture fermée à l'écran.
DROP POLICY IF EXISTS niveaux_prison_ecriture_acteur ON public.niveaux_prison;
DROP POLICY IF EXISTS niveaux_prison_maj_acteur ON public.niveaux_prison;
REVOKE INSERT, UPDATE, DELETE ON public.niveaux_prison FROM anon, authenticated;
