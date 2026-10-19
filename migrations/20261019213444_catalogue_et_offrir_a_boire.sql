-- PREPAREE UNIQUEMENT : catalogue vivant et prevol requis avant application MCP.
-- Aucune donnee joueur transformee. Les anciennes tournees conservent leur contrat.
-- La vente reste le moteur commerce existant, prive, avec tarif serveur optionnel.
BEGIN;
DO $prevol$ BEGIN
 IF coalesce(md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.commerce_vendre_produit(text,text,jsonb,text,text,integer,integer,text)'))), 'absent') NOT IN ('0faf68e13fd68cbd331cbbc5ffa526f4','7f3a81e29c7552624337be226e016133') THEN
  RAISE EXCEPTION 'precondition_definition_differente: commerce_vendre_produit'; END IF;
END $prevol$;
DO $prevol$ BEGIN
 IF coalesce(md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.commerce_produire(text,text,text,text)'))), 'absent') NOT IN ('ec54dda4bec2c0da19d923f3d10e3e4c','e20b49be94dc6a17baa8981e0038f8d6') THEN
  RAISE EXCEPTION 'precondition_definition_differente: commerce_produire'; END IF;
END $prevol$;
DO $prevol$ BEGIN
 IF coalesce(md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.fonds_reference_produire_lots(text,text,text,text,integer)'))), 'absent') NOT IN ('ab95c733be25d3da5c3c2874c100557f','f74eb7dc6f1cb4c5c5e6ea86149c5b60') THEN
  RAISE EXCEPTION 'precondition_definition_differente: fonds_reference_produire_lots'; END IF;
END $prevol$;
DO $prevol$ BEGIN
 IF coalesce(md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.tournee_cloturer(text,boolean)'))), 'absent') NOT IN ('d6e6a969f92ca67776707cfc0b385644','d185cadc94c04be84feb54ea0be39fca') THEN
  RAISE EXCEPTION 'precondition_definition_differente: tournee_cloturer'; END IF;
END $prevol$;
-- Meme registre salaries que employer_fonds ; aucun pouvoir de gestion n'en derive.
CREATE OR REPLACE FUNCTION public.commerce_production_autorisee(p_data jsonb,p_acteur text) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $fn$
 SELECT coalesce(p_acteur,'')<>'' AND (
  regexp_replace(coalesce(p_data->>'proprietaire',''),'^pj:','')=regexp_replace(p_acteur,'^pj:','')
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_data->'salaries')='array' THEN p_data->'salaries' ELSE '[]'::jsonb END) s
    WHERE s->'actif'='true'::jsonb AND regexp_replace(s->>'ref','^pj:','')=regexp_replace(p_acteur,'^pj:','')));
$fn$;
REVOKE ALL ON FUNCTION public.commerce_production_autorisee(jsonb,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.commerce_produire(p_acteur text, p_entreprise text, p_recette text, p_ordre text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_type text; v_pays text; v_ville text; v_bat text; v_jour integer;
  v_rec record; v_prod record; v_prix_fixe numeric;
  v_pa_requis integer; v_salaire numeric; v_portions integer; v_materiaux jsonb;
  v_sm jsonb; v_sp jsonb; v_stock numeric; v_plafond numeric; v_declare numeric; v_smc numeric;
  v_caisse numeric; v_categorie text; v_caisse_id text; v_r jsonb;
  v_pa integer; v_arg numeric; v_liquide numeric;
  v_m text; v_q jsonb; v_dispo numeric; v_cout numeric; v_mo numeric;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF NOT public.commerce_production_autorisee(v_data,p_acteur) THEN
    RETURN jsonb_build_object('ok',false,'raison','production_non_autorisee'); END IF;
  v_type := COALESCE(v_data->>'type','');
  v_pays := COALESCE(v_data->>'country','republic');
  v_ville:= COALESCE(v_data->>'city','capitale');
  v_bat  := COALESCE(v_data->>'buildingId','');

  IF v_type = 'armurerie' THEN
    SELECT * INTO v_prod FROM public.recettes_production WHERE id = p_recette AND pays = v_pays;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue'); END IF;
    v_materiaux := v_prod.materiaux;
    v_portions  := 1;
    v_prix_fixe := NULL;
    SELECT valeur INTO v_pa_requis FROM public.entreprises_constantes WHERE cle = 'pa_production_armurerie';
    SELECT valeur INTO v_salaire   FROM public.entreprises_constantes WHERE cle = 'salaire_production_armurerie';
  ELSE
    SELECT * INTO v_rec FROM public.recettes_commerce WHERE id = p_recette;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue'); END IF;
    IF NOT (COALESCE(v_data->'carte','[]'::jsonb) @> jsonb_build_array(to_jsonb(p_recette))) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_carte');
    END IF;
    IF v_rec.types_autorises IS NOT NULL THEN
      IF NOT (v_rec.types_autorises @> jsonb_build_array(to_jsonb(v_type))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'type_non_autorise');
      END IF;
    END IF;
    IF v_rec.pays_autorises IS NOT NULL THEN
      IF NOT (v_rec.pays_autorises @> jsonb_build_array(to_jsonb(v_pays))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_autorise');
      END IF;
    END IF;
    IF v_rec.villes_autorisees IS NOT NULL THEN
      IF NOT (v_rec.villes_autorisees @> jsonb_build_array(to_jsonb(v_ville))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'ville_non_autorisee');
      END IF;
    END IF;
    IF v_rec.buildings_autorises IS NOT NULL THEN
      IF NOT (v_rec.buildings_autorises @> jsonb_build_array(to_jsonb(v_bat))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'batiment_non_autorise');
      END IF;
    END IF;
    v_materiaux := v_rec.materiaux;
    v_portions  := v_rec.portions;
    v_pa_requis := v_rec.pa;
    v_prix_fixe := v_rec.prix_fixe;
    SELECT valeur INTO v_mo FROM public.entreprises_constantes WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
    v_salaire := v_rec.pa * COALESCE(v_mo, 0);
  END IF;

  v_sp := COALESCE(v_data->'stockProduits','{}'::jsonb);
  v_stock := COALESCE((v_sp->>p_recette)::numeric, 0);
  v_declare := (v_data->'parametres'->'stockMax'->>p_recette)::numeric;
  IF v_type = 'armurerie' THEN
    v_plafond := v_declare;
  ELSE
    SELECT valeur INTO v_smc FROM public.entreprises_constantes WHERE cle = 'stock_max_commerce';
    v_plafond := CASE WHEN v_declare IS NOT NULL THEN LEAST(v_declare, COALESCE(v_smc,20))
                      ELSE COALESCE(v_smc,20) END;
  END IF;
  IF v_plafond IS NOT NULL AND v_stock + v_portions > v_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein', 'plafond', v_plafond);
  END IF;

  -- TRANSFORMATION D'UN STOCK (30 septembre 2026). Une loi appliquee peut
  -- interdire de transformer la matiere en produits finis (cas B). Le stock
  -- reste possede et consommable : seule la fabrication est fermee. Verifie
  -- avant toute lecture de stock et toute ecriture.
  IF public.matiere_refus_circuit_legal_lot(p_acteur, v_materiaux, 'transformation') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal_lot(p_acteur, v_materiaux, 'transformation');
  END IF;
  v_sm := COALESCE(v_data->'stockMatieres','{}'::jsonb);
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_materiaux) LOOP
    v_dispo := COALESCE((v_sm->>v_m)::numeric, 0);
    IF v_dispo < (v_q#>>'{}')::numeric THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes',
                                'matiere', v_m, 'disponible', v_dispo);
    END IF;
  END LOOP;

  IF COALESCE(p_ordre,'') <> '' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, 0, 0);
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','ordre_refuse'));
    END IF;
  END IF;

  SELECT COALESCE(pa,0), COALESCE(arg,0), COALESCE(liquide,0), COALESCE(day,1)
    INTO v_pa, v_arg, v_liquide, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_pa < COALESCE(v_pa_requis,0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa);
  END IF;

  v_categorie := CASE v_type WHEN 'buvette' THEN 'stade' WHEN 'marche' THEN 'marche' ELSE NULL END;
  v_caisse := GREATEST(0, COALESCE((v_data->>'caisse')::numeric, 0));
  IF v_categorie IS NOT NULL THEN
    v_caisse_id := v_pays || '_' || v_categorie || '_' || v_ville;
    v_r := public.caisse_institution_mouvement(v_caisse_id, -v_salaire, false);
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
    END IF;
  ELSE
    IF v_caisse < v_salaire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
    END IF;
    v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_salaire), true);
  END IF;

  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_materiaux) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[v_m],
             to_jsonb(COALESCE((v_sm->>v_m)::numeric,0) - (v_q#>>'{}')::numeric));
  END LOOP;
  v_data := jsonb_set(v_data, '{stockMatieres}', v_sm, true);
  v_data := jsonb_set(v_data, '{stockProduits}',
                      jsonb_set(v_sp, ARRAY[p_recette], to_jsonb(v_stock + v_portions)), true);

  IF v_type <> 'armurerie' THEN
    IF COALESCE(v_data->>'proprietaire','PNJ') = 'PNJ' AND v_prix_fixe IS NULL THEN
      v_cout := public.commerce_cout_revient_portion(v_data, p_recette);
      IF v_cout IS NOT NULL THEN
        v_data := jsonb_set(v_data, ARRAY['parametres','prixVente',p_recette],
                            to_jsonb(round(v_cout * 2)), true);
      END IF;
    END IF;
  END IF;

  v_data := public.entreprise_ajouter_historique(v_data, -v_salaire,
              'Production de ' || p_recette || ' (' || v_portions || ' portions) — ' || p_acteur, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  UPDATE public.personnages_donnees
     SET pa = v_pa - COALESCE(v_pa_requis,0),
         arg = v_arg + v_salaire, liquide = v_liquide + v_salaire, updated_at = now()
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'recette', p_recette, 'portions', v_portions,
    'salaire', v_salaire, 'paPreleves', COALESCE(v_pa_requis,0),
    'pa', v_pa - COALESCE(v_pa_requis,0), 'arg', v_arg + v_salaire,
    'liquide', v_liquide + v_salaire,
    'stockProduit', v_stock + v_portions,
    'prixVente', v_data->'parametres'->'prixVente'->p_recette);
END; $function$;
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
  IF NOT public.commerce_production_autorisee(v_data,v_nom_pj) THEN
    RETURN jsonb_build_object('ok',false,'raison','production_non_autorisee'); END IF;
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
CREATE OR REPLACE FUNCTION public.commerce_vendre_produit_interne(p_acteur text, p_entreprise text, p_produits jsonb, p_mode text DEFAULT 'comptoir'::text, p_ordre text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0, p_regle_pa text DEFAULT NULL::text, p_prix_tournee numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_type text; v_pays text; v_ville text; v_jour integer;
  v_sp jsonb; v_ligne jsonb; v_id text; v_qte numeric; v_stock numeric; v_prix numeric;
  v_dynamique numeric := 0; v_assiette numeric; v_net numeric;
  v_caisse numeric; v_categorie text; v_caisse_id text;
  v_r jsonb; v_taxe jsonb; v_au_catalogue boolean; v_livraison jsonb := '[]'::jsonb;
  v_rec record; v_arg numeric; v_liquide numeric; v_pa_reste integer; v_libelle text := '';
  v_pa_metier numeric := 0; v_pa_actuel integer;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);
  IF p_mode NOT IN ('comptoir', 'service', 'marche_noir') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide');
  END IF;
  IF p_mode = 'service' AND (COALESCE(p_ordre,'') = '' OR COALESCE(p_cost,0) <= 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_requis');
  END IF;
  IF p_produits IS NULL OR jsonb_typeof(p_produits) <> 'array' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'articles_invalides');
  END IF;
  IF jsonb_array_length(p_produits) = 0 AND p_mode <> 'service' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'articles_invalides');
  END IF;

  IF COALESCE(p_regle_pa,'') <> '' THEN
    SELECT valeur INTO v_pa_metier FROM public.entreprises_constantes WHERE cle = p_regle_pa;
    IF v_pa_metier IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'regle_pa_inconnue', 'cle', p_regle_pa);
    END IF;
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_type  := COALESCE(v_data->>'type','');
  v_pays  := COALESCE(v_data->>'country','republic');
  v_ville := COALESCE(v_data->>'city','capitale');
  v_sp    := COALESCE(v_data->'stockProduits', '{}'::jsonb);

  FOR v_ligne IN SELECT value FROM jsonb_array_elements(p_produits) LOOP
    v_id  := v_ligne->>'produit';
    v_qte := COALESCE((v_ligne->>'qte')::numeric, 1);
    IF COALESCE(v_id,'') = '' OR v_qte <= 0 OR v_qte <> trunc(v_qte) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'articles_invalides');
    END IF;
    IF v_type = 'armurerie' THEN
      SELECT EXISTS (SELECT 1 FROM public.recettes_production
                      WHERE id = v_id AND pays = v_pays) INTO v_au_catalogue;
    ELSE
      v_au_catalogue := COALESCE(v_data->'carte','[]'::jsonb) @> jsonb_build_array(to_jsonb(v_id));
    END IF;
    IF NOT v_au_catalogue THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'produit_non_propose', 'produit', v_id);
    END IF;
    v_stock := COALESCE((v_sp->>v_id)::numeric, 0);
    IF v_stock < v_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant',
                                'produit', v_id, 'stock', v_stock);
    END IF;
    IF p_mode <> 'service' THEN
      v_prix := coalesce(p_prix_tournee, (v_data->'parametres'->'prixVente'->>v_id)::numeric);
      IF v_prix IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'prix_non_defini', 'produit', v_id);
      END IF;
      v_dynamique := v_dynamique + v_prix * v_qte
                     * CASE WHEN p_mode = 'marche_noir' THEN 3 ELSE 1 END;
    END IF;
  END LOOP;

  SELECT COALESCE(day,1), COALESCE(pa,0) INTO v_jour, v_pa_actuel
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa_metier > 0 AND v_pa_actuel < v_pa_metier THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa_actuel);
  END IF;

  IF COALESCE(p_ordre,'') <> '' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, COALESCE(p_pa,0), COALESCE(p_cost,0));
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','paiement_refuse'),
                                'detail', v_r);
    END IF;
  END IF;

  IF v_pa_metier > 0 THEN
    UPDATE public.personnages_donnees SET pa = GREATEST(0, pa - v_pa_metier), updated_at = now()
     WHERE name = p_acteur;
  END IF;

  IF v_dynamique > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_dynamique) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'total', v_dynamique);
    END IF;
  END IF;

  SELECT COALESCE(arg,0), COALESCE(liquide,0), COALESCE(pa,0)
    INTO v_arg, v_liquide, v_pa_reste
    FROM public.personnages_donnees WHERE name = p_acteur;

  v_assiette := CASE p_mode WHEN 'service' THEN COALESCE(p_cost,0) ELSE v_dynamique END;
  IF p_mode = 'marche_noir' THEN
    v_net := 0;
  ELSE
    v_taxe := public.appliquer_taxe_transaction(v_pays, v_ville, v_assiette);
    v_net := COALESCE((v_taxe->>'net')::numeric, v_assiette);
    v_categorie := CASE v_type WHEN 'buvette' THEN 'stade' WHEN 'marche' THEN 'marche' ELSE NULL END;
    IF v_categorie IS NOT NULL THEN
      v_caisse_id := v_pays || '_' || v_categorie || '_' || v_ville;
      PERFORM public.caisse_institution_mouvement(v_caisse_id, v_net, false);
    ELSE
      v_caisse := GREATEST(0, COALESCE((v_data->>'caisse')::numeric, 0));
      v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse + v_net), true);
    END IF;
  END IF;

  FOR v_ligne IN SELECT value FROM jsonb_array_elements(p_produits) LOOP
    v_id  := v_ligne->>'produit';
    v_qte := COALESCE((v_ligne->>'qte')::numeric, 1);
    v_stock := COALESCE((v_sp->>v_id)::numeric, 0);
    v_sp := jsonb_set(v_sp, ARRAY[v_id], to_jsonb(v_stock - v_qte));
    v_libelle := v_libelle || CASE WHEN v_libelle = '' THEN '' ELSE ', ' END || v_id || ' x' || v_qte;
    SELECT * INTO v_rec FROM public.recettes_commerce WHERE id = v_id;
    v_livraison := v_livraison || jsonb_build_array(jsonb_build_object(
      'produit', v_id, 'qte', v_qte,
      'prixUnitaire', coalesce(p_prix_tournee, (v_data->'parametres'->'prixVente'->>v_id)::numeric),
      'label', v_rec.label, 'categorie', v_rec.categorie,
      'effets', COALESCE(v_rec.effets, '{}'::jsonb), 'icone', v_rec.icone,
      'image', v_rec.image, 'description', v_rec.description,
      'familleProduitMarche', v_rec.famille_produit_marche,
      'bonusIntegrationVille', v_rec.bonus_integration_ville));
  END LOOP;
  v_data := jsonb_set(v_data, '{stockProduits}', v_sp, true);

  v_data := public.entreprise_ajouter_historique(v_data, v_net,
              CASE WHEN p_mode = 'marche_noir' THEN 'Vol — ' ELSE 'Vente — ' END
              || COALESCE(NULLIF(v_libelle,''), 'prestation') || ' — ' || p_acteur, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'mode', p_mode,
    'total', v_dynamique, 'assiette', v_assiette, 'net', v_net,
    'paMetier', v_pa_metier,
    'arg', v_arg, 'liquide', v_liquide, 'pa', v_pa_reste,
    'livraison', v_livraison);
