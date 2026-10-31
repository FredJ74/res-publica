-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261018231225_assemblage_composants_stocks_reels.sql ; aucun changement de règle.
-- NON APPLIQUE. Requiert le moteur d'assemblage deja installe ; verifier le catalogue vivant.
-- Les sources de reference ont des horodatages futurs : ne pas trier/appiquer aveuglement.
BEGIN;
DO $controle$
DECLARE v_source text;
BEGIN
 SELECT prosrc INTO v_source FROM pg_proc WHERE oid=to_regprocedure('public.fonds_reference_produire_lots(text,text,text,text,integer)');
 IF v_source IS NULL OR md5(v_source) NOT IN ('95389bd2068e2767fa2a165c5b79ab64','ab95c733be25d3da5c3c2874c100557f') THEN
  RAISE EXCEPTION 'definition_assemblage_non_verifiee';
 END IF;
END;
$controle$;
CREATE OR REPLACE FUNCTION public.fonds_reference_produire_lots(p_requete text, p_acteur text, p_fonds_id text, p_reference_id text, p_lots integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_lots integer := coalesce(p_lots, 0);
  v_max_ref integer;
  v_data jsonb; v_ref jsonb; v_r record; v_gen record;
  v_sm jsonb; v_couts jsonb; v_m text; v_q jsonb;
  v_besoin numeric; v_dispo numeric; v_cm numeric;
  v_mat numeric := 0; v_pa_val numeric; v_pa_requis integer;
  v_nom_pj text; v_pa integer; v_manque jsonb := '[]'::jsonb;
  v_stock_avant integer; v_quantite integer; v_cout_lot numeric; v_unit numeric;
  v_cmup_avant numeric; v_cmup_apres numeric;
  v_deja record; v_salaire numeric; v_caisse numeric; v_jour integer;
  v_conso jsonb := '{}'::jsonb;
  v_intermediaire numeric := 0; v_stock_comp numeric := 0; v_cmup_comp numeric := 0;
  v_comp_ref text; v_comp record; v_a_prendre numeric; v_restant numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_requete IS NULL OR p_requete !~ '^prod-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  IF coalesce(p_fonds_id,'') = '' OR coalesce(p_reference_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_lots < 1 OR v_lots > 99 OR v_lots IS DISTINCT FROM p_lots THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lots_invalides',
                              'minimum', 1, 'maximum', 99);
  END IF;
  v_nom_pj := CASE WHEN left(p_acteur,3) = 'pj:' THEN substr(p_acteur,4) ELSE p_acteur END;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  IF NOT public.fonds_acteur_present(v_nom_pj, v_data->'implantation') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  v_ref := v_data->'references'->p_reference_id;
  IF v_ref IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;
  IF coalesce(v_ref->>'recette_id','') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_sans_recette'); END IF;

  SELECT * INTO v_r FROM public.recettes_commerce WHERE id = v_ref->>'recette_id';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inexistante'); END IF;
  IF v_r.generique_id IS DISTINCT FROM (v_ref->>'generique_id') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'recette_hors_generique',
                              'recetteGenerique', v_r.generique_id,
                              'referenceGenerique', v_ref->>'generique_id'); END IF;
  IF coalesce(v_r.portions, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rendement_non_declare'); END IF;

  SELECT * INTO v_gen FROM public.fonds_generiques_accessibles(p_fonds_id)
   WHERE generique_id = v_ref->>'generique_id';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_hors_perimetre',
                              'generique', v_ref->>'generique_id'); END IF;

  SELECT * INTO v_deja FROM public.productions_references WHERE requete = p_requete;
  IF FOUND THEN
    IF v_deja.acteur IS DISTINCT FROM p_acteur OR v_deja.fonds_id IS DISTINCT FROM p_fonds_id
       OR v_deja.reference_id IS DISTINCT FROM p_reference_id OR v_deja.quantite IS DISTINCT FROM v_r.portions*v_lots THEN
      RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');
    END IF;
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'quantite', v_deja.quantite, 'coutUnitaire', v_deja.cout_unitaire);
  END IF;

  SELECT coalesce(pa, 0), coalesce(day, 1) INTO v_pa, v_jour
    FROM public.personnages_donnees WHERE name = v_nom_pj FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_pa_requis := greatest(0, coalesce(v_r.pa, 0)) * v_lots;
  IF v_pa < v_pa_requis THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', v_pa_requis, 'disponibles', v_pa,
                              'lots', v_lots); END IF;

  SELECT valeur::numeric INTO v_pa_val FROM public.entreprises_constantes
   WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
  IF v_pa_val IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_pa_non_declaree'); END IF;
  v_salaire := round(v_pa_requis * v_pa_val, 2);

  -- TRANSFORMATION D'UN STOCK (30 septembre 2026), cote fonds PJ. Meme regle
  -- et meme garde que le moteur historique : le niveau vient de la loi votee.
  IF public.matiere_refus_circuit_legal_lot(v_nom_pj, coalesce(v_r.materiaux, '{}'::jsonb), 'transformation') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal_lot(v_nom_pj, coalesce(v_r.materiaux, '{}'::jsonb), 'transformation');
  END IF;
  v_sm    := coalesce(v_data->'stockMatieres', '{}'::jsonb);
  v_couts := coalesce(v_data->'coutMoyenMatieres', '{}'::jsonb);
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(coalesce(v_r.materiaux, '{}'::jsonb)) LOOP
    v_besoin := (v_q#>>'{}')::numeric * v_lots;
    v_conso  := jsonb_set(v_conso, ARRAY[v_m], to_jsonb(v_besoin), true);
    v_dispo  := coalesce((v_sm->>v_m)::numeric, 0);
    IF v_dispo < v_besoin THEN
      v_manque := v_manque || jsonb_build_object('matiere', v_m, 'requis', v_besoin, 'dispo', v_dispo);
    END IF;
    v_cm := (v_couts->>v_m)::numeric;
    IF v_cm IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cout_matiere_inconnu', 'matiere', v_m);
    END IF;
    v_mat := v_mat + v_besoin * v_cm;
  END LOOP;
  IF jsonb_array_length(v_manque) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes',
                              'manquantes', v_manque, 'lots', v_lots);
  END IF;

  -- Consommer les composants ELECTRONIQUES deja fabriques dans ce fonds.
  -- Pas de conversion fictive de produits exotiques au stade de l'assemblage.
  v_intermediaire := coalesce((v_r.intermediaires->>'composants-electroniques')::numeric,0) * v_lots;
  IF v_intermediaire > 0 THEN
    v_restant := v_intermediaire;
    FOR v_comp IN
      SELECT ref.key AS id FROM jsonb_each(coalesce(v_data->'references','{}'::jsonb)) ref
      WHERE ref.value->>'generique_id'='composants-electroniques'
      ORDER BY ref.key
    LOOP
      EXIT WHEN v_restant=0;
      v_comp_ref := v_comp.id;
      v_stock_comp := greatest(0,coalesce((v_data->'stockReferences'->>v_comp_ref)::numeric,0));
      IF v_stock_comp=0 THEN CONTINUE; END IF;
      v_cmup_comp := (v_data->'coutMoyenReferences'->>v_comp_ref)::numeric;
      IF v_cmup_comp IS NULL OR v_cmup_comp < 0 THEN
        RETURN jsonb_build_object('ok',false,'raison','cout_composants_inconnu');
      END IF;
      v_a_prendre := least(v_restant,v_stock_comp);
      v_mat := v_mat + v_a_prendre * v_cmup_comp;
      v_data := jsonb_set(v_data,ARRAY['stockReferences',v_comp_ref],to_jsonb(v_stock_comp-v_a_prendre),true);
      v_restant := v_restant-v_a_prendre;
    END LOOP;
    IF v_restant>0 THEN
      RETURN jsonb_build_object('ok',false,'raison','composants_insuffisants',
        'requis',v_intermediaire,'composant','composants-electroniques');
    END IF;
    v_conso := jsonb_set(v_conso,ARRAY['composants-electroniques'],to_jsonb(v_intermediaire),true);
  END IF;

  v_quantite := v_r.portions * v_lots;
  v_max_ref  := nullif((v_data->'parametres'->'stockMaxReferences'->>p_reference_id)::integer, 0);
  v_stock_avant := greatest(0, coalesce((v_data->'stockReferences'->>p_reference_id)::numeric, 0))::integer;
  IF v_max_ref IS NOT NULL AND v_stock_avant + v_quantite > v_max_ref THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_max_reference_depasse',
      'stock', v_stock_avant, 'rendement', v_quantite, 'rendementLot', v_r.portions,
      'lots', v_lots, 'maximum', v_max_ref);
  END IF;

  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));
  IF v_caisse < v_salaire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                              'caisse', v_caisse, 'salaire', v_salaire, 'lots', v_lots);
  END IF;

  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_conso) LOOP
    IF v_m = 'composants-electroniques' THEN CONTINUE; END IF;
    v_sm := jsonb_set(v_sm, ARRAY[v_m],
              to_jsonb(coalesce((v_sm->>v_m)::numeric, 0) - (v_q#>>'{}')::numeric));
  END LOOP;

  v_cout_lot := v_mat + v_pa_requis * v_pa_val;
  v_unit     := v_cout_lot / v_quantite;

  v_cmup_avant := (v_data->'coutMoyenReferences'->>p_reference_id)::numeric;
  IF v_stock_avant <= 0 OR v_cmup_avant IS NULL THEN
    v_cmup_apres := v_unit;
  ELSE
    v_cmup_apres := (v_stock_avant * v_cmup_avant + v_cout_lot) / (v_stock_avant + v_quantite);
  END IF;

  v_data := jsonb_set(v_data, '{stockMatieres}', v_sm);
  v_data := jsonb_set(v_data, ARRAY['stockReferences', p_reference_id],
              to_jsonb(v_stock_avant + v_quantite), true);
  v_data := jsonb_set(v_data, ARRAY['coutMoyenReferences', p_reference_id],
              to_jsonb(v_cmup_apres), true);
  v_data := v_data || jsonb_build_object('caisse', v_caisse - v_salaire);
  v_data := public.entreprise_ajouter_historique(v_data, -v_salaire,
              'Production de ' || coalesce(v_ref->>'nom', p_reference_id)
              || ' (' || v_lots || ' lot(s), ' || v_quantite || ' unites) — ' || v_nom_pj, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  UPDATE public.personnages_donnees
     SET pa      = v_pa - v_pa_requis,
         arg     = COALESCE(arg, 0)     + v_salaire,
         liquide = COALESCE(liquide, 0) + v_salaire,
         updated_at = now()
   WHERE name = v_nom_pj;

  INSERT INTO public.productions_references
    (requete, fonds_id, reference_id, generique_id, recette_id, acteur,
     quantite, pa, matieres, cout_matieres, cout_lot, cout_unitaire)
  VALUES (p_requete, p_fonds_id, p_reference_id, v_r.generique_id, v_r.id, p_acteur,
     v_quantite, v_pa_requis, v_conso, v_mat, v_cout_lot, v_unit);

  RETURN jsonb_build_object('ok', true, 'rejeu', false,
    'referenceId', p_reference_id, 'recette', v_r.id, 'generique', v_r.generique_id,
    'lots', v_lots, 'rendementLot', v_r.portions,
    'quantite', v_quantite, 'stockAvant', v_stock_avant, 'stockApres', v_stock_avant + v_quantite,
    'paPreleves', v_pa_requis, 'paRestants', v_pa - v_pa_requis,
    'salaire', v_salaire, 'caisse', v_caisse - v_salaire,
    'coutMatieres', v_mat, 'coutLot', v_cout_lot, 'coutUnitaireLot', v_unit,
    'cmupAvant', v_cmup_avant, 'cmupApres', v_cmup_apres,
    'matieresConsommees', v_conso);
END; $function$;


COMMIT;