END; $function$;
REVOKE ALL ON FUNCTION public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric) FROM PUBLIC, anon, authenticated, service_role;
CREATE OR REPLACE FUNCTION public.commerce_vendre_produit(p_acteur text, p_entreprise text, p_produits jsonb, p_mode text DEFAULT 'comptoir', p_ordre text DEFAULT NULL, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0, p_regle_pa text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
 SELECT public.commerce_vendre_produit_interne(p_acteur,p_entreprise,p_produits,p_mode,p_ordre,p_pa,p_cost,p_regle_pa,NULL);
$fn$;
ALTER TABLE public.tournees ADD COLUMN IF NOT EXISTS contrat text;
ALTER TABLE public.tournees ADD COLUMN IF NOT EXISTS entreprise_id text;
ALTER TABLE public.tournees ADD COLUMN IF NOT EXISTS invites_initiales text[];
ALTER TABLE public.tournees ADD COLUMN IF NOT EXISTS resultat jsonb;

-- Les droits RLS historiques ne permettent pas de fabriquer/modifier un acte v1 en REST.
CREATE OR REPLACE FUNCTION public.tournee_proteger_contrat() RETURNS trigger
LANGUAGE plpgsql SET search_path=public,pg_temp AS $fn$
DECLARE v_nouveau boolean:=false; v_ancien boolean:=false;
BEGIN
 IF TG_TABLE_NAME='tournees' THEN
  IF TG_OP<>'DELETE' THEN v_nouveau:=NEW.contrat IS NOT NULL; END IF;
  IF TG_OP<>'INSERT' THEN v_ancien:=OLD.contrat IS NOT NULL; END IF;
 ELSE
  IF TG_OP<>'DELETE' THEN SELECT contrat IS NOT NULL INTO v_nouveau FROM public.tournees WHERE id=NEW.tournee_id; END IF;
  IF TG_OP<>'INSERT' THEN SELECT contrat IS NOT NULL INTO v_ancien FROM public.tournees WHERE id=OLD.tournee_id; END IF;
 END IF;
 IF TG_TABLE_NAME='tournees' AND TG_OP='INSERT' THEN v_nouveau:=true; END IF;
 IF (coalesce(v_nouveau,false) OR coalesce(v_ancien,false)) AND current_user NOT IN ('postgres','supabase_admin') THEN
  RAISE EXCEPTION 'tournee_ecriture_par_rpc_requise' USING ERRCODE='42501'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION public.tournee_proteger_contrat() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS tournee_contrat_protege ON public.tournees;
CREATE TRIGGER tournee_contrat_protege BEFORE INSERT OR UPDATE OR DELETE ON public.tournees FOR EACH ROW EXECUTE FUNCTION public.tournee_proteger_contrat();
DROP TRIGGER IF EXISTS invitation_tournee_contrat_protege ON public.invitations_diner;
CREATE TRIGGER invitation_tournee_contrat_protege BEFORE INSERT OR UPDATE OR DELETE ON public.invitations_diner FOR EACH ROW EXECUTE FUNCTION public.tournee_proteger_contrat();

CREATE OR REPLACE FUNCTION public.tournee_contrat_lire() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
 SELECT jsonb_build_object('ok',public.mon_personnage() IS NOT NULL,'version',1);
$fn$;
CREATE OR REPLACE FUNCTION public.tournee_creer(p_id text,p_entreprise text,p_recette text,p_invites text[]) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
DECLARE v_moi text:=public.mon_personnage(); v_data jsonb; v_p public.personnages_donnees; t public.tournees; v_invite text; v_invites text[];
BEGIN
 IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_id IS NULL OR p_id !~ '^tournee-[A-Za-z0-9-]{10,80}$' OR coalesce(cardinality(p_invites),0) NOT BETWEEN 1 AND 50 OR v_moi=ANY(p_invites) OR array_position(p_invites,NULL) IS NOT NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
 SELECT array_agg(DISTINCT x ORDER BY x) INTO v_invites FROM unnest(p_invites) x;
 IF cardinality(v_invites)<>cardinality(p_invites) THEN RETURN jsonb_build_object('ok',false,'raison','invites_dupliques'); END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('tournee:'||p_id,0));
 SELECT * INTO t FROM public.tournees WHERE id=p_id FOR UPDATE;
 IF FOUND THEN
  IF t.offreur=v_moi AND t.entreprise_id=p_entreprise AND t.recette_id=p_recette AND t.invites_initiales=v_invites AND t.contrat='boire_v1' THEN
   RETURN jsonb_build_object('ok',true,'id',t.id,'rejeu',true); END IF;
  RETURN jsonb_build_object('ok',false,'raison','requete_incompatible'); END IF;
 SELECT data INTO v_data FROM public.entreprises WHERE id=p_entreprise FOR UPDATE;
 IF v_data IS NULL OR NOT(coalesce(v_data->'carte','[]') @> jsonb_build_array(p_recette)) OR NOT EXISTS(SELECT 1 FROM public.recettes_commerce WHERE id=p_recette AND categorie='boisson') THEN
  RETURN jsonb_build_object('ok',false,'raison','boisson_non_proposee'); END IF;
 -- Ordre de verrouillage commun a tous les participants, y compris deux organisateurs concurrents.
 PERFORM 1 FROM public.personnages_donnees WHERE name=ANY(v_invites||ARRAY[v_moi]) ORDER BY name FOR UPDATE;
 SELECT * INTO v_p FROM public.personnages_donnees WHERE name=v_moi;
 IF NOT FOUND OR v_p.country IS DISTINCT FROM v_data->>'country' OR v_p.current_city IS DISTINCT FROM v_data->>'city' OR v_p.current_building IS DISTINCT FROM v_data->>'buildingId' OR v_p.current_room IS NULL OR
   (v_data->>'roomId' IS NOT NULL AND v_p.current_room IS DISTINCT FROM v_data->>'roomId') THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 FOREACH v_invite IN ARRAY v_invites LOOP
  IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=v_invite AND country=v_p.country AND current_city=v_p.current_city AND current_building=v_p.current_building AND current_room=v_p.current_room) THEN
   RETURN jsonb_build_object('ok',false,'raison','invite_absent'); END IF;
 END LOOP;
 INSERT INTO public.tournees(id,country,ville,offreur,building_id,room_id,commerce_type,recette_id,prix_unitaire_reference,pnj_resultats,expires_at,contrat,entreprise_id,invites_initiales)
 VALUES(p_id,v_p.country,v_p.current_city,v_moi,v_p.current_building,v_p.current_room,v_data->>'type',p_recette,25,'[]',now()+interval '5 minutes','boire_v1',p_entreprise,v_invites);
 INSERT INTO public.invitations_diner(inviteur,invite,country,city,building_id,room_id,cout,type,tournee_id)
 SELECT v_moi,x,v_p.country,v_p.current_city,v_p.current_building,v_p.current_room,25,'tournee_boisson',p_id FROM unnest(v_invites) x;
 RETURN jsonb_build_object('ok',true,'id',p_id);
END $fn$;

CREATE OR REPLACE FUNCTION public.tournee_repondre(p_invitation bigint,p_accepte boolean) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
DECLARE v_moi text:=public.mon_personnage(); i public.invitations_diner; t public.tournees; v_id text; v_statut text:=CASE WHEN p_accepte THEN 'acceptee' ELSE 'refusee' END;
BEGIN
 IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 SELECT tournee_id INTO v_id FROM public.invitations_diner WHERE id=p_invitation AND invite=v_moi;
 SELECT * INTO t FROM public.tournees WHERE id=v_id FOR UPDATE;
 IF NOT FOUND OR t.contrat IS DISTINCT FROM 'boire_v1' THEN RETURN jsonb_build_object('ok',false,'raison','invitation_absente'); END IF;
 SELECT * INTO i FROM public.invitations_diner WHERE id=p_invitation AND invite=v_moi FOR UPDATE;
 IF p_accepte IS NULL AND t.resultat IS NOT NULL THEN
  UPDATE public.invitations_diner SET statut='vue' WHERE id=i.id;
  RETURN jsonb_build_object('ok',true); END IF;
 IF p_accepte IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','invitation_non_resolue'); END IF;
 IF i.statut=v_statut THEN RETURN jsonb_build_object('ok',true,'rejeu',true); END IF;
 IF i.statut<>'attente' OR t.statut<>'en_attente' OR now()>=t.expires_at THEN RETURN jsonb_build_object('ok',false,'raison','invitation_close'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=v_moi AND country=t.country AND current_city=t.ville AND current_building=t.building_id AND current_room=t.room_id) THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 UPDATE public.invitations_diner SET statut=v_statut WHERE id=p_invitation;
 RETURN jsonb_build_object('ok',true);
END $fn$;

-- Privee, appelee UNIQUEMENT par tournee_cloturer, sans vente prealable cote navigateur.
CREATE OR REPLACE FUNCTION public.tournee_cloturer_boire(p_tournee_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
DECLARE t public.tournees; v_moi text:=public.mon_personnage(); v_n integer; v_qte integer; v_r jsonb; v_erreur text; v_participants text[];
BEGIN
 IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 SELECT * INTO t FROM public.tournees WHERE id=p_tournee_id FOR UPDATE;
 IF NOT FOUND OR t.contrat IS DISTINCT FROM 'boire_v1' OR t.offreur IS DISTINCT FROM v_moi THEN RETURN jsonb_build_object('ok',false,'raison','pas_mon_offre'); END IF;
 IF t.resultat IS NOT NULL THEN RETURN t.resultat||jsonb_build_object('rejeu',true); END IF;
 IF t.statut NOT IN ('en_attente','en_resolution') THEN RETURN jsonb_build_object('ok',false,'raison','tournee_close'); END IF;
 IF t.expires_at>now() AND EXISTS(SELECT 1 FROM public.invitations_diner WHERE tournee_id=t.id AND statut='attente') THEN RETURN jsonb_build_object('ok',false,'raison','reponses_en_attente'); END IF;
 -- Meme ordre entreprise puis personnages que le moteur de vente et le lancement.
 PERFORM 1 FROM public.entreprises WHERE id=t.entreprise_id FOR UPDATE;
 PERFORM 1 FROM public.personnages_donnees WHERE name=ANY(t.invites_initiales||ARRAY[v_moi]) ORDER BY name FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=v_moi AND country=t.country AND current_city=t.ville AND current_building=t.building_id AND current_room=t.room_id) THEN
  v_r:=jsonb_build_object('ok',false,'raison','action_obsolete');
 ELSE
  SELECT coalesce(array_agg(DISTINCT d.name ORDER BY d.name),'{}'::text[]) INTO v_participants FROM public.invitations_diner i JOIN public.personnages_donnees d ON d.name=i.invite
   WHERE i.tournee_id=t.id AND i.statut='acceptee' AND d.country=t.country AND d.current_city=t.ville AND d.current_building=t.building_id AND d.current_room=t.room_id;
  v_n:=cardinality(v_participants); v_qte:=v_n+1;
  IF (SELECT valeur FROM public.entreprises_constantes WHERE cle='pa_tournee') IS DISTINCT FROM 1::numeric THEN
   RETURN jsonb_build_object('ok',false,'raison','contrat_pa_incompatible'); END IF;
  -- Sous-transaction : les moteurs historiques peuvent refuser apres un debit de PA.
  -- Le refus est leve puis capture : toutes ses ecritures sont annulees ensemble.
  BEGIN
   v_r:=public.commerce_vendre_produit_interne(v_moi,t.entreprise_id,jsonb_build_array(jsonb_build_object('produit',t.recette_id,'qte',v_qte)),'comptoir',NULL,0,0,'pa_tournee',25);
   IF v_r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'tournee_vente_refusee' USING DETAIL=v_r::text; END IF;
  EXCEPTION WHEN raise_exception THEN
   IF SQLERRM<>'tournee_vente_refusee' THEN RAISE; END IF;
   GET STACKED DIAGNOSTICS v_erreur=PG_EXCEPTION_DETAIL; v_r:=v_erreur::jsonb;
  END;
  IF v_r->>'ok'='true' THEN
   IF v_n=0 THEN
    UPDATE public.personnages_donnees SET moral=greatest(0,coalesce(moral,75)-5),updated_at=now() WHERE name=v_moi;
   ELSE
    UPDATE public.personnages_donnees SET hp=least(100,coalesce(hp,100)+5),
     resources=jsonb_set(coalesce(resources,'{}'),'{inf}',to_jsonb(least(100,coalesce((resources->>'inf')::numeric,0)+2)),true),
     stats=jsonb_set(coalesce(stats,'{}'),'{ENT}',to_jsonb(greatest(coalesce((stats->>'ENT')::numeric,0),least(20,coalesce((stats->>'ENT')::numeric,0)+2))),true),updated_at=now()
     WHERE name=ANY(v_participants||ARRAY[v_moi]);
   END IF;
   v_r:=jsonb_build_object('ok',true,'servie',true,'acceptants',v_n,'verres',v_qte,'total',25*v_qte,'pa',1,'seul',v_n=0);
  END IF;
 END IF;
 UPDATE public.invitations_diner SET statut='refusee' WHERE tournee_id=t.id AND statut='attente';
 UPDATE public.tournees SET statut=CASE WHEN v_r->>'ok'='true' THEN 'resolue' ELSE 'annulee' END,pa_debite=v_r->>'ok'='true',resultat=v_r WHERE id=t.id;
 RETURN v_r;
END $fn$;
REVOKE ALL ON FUNCTION public.tournee_cloturer_boire(text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.tournee_cloturer(p_tournee_id text, p_servie boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  t public.tournees; v_moi text; v_credites integer := 0; v_supprimees integer := 0;
  v_n integer; r record;
BEGIN
  SELECT * INTO t FROM public.tournees WHERE id = p_tournee_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'tournee_introuvable'); END IF;

  -- SEUL L'OFFREUR CLOT SA TOURNEE (le serveur traverse : mon_personnage() rend NULL pour lui).
  v_moi := public.mon_personnage();
  IF v_moi IS NOT NULL AND v_moi IS DISTINCT FROM t.offreur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_offre');
  END IF;

  IF t.contrat='boire_v1' THEN RETURN public.tournee_cloturer_boire(p_tournee_id); END IF;

  -- LE COMPARE-AND-SWAP : seule une tournee revendiquee se clot, et une seule fois.
  IF t.statut <> 'en_resolution' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_resolution', 'statut', t.statut);
  END IF;

  IF coalesce(p_servie, false) THEN
    -- LE CREDIT DES INVITES, ENFIN APPLIQUE -- et dans la meme transaction que la cloture.
    -- Il vise la TABLE, pas la vue : c'est la vue qui refusait la fiche d'autrui.
    FOR r IN SELECT i.invite FROM public.invitations_diner i
              WHERE i.tournee_id = p_tournee_id AND i.statut = 'acceptee'
    LOOP
      UPDATE public.personnages_donnees d
         SET moral = least(100, coalesce(d.moral, 75) + 2),
             stats = CASE
               WHEN coalesce((d.stats ->> 'ENT')::numeric, 0) < 20
                 THEN jsonb_set(coalesce(d.stats, '{}'::jsonb), '{ENT}',
                        to_jsonb(least(20, coalesce((d.stats ->> 'ENT')::numeric, 0) + 1)), true)
               ELSE coalesce(d.stats, '{}'::jsonb) END
       WHERE d.name = r.invite;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_credites := v_credites + v_n;
    END LOOP;
  END IF;

  DELETE FROM public.invitations_diner WHERE tournee_id = p_tournee_id;
  GET DIAGNOSTICS v_supprimees = ROW_COUNT;

  UPDATE public.tournees
     SET statut = 'resolue',
         pa_debite = CASE WHEN coalesce(p_servie,false) THEN true ELSE coalesce(pa_debite,false) END
   WHERE id = p_tournee_id AND statut = 'en_resolution';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'tournee_cloturer : la cloture n''a pas pris sur %', p_tournee_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'servie', coalesce(p_servie,false),
    'credites', v_credites, 'invitations_supprimees', v_supprimees);
END; $function$;
REVOKE ALL ON FUNCTION public.tournee_contrat_lire() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.tournee_contrat_lire() TO authenticated;
REVOKE ALL ON FUNCTION public.tournee_creer(text,text,text,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.tournee_creer(text,text,text,text[]) TO authenticated;
REVOKE ALL ON FUNCTION public.tournee_repondre(bigint,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.tournee_repondre(bigint,boolean) TO authenticated;
COMMIT;
