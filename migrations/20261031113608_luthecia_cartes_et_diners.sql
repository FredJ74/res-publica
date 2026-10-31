-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261019221500_luthecia_cartes_et_diners.sql ; aucun changement de règle.
-- PREPAREE. Requiert la migration catalogue/tournee et un prevol vivant conforme.
-- Arbitrage valide : boissons 25 FR, neuf verres, marge MINIMALE x2 ; pas de changement general PNJ.
BEGIN;
DO $nouveau$ BEGIN IF to_regprocedure('public.restaurant_luthecia_est_commerce(jsonb)') IS NOT NULL AND md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_luthecia_est_commerce(jsonb)'))) IS DISTINCT FROM 'ff46b5a0cdb7d2004b8da184e40cce23' THEN RAISE EXCEPTION 'fonction_restaurant_preexistante_differente: restaurant_luthecia_est_commerce'; END IF; END $nouveau$;
DO $nouveau$ BEGIN IF to_regprocedure('public.restaurant_luthecia_carte(jsonb,text)') IS NOT NULL AND md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_luthecia_carte(jsonb,text)'))) IS DISTINCT FROM '4294dd17a1dffe4c190566af85b3eb3d' THEN RAISE EXCEPTION 'fonction_restaurant_preexistante_differente: restaurant_luthecia_carte'; END IF; END $nouveau$;
DO $nouveau$ BEGIN IF to_regprocedure('public.restaurant_luthecia_vente_verifier(jsonb,text,jsonb,text)') IS NOT NULL AND md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_luthecia_vente_verifier(jsonb,text,jsonb,text)'))) IS DISTINCT FROM '125f48ea10cde52aab45689599f1229e' THEN RAISE EXCEPTION 'fonction_restaurant_preexistante_differente: restaurant_luthecia_vente_verifier'; END IF; END $nouveau$;
DO $nouveau$ BEGIN IF to_regprocedure('public.restaurant_luthecia_production_verifier(jsonb,text,text)') IS NOT NULL AND md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_luthecia_production_verifier(jsonb,text,text)'))) IS DISTINCT FROM '1004a6d615641fa20442594b3053b7ea' THEN RAISE EXCEPTION 'fonction_restaurant_preexistante_differente: restaurant_luthecia_production_verifier'; END IF; END $nouveau$;
DO $nouveau$ BEGIN IF to_regprocedure('public.restaurant_luthecia_configurer(jsonb)') IS NOT NULL AND md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_luthecia_configurer(jsonb)'))) IS DISTINCT FROM 'e1b3b2419578d86e6ba640115219a1fb' THEN RAISE EXCEPTION 'fonction_restaurant_preexistante_differente: restaurant_luthecia_configurer'; END IF; END $nouveau$;
DO $nouveau$ BEGIN IF to_regprocedure('public.restaurant_luthecia_initialiser()') IS NOT NULL AND md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_luthecia_initialiser()'))) IS DISTINCT FROM 'd710c131657d8df4859c91bd92daa377' THEN RAISE EXCEPTION 'fonction_restaurant_preexistante_differente: restaurant_luthecia_initialiser'; END IF; END $nouveau$;
DO $nouveau$ BEGIN IF to_regprocedure('public.restaurant_diner_proteger()') IS NOT NULL AND md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_diner_proteger()'))) IS DISTINCT FROM '010c7ee8e8163311a565eff45e3e400d' THEN RAISE EXCEPTION 'fonction_restaurant_preexistante_differente: restaurant_diner_proteger'; END IF; END $nouveau$;
DO $nouveau$ BEGIN IF to_regprocedure('public.restaurant_luthecia_pnj_chance(text,text)') IS NOT NULL AND md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_luthecia_pnj_chance(text,text)'))) IS DISTINCT FROM '9a0bc8b28eeeba4e70602afdad6f96bb' THEN RAISE EXCEPTION 'fonction_restaurant_preexistante_differente: restaurant_luthecia_pnj_chance'; END IF; END $nouveau$;
DO $nouveau$ BEGIN IF to_regprocedure('public.restaurant_diner_creer(text,text,boolean,text)') IS NOT NULL AND md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_diner_creer(text,text,boolean,text)'))) IS DISTINCT FROM '3b35cdf583b4a85835a64a2cae3a9bf4' THEN RAISE EXCEPTION 'fonction_restaurant_preexistante_differente: restaurant_diner_creer'; END IF; END $nouveau$;
DO $nouveau$ BEGIN IF to_regprocedure('public.restaurant_diner_repondre(bigint,boolean,text)') IS NOT NULL AND md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_diner_repondre(bigint,boolean,text)'))) IS DISTINCT FROM 'b29a9f18f3e6a8c2c43c1176ee67adc3' THEN RAISE EXCEPTION 'fonction_restaurant_preexistante_differente: restaurant_diner_repondre'; END IF; END $nouveau$;
DO $nouveau$ BEGIN IF to_regprocedure('public.restaurant_diner_servir(bigint)') IS NOT NULL AND md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_diner_servir(bigint)'))) IS DISTINCT FROM '8d91a15259c3cfcd9d2e67623598a47f' THEN RAISE EXCEPTION 'fonction_restaurant_preexistante_differente: restaurant_diner_servir'; END IF; END $nouveau$;
DO $nouveau$ BEGIN IF to_regprocedure('public.restaurant_diner_suivre()') IS NOT NULL AND md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_diner_suivre()'))) IS DISTINCT FROM '6fc3ad2a14f9355edd06c28e53a24dd0' THEN RAISE EXCEPTION 'fonction_restaurant_preexistante_differente: restaurant_diner_suivre'; END IF; END $nouveau$;
DO $nouveau$ BEGIN IF to_regprocedure('public.restaurant_diner_acquitter(bigint)') IS NOT NULL AND md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_diner_acquitter(bigint)'))) IS DISTINCT FROM 'd58847cb4791b6e2047beed14edff974' THEN RAISE EXCEPTION 'fonction_restaurant_preexistante_differente: restaurant_diner_acquitter'; END IF; END $nouveau$;
DO $prevol$ BEGIN IF coalesce(md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.tournee_creer(text,text,text,text[])'))),'absent') NOT IN ('89f597e3daac93e13ca4ebed88906668','97959954b76d6c00b0e8035eedead7ea') THEN RAISE EXCEPTION 'precondition_definition_differente: tournee_creer'; END IF; END $prevol$;
DO $prevol$ BEGIN IF coalesce(md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.commerce_produire(text,text,text,text)'))),'absent') NOT IN ('e20b49be94dc6a17baa8981e0038f8d6','dcdec7f004f91a798bcccd03739b979d') THEN RAISE EXCEPTION 'precondition_definition_differente: commerce_produire'; END IF; END $prevol$;
DO $prevol$ BEGIN IF coalesce(md5((SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'))),'absent') NOT IN ('8777df12a7956a7c3ee61b5c0f3f9251','3b1a95240f0adb8234a1b6d3752444d1') THEN RAISE EXCEPTION 'precondition_definition_differente: commerce_vendre_produit_interne'; END IF; END $prevol$;
DO $prevol$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.entreprises_constantes WHERE cle='cout_main_oeuvre_pa_alimentaire' AND valeur=50) THEN RAISE EXCEPTION 'cout_main_oeuvre_a_verifier'; END IF;
 IF (SELECT count(*) FROM public.recettes_commerce WHERE id IN('menu_gastronomique_1','menu_gastronomique_2','menu_gastronomique_3') AND pa IN(1,3) AND portions=5 AND pays_autorises='["republic"]'::jsonb AND villes_autorisees='["capitale"]'::jsonb AND buildings_autorises='["hotel-republica"]'::jsonb)<>3 THEN RAISE EXCEPTION 'recettes_gastronomiques_a_verifier'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.recettes_commerce WHERE id='vin' AND pa=1 AND portions=15 AND materiaux='{"fruits_legumes":1}'::jsonb) THEN RAISE EXCEPTION 'reference_boisson_a_verifier'; END IF;
END $prevol$;

CREATE OR REPLACE FUNCTION public.restaurant_luthecia_est_commerce(d jsonb) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $fn$
 SELECT coalesce(d->>'country'='republic' AND d->>'city'='capitale' AND d->>'buildingId'='hotel-republica',false);
$fn$;
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_carte(d jsonb,acteur text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
 SELECT CASE WHEN public.restaurant_luthecia_est_commerce(d) THEN coalesce(d->'cartesParPiece'->(SELECT current_room FROM public.personnages_donnees WHERE name=acteur),'[]'::jsonb) ELSE coalesce(d->'carte','[]'::jsonb) END;
$fn$;
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_vente_verifier(d jsonb,acteur text,produits jsonb,mode_vente text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
BEGIN
 IF NOT public.restaurant_luthecia_est_commerce(d) THEN RETURN '{"ok":true}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=acteur AND country='republic' AND current_city='capitale' AND current_building='hotel-republica' AND current_room IN('bar','restaurant')) THEN RETURN '{"ok":false,"raison":"pas_sur_place"}'; END IF;
 IF d->>'versionGastronomieLuthecia' IS DISTINCT FROM '1' THEN RETURN '{"ok":false,"raison":"carte_non_installee"}'; END IF;
 -- Le service du diner passe UNIQUEMENT par sa porte atomique. Aucun assemblage libre cote client.
 IF mode_vente='service' AND current_setting('rp.diner_luthecia',true) IS DISTINCT FROM 'on' THEN RETURN '{"ok":false,"raison":"service_par_invitation_requis"}'; END IF;
 RETURN '{"ok":true}';
END $fn$;
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_production_verifier(d jsonb,acteur text,recette text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
DECLARE c numeric;
BEGIN
 IF NOT public.restaurant_luthecia_est_commerce(d) THEN RETURN '{"ok":true}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=acteur AND country='republic' AND current_city='capitale' AND current_building='hotel-republica') OR NOT(public.restaurant_luthecia_carte(d,acteur) @> jsonb_build_array(recette)) THEN RETURN '{"ok":false,"raison":"hors_carte_piece"}'; END IF;
 IF coalesce(d->>'proprietaire','PNJ')='PNJ' AND recette IN('champagne_luthecia','cocktail_luthecia') THEN
  IF d->'coutMoyenMatieres'->>'fruits_legumes' IS NULL THEN RETURN '{"ok":false,"raison":"cout_matiere_inconnu"}'; END IF;
  c:=public.commerce_cout_revient_portion(d,recette);
  IF c IS NULL OR c*2>25 THEN RETURN jsonb_build_object('ok',false,'raison','marge_pnj_insuffisante','coutUnitaire',c); END IF;
 END IF;
 RETURN '{"ok":true}';
END $fn$;
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

  v_r:=public.restaurant_luthecia_production_verifier(v_data,p_acteur,p_recette);
  IF v_r->>'ok' IS DISTINCT FROM 'true' THEN RETURN v_r; END IF;
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
  v_r:=public.restaurant_luthecia_vente_verifier(v_data,p_acteur,p_produits,p_mode);
  IF v_r->>'ok' IS DISTINCT FROM 'true' THEN RETURN v_r; END IF;
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
      v_au_catalogue := public.restaurant_luthecia_carte(v_data,p_acteur) @> jsonb_build_array(to_jsonb(v_id));
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
      v_prix := CASE WHEN public.restaurant_luthecia_est_commerce(v_data) AND v_id LIKE 'menu_gastronomique_%' THEN 125 WHEN public.restaurant_luthecia_est_commerce(v_data) AND v_id IN('champagne_luthecia','cocktail_luthecia') THEN 25 ELSE coalesce(p_prix_tournee, (v_data->'parametres'->'prixVente'->>v_id)::numeric) END;
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
DO $recettes$
DECLARE r public.recettes_commerce; n text;
BEGIN
 FOREACH n IN ARRAY ARRAY['champagne_luthecia','cocktail_luthecia'] LOOP
  IF NOT EXISTS(SELECT 1 FROM public.recettes_commerce WHERE id=n) THEN
   SELECT * INTO r FROM public.recettes_commerce WHERE id='vin';
   r.id:=n; r.label:=CASE WHEN n='champagne_luthecia' THEN 'Champagne' ELSE 'Cocktail' END;
   r.pa:=2; r.portions:=9; r.materiaux:='{"fruits_legumes":2}'; r.prix_fixe:=25;
   r.types_autorises:='["brasserie"]';r.pays_autorises:='["republic"]';r.villes_autorisees:='["capitale"]';r.buildings_autorises:='["hotel-republica"]';
   INSERT INTO public.recettes_commerce SELECT r.*;
  ELSIF NOT EXISTS(SELECT 1 FROM public.recettes_commerce WHERE id=n AND pa=2 AND portions=9 AND materiaux='{"fruits_legumes":2}' AND prix_fixe=25 AND categorie='boisson' AND types_autorises='["brasserie"]' AND pays_autorises='["republic"]' AND villes_autorisees='["capitale"]' AND buildings_autorises='["hotel-republica"]') THEN RAISE EXCEPTION 'recette_premium_existante_differente'; END IF;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM public.recettes_commerce WHERE id='amuse_bouche_luthecia') THEN
  SELECT * INTO r FROM public.recettes_commerce WHERE id='snack_buvette';
  IF NOT FOUND THEN RAISE EXCEPTION 'reference_amuse_bouche_absente'; END IF;
  r.id:='amuse_bouche_luthecia';r.label:='Amuse-bouche';r.types_autorises:='["brasserie"]';r.pays_autorises:='["republic"]';r.villes_autorisees:='["capitale"]';r.buildings_autorises:='["hotel-republica"]';
  INSERT INTO public.recettes_commerce SELECT r.*;
 ELSIF NOT EXISTS(SELECT 1 FROM public.recettes_commerce WHERE id='amuse_bouche_luthecia' AND pa=1 AND portions=15 AND materiaux='{"cereales":1}' AND pays_autorises='["republic"]' AND villes_autorisees='["capitale"]' AND buildings_autorises='["hotel-republica"]') THEN RAISE EXCEPTION 'recette_amuse_bouche_existante_differente';
 END IF;
 UPDATE public.recettes_commerce SET pa=3,prix_fixe=125 WHERE id IN('menu_gastronomique_1','menu_gastronomique_2','menu_gastronomique_3');
END $recettes$;

-- Une entreprise existante, deux offres par piece ; aucune copie de caisse ou de stock.
-- Les nouveaux stocks commencent a ZERO. Les stocks historiques et leur historique sont conserves.
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_configurer(d jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path=public,pg_temp AS $fn$
DECLARE bar jsonb;restaurant jsonb;union_carte jsonb;k text;
BEGIN
 IF NOT public.restaurant_luthecia_est_commerce(d) OR d->>'versionGastronomieLuthecia'='1' THEN RETURN d; END IF;
 IF jsonb_typeof(d->'stockProduits') IS DISTINCT FROM 'object' OR jsonb_typeof(d->'parametres'->'stockMax') IS DISTINCT FROM 'object' OR jsonb_typeof(d->'parametres'->'prixVente') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'structure_commerce_inconnue'; END IF;
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]') INTO bar FROM jsonb_array_elements_text(coalesce(d->'carte','[]')) WITH ORDINALITY a(x,ord) WHERE EXISTS(SELECT 1 FROM public.recettes_commerce WHERE id=x AND (categorie='boisson' OR id='snack_buvette'));
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]') INTO restaurant FROM jsonb_array_elements_text(coalesce(d->'carte','[]')) WITH ORDINALITY a(x,ord) WHERE EXISTS(SELECT 1 FROM public.recettes_commerce WHERE id=x AND (categorie='boisson' OR id IN('menu_gastronomique_1','menu_gastronomique_2','menu_gastronomique_3'))) AND x<>'cocktail_luthecia';
  bar:=bar||'["cocktail_luthecia","champagne_luthecia"]';restaurant:=restaurant||'["champagne_luthecia","amuse_bouche_luthecia"]';
  SELECT jsonb_agg(DISTINCT x) INTO bar FROM jsonb_array_elements(bar) a(x);
  SELECT jsonb_agg(DISTINCT x) INTO restaurant FROM jsonb_array_elements(restaurant) a(x);
  SELECT jsonb_agg(DISTINCT x) INTO union_carte FROM jsonb_array_elements(bar||restaurant) a(x);
  d:=d||jsonb_build_object('versionGastronomieLuthecia',1,'cartesParPiece',jsonb_build_object('bar',bar,'restaurant',restaurant),'carte',union_carte);
  FOREACH k IN ARRAY ARRAY['champagne_luthecia','cocktail_luthecia','amuse_bouche_luthecia'] LOOP
   IF NOT(coalesce(d->'stockProduits','{}') ? k) THEN d:=jsonb_set(d,ARRAY['stockProduits',k],'0',true); END IF;
   IF NOT(coalesce(d->'parametres'->'stockMax','{}') ? k) THEN d:=jsonb_set(d,ARRAY['parametres','stockMax',k],'20',true); END IF;
  END LOOP;
  FOREACH k IN ARRAY ARRAY['champagne_luthecia','cocktail_luthecia'] LOOP d:=jsonb_set(d,ARRAY['parametres','prixVente',k],'25',true); END LOOP;
  FOREACH k IN ARRAY ARRAY['menu_gastronomique_1','menu_gastronomique_2','menu_gastronomique_3'] LOOP d:=jsonb_set(d,ARRAY['parametres','prixVente',k],'125',true); END LOOP;
  d:=jsonb_set(d,ARRAY['parametres','prixVente','amuse_bouche_luthecia'],to_jsonb(coalesce((d->'parametres'->'prixVente'->>'snack_buvette')::numeric,round(public.commerce_cout_revient_portion(d,'amuse_bouche_luthecia')*2))),true);
 RETURN d;
END $fn$;
REVOKE ALL ON FUNCTION public.restaurant_luthecia_configurer(jsonb) FROM PUBLIC,anon,authenticated,service_role;
DO $cartes$
DECLARE r record;
BEGIN
 IF (SELECT count(*) FROM public.entreprises WHERE public.restaurant_luthecia_est_commerce(data))>1 THEN RAISE EXCEPTION 'entreprise_luthecia_non_unifiee'; END IF;
 FOR r IN SELECT id,data FROM public.entreprises WHERE public.restaurant_luthecia_est_commerce(data) AND data->>'versionGastronomieLuthecia' IS DISTINCT FROM '1' FOR UPDATE LOOP
  UPDATE public.entreprises SET data=public.restaurant_luthecia_configurer(r.data),updated_at=now() WHERE id=r.id;
 END LOOP;
END $cartes$;
CREATE UNIQUE INDEX IF NOT EXISTS entreprise_luthecia_unifiee ON public.entreprises((data->>'country'),(data->>'city'),(data->>'buildingId')) WHERE data->>'country'='republic' AND data->>'city'='capitale' AND data->>'buildingId'='hotel-republica';
-- Creation future via entreprise_assurer_existence : meme configuration sans rattrapage repete.
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_initialiser() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
BEGIN NEW.data:=public.restaurant_luthecia_configurer(NEW.data); RETURN NEW; END $fn$;
REVOKE ALL ON FUNCTION public.restaurant_luthecia_initialiser() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS entreprise_restaurant_luthecia_initialiser ON public.entreprises;
CREATE TRIGGER entreprise_restaurant_luthecia_initialiser BEFORE INSERT ON public.entreprises FOR EACH ROW EXECUTE FUNCTION public.restaurant_luthecia_initialiser();
REVOKE ALL ON FUNCTION public.restaurant_luthecia_carte(jsonb,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.restaurant_luthecia_vente_verifier(jsonb,text,jsonb,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.restaurant_luthecia_production_verifier(jsonb,text,text) FROM PUBLIC,anon,authenticated,service_role;

ALTER TABLE public.invitations_diner ADD COLUMN IF NOT EXISTS contrat_restaurant text;
ALTER TABLE public.invitations_diner ADD COLUMN IF NOT EXISTS requete_restaurant text;
ALTER TABLE public.invitations_diner ADD COLUMN IF NOT EXISTS invite_pnj boolean NOT NULL DEFAULT false;
ALTER TABLE public.invitations_diner ADD COLUMN IF NOT EXISTS resultat_service jsonb;
ALTER TABLE public.invitations_diner ADD COLUMN IF NOT EXISTS lecture_inviteur boolean NOT NULL DEFAULT false;
ALTER TABLE public.invitations_diner ADD COLUMN IF NOT EXISTS lecture_invite boolean NOT NULL DEFAULT false;
CREATE UNIQUE INDEX IF NOT EXISTS invitations_requete_restaurant ON public.invitations_diner(requete_restaurant) WHERE requete_restaurant IS NOT NULL;
CREATE OR REPLACE FUNCTION public.restaurant_diner_proteger() RETURNS trigger
LANGUAGE plpgsql SET search_path=public,pg_temp AS $fn$
BEGIN
 IF current_user NOT IN('postgres','supabase_admin') THEN
  IF TG_OP<>'DELETE' AND NEW.contrat_restaurant IS NOT NULL THEN RAISE EXCEPTION 'diner_par_rpc_requis' USING ERRCODE='42501'; END IF;
  IF TG_OP<>'INSERT' AND OLD.contrat_restaurant IS NOT NULL THEN RAISE EXCEPTION 'diner_par_rpc_requis' USING ERRCODE='42501'; END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION public.restaurant_diner_proteger() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS invitations_restaurant_protege ON public.invitations_diner;
CREATE TRIGGER invitations_restaurant_protege BEFORE INSERT OR UPDATE OR DELETE ON public.invitations_diner FOR EACH ROW EXECUTE FUNCTION public.restaurant_diner_proteger();

CREATE OR REPLACE FUNCTION public.restaurant_luthecia_pnj_chance(acteur text,invite text) RETURNS integer
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
DECLARE p public.personnages_donnees; chance integer;
BEGIN
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur;
 IF NOT FOUND THEN RETURN NULL; END IF;
 chance:=CASE invite WHEN 'Gaston Sauceblanche' THEN 60 WHEN 'Régis Gondasse' THEN 60 WHEN 'Yvette Gratinée' THEN 60 WHEN 'Jean Dupont' THEN 60 WHEN 'Marie Leblanc' THEN 20 ELSE NULL END;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.employes)='array' THEN p.employes ELSE '[]' END) e WHERE e->>'nom'=invite AND e->'inGroupe'='true'::jsonb)
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.escort_active)='array' THEN p.escort_active ELSE '[]' END) e WHERE e->>'nom'=invite)
  OR EXISTS(SELECT 1 FROM public.pnj_membres WHERE nom=invite AND leader_pj IN(acteur,'pj:'||acteur) AND statut='actif') THEN chance:=95; END IF;
 -- Reutiliser la projection serveur des agents, jamais les vrais noms ni un cache de presence.
 IF acteur=public.mon_personnage() AND EXISTS(
  SELECT 1 FROM jsonb_array_elements(coalesce(public.agents_couverture_de_mon_groupe()->'agents','[]'::jsonb)) a WHERE a->>'nom'=invite
 ) THEN chance:=95; END IF;
 RETURN chance;
END $fn$;
REVOKE ALL ON FUNCTION public.restaurant_luthecia_pnj_chance(text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.restaurant_diner_creer(p_requete text,p_invite text,p_pnj boolean,p_message text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
DECLARE moi text:=public.mon_personnage(); i public.invitations_diner; p public.personnages_donnees; chance integer; etat text; accepte boolean;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}'; END IF;
 IF p_requete IS NULL OR p_requete !~ '^diner-[A-Za-z0-9-]{10,80}$' OR coalesce(p_invite,'')='' OR p_invite=moi OR p_pnj IS NULL THEN RETURN '{"ok":false,"raison":"parametres_invalides"}'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('restaurant:'||p_requete,0));
 SELECT * INTO i FROM public.invitations_diner WHERE requete_restaurant=p_requete FOR UPDATE;
 IF FOUND THEN
  IF i.inviteur=moi AND i.invite=p_invite AND i.invite_pnj=p_pnj AND coalesce(i.message,'')=left(coalesce(p_message,''),200) THEN RETURN jsonb_build_object('ok',true,'id',i.id,'statut',i.statut,'rejeu',true); END IF;
  RETURN '{"ok":false,"raison":"requete_incompatible"}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=ANY(ARRAY[moi,CASE WHEN NOT p_pnj THEN p_invite ELSE moi END]) ORDER BY name FOR UPDATE;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 IF NOT FOUND OR p.country IS DISTINCT FROM 'republic' OR p.current_city IS DISTINCT FROM 'capitale' OR p.current_building IS DISTINCT FROM 'hotel-republica' OR p.current_room IS DISTINCT FROM 'restaurant' THEN RETURN '{"ok":false,"raison":"pas_sur_place"}'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.entreprises WHERE public.restaurant_luthecia_est_commerce(data) AND data->>'versionGastronomieLuthecia'='1') THEN RETURN '{"ok":false,"raison":"carte_non_installee"}'; END IF;
 etat:='attente';
 IF p_pnj THEN
  -- PNJ fixes de la salle, identites/relations de data.js, sans aucun personnage cree.
  chance:=public.restaurant_luthecia_pnj_chance(moi,p_invite);
  IF chance IS NULL THEN RETURN '{"ok":false,"raison":"pnj_non_present"}'; END IF;
  accepte:=floor(random()*100)+1<=chance;etat:=CASE WHEN accepte THEN 'acceptee' ELSE 'refusee' END;
 ELSE
  IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=p_invite AND country='republic' AND current_city='capitale' AND current_building='hotel-republica' AND current_room='restaurant') THEN RETURN '{"ok":false,"raison":"invite_absent"}'; END IF;
 END IF;
 INSERT INTO public.invitations_diner(inviteur,invite,country,city,building_id,room_id,cout,type,message,statut,contrat_restaurant,requete_restaurant,invite_pnj,resultat_service)
 VALUES(moi,p_invite,'republic','capitale','hotel-republica','restaurant',300,'diner_affaires',left(coalesce(p_message,''),200),etat,'luthecia_v1',p_requete,p_pnj,CASE WHEN etat='refusee' THEN '{"ok":false,"raison":"invitation_refusee"}'::jsonb ELSE NULL END) RETURNING * INTO i;
 RETURN jsonb_build_object('ok',true,'id',i.id,'statut',i.statut);
END $fn$;

CREATE OR REPLACE FUNCTION public.restaurant_diner_repondre(p_invitation bigint,p_accepte boolean,p_reponse text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
DECLARE moi text:=public.mon_personnage(); i public.invitations_diner; etat text:=CASE WHEN p_accepte THEN 'acceptee' ELSE 'refusee' END;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}'; END IF;
 SELECT * INTO i FROM public.invitations_diner WHERE id=p_invitation FOR UPDATE;
 IF NOT FOUND OR i.contrat_restaurant IS DISTINCT FROM 'luthecia_v1' OR i.invite IS DISTINCT FROM moi OR i.invite_pnj OR p_accepte IS NULL THEN RETURN '{"ok":false,"raison":"pas_mon_invitation"}'; END IF;
 IF i.statut=etat THEN RETURN '{"ok":true,"rejeu":true}'; END IF;
 IF i.statut<>'attente' OR i.resultat_service IS NOT NULL THEN RETURN '{"ok":false,"raison":"invitation_close"}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=moi AND country='republic' AND current_city='capitale' AND current_building='hotel-republica' AND current_room='restaurant') THEN RETURN '{"ok":false,"raison":"pas_sur_place"}'; END IF;
 UPDATE public.invitations_diner SET statut=etat,reponse=left(coalesce(p_reponse,''),200),resultat_service=CASE WHEN NOT p_accepte THEN '{"ok":false,"raison":"invitation_refusee"}'::jsonb ELSE NULL END WHERE id=i.id;
 RETURN '{"ok":true}';
END $fn$;

CREATE OR REPLACE FUNCTION public.restaurant_diner_servir(p_invitation bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
DECLARE moi text:=public.mon_personnage(); i public.invitations_diner; d jsonb; entreprise text; restant integer:=2; disponible integer; pris integer; menu text; articles jsonb:='[]'; r jsonb; detail text; bonus integer; precedent text;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}'; END IF;
 SELECT * INTO i FROM public.invitations_diner WHERE id=p_invitation FOR UPDATE;
 IF NOT FOUND OR i.inviteur IS DISTINCT FROM moi OR i.contrat_restaurant IS DISTINCT FROM 'luthecia_v1' THEN RETURN '{"ok":false,"raison":"pas_mon_invitation"}'; END IF;
 IF i.resultat_service IS NOT NULL THEN RETURN i.resultat_service||'{"rejeu":true}'; END IF;
 IF i.statut<>'acceptee' THEN RETURN '{"ok":false,"raison":"acceptation_requise"}'; END IF;
 -- Une seule entreprise canonique. Pas de recherche d'un autre restaurant pour satisfaire le stock.
 SELECT id,data INTO entreprise,d FROM public.entreprises WHERE public.restaurant_luthecia_est_commerce(data) AND data->>'versionGastronomieLuthecia'='1' ORDER BY id LIMIT 1 FOR UPDATE;
 IF d IS NULL THEN RETURN '{"ok":false,"raison":"commerce_introuvable"}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=ANY(ARRAY[moi,CASE WHEN NOT i.invite_pnj THEN i.invite ELSE moi END]) ORDER BY name FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=moi AND country='republic' AND current_city='capitale' AND current_building='hotel-republica' AND current_room='restaurant') OR
   (i.invite_pnj AND public.restaurant_luthecia_pnj_chance(moi,i.invite) IS NULL) OR
   (NOT i.invite_pnj AND NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=i.invite AND country='republic' AND current_city='capitale' AND current_building='hotel-republica' AND current_room='restaurant')) THEN r:='{"ok":false,"raison":"action_obsolete"}';
 ELSE
  FOREACH menu IN ARRAY ARRAY['menu_gastronomique_1','menu_gastronomique_2','menu_gastronomique_3'] LOOP
   disponible:=greatest(0,coalesce((d->'stockProduits'->>menu)::integer,0));pris:=least(restant,disponible);
   IF pris>0 THEN articles:=articles||jsonb_build_array(jsonb_build_object('produit',menu,'qte',pris));restant:=restant-pris; END IF;
   EXIT WHEN restant=0;
  END LOOP;
  IF restant>0 OR coalesce((d->'stockProduits'->>'champagne_luthecia')::integer,0)<2 THEN r:='{"ok":false,"raison":"stock_insuffisant"}';
  ELSE
   articles:=articles||'[{"produit":"champagne_luthecia","qte":2}]';
   -- La meme vente qu'un service historique, mais le PA/paiement, les stocks et les effets
   -- sont un seul acte et un seul recu. Aucun chiffre de prix/quantite fourni par le navigateur.
   precedent:=current_setting('rp.diner_luthecia',true);
   BEGIN
    PERFORM set_config('rp.diner_luthecia','on',true);
    r:=public.commerce_vendre_produit_interne(moi,entreprise,articles,'service','diner_affaires',2,300,NULL,NULL);
    IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'diner_vente_refusee' USING DETAIL=r::text; END IF;
    SELECT montant INTO bonus FROM public.pa_bonus_differes WHERE source='diner_affaires';
    IF bonus IS DISTINCT FROM 3 THEN RAISE EXCEPTION 'bonus_diner_incompatible'; END IF;
    UPDATE public.personnages_donnees SET hp=least(100,coalesce(hp,100)+10),moral=least(100,coalesce(moral,75)+2),
      resources=jsonb_set(coalesce(resources,'{}'),'{inf}',to_jsonb(least(100,coalesce((resources->>'inf')::numeric,0)+5)),true),
      bonus_pa_differe=least(30,coalesce(bonus_pa_differe,0)+bonus),updated_at=now()
    WHERE name=moi OR (NOT i.invite_pnj AND name=i.invite);
    r:=jsonb_build_object('ok',true,'total',300,'repas',2,'champagnes',2,'pa',2,'articles',articles);
    PERFORM set_config('rp.diner_luthecia',coalesce(precedent,''),true);
   EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'diner_vente_refusee' THEN RAISE; END IF;
    GET STACKED DIAGNOSTICS detail=PG_EXCEPTION_DETAIL;r:=detail::jsonb;
   END;
  END IF;
 END IF;
 UPDATE public.invitations_diner SET resultat_service=r WHERE id=i.id;
 RETURN r;
END $fn$;
CREATE OR REPLACE FUNCTION public.restaurant_diner_suivre() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
 SELECT jsonb_build_object('ok',public.mon_personnage() IS NOT NULL,'invitations',coalesce(jsonb_agg(to_jsonb(i) ORDER BY i.id),'[]'))
 FROM public.invitations_diner i WHERE i.contrat_restaurant='luthecia_v1' AND
 ((i.inviteur=public.mon_personnage() AND NOT i.lecture_inviteur) OR (NOT i.invite_pnj AND i.invite=public.mon_personnage() AND i.resultat_service IS NOT NULL AND NOT i.lecture_invite));
$fn$;
CREATE OR REPLACE FUNCTION public.restaurant_diner_acquitter(p_invitation bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
DECLARE moi text:=public.mon_personnage();i public.invitations_diner;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}'; END IF;
 SELECT * INTO i FROM public.invitations_diner WHERE id=p_invitation FOR UPDATE;
 IF NOT FOUND OR i.contrat_restaurant IS DISTINCT FROM 'luthecia_v1' OR i.resultat_service IS NULL THEN RETURN '{"ok":false,"raison":"service_non_confirme"}'; END IF;
 IF i.inviteur=moi THEN
  IF i.lecture_inviteur THEN RETURN '{"ok":true,"rejeu":true}'; END IF;
  UPDATE public.invitations_diner SET lecture_inviteur=true WHERE id=i.id;
 ELSIF NOT i.invite_pnj AND i.invite=moi THEN
  IF i.lecture_invite THEN RETURN '{"ok":true,"rejeu":true}'; END IF;
  UPDATE public.invitations_diner SET lecture_invite=true WHERE id=i.id;
 ELSE RETURN '{"ok":false,"raison":"pas_mon_invitation"}'; END IF;
 RETURN '{"ok":true}';
END $fn$;
REVOKE ALL ON FUNCTION public.restaurant_diner_creer(text,text,boolean,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.restaurant_diner_repondre(bigint,boolean,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.restaurant_diner_servir(bigint) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.restaurant_diner_suivre() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.restaurant_diner_acquitter(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.restaurant_diner_creer(text,text,boolean,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_diner_repondre(bigint,boolean,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_diner_servir(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_diner_suivre() TO authenticated;
GRANT EXECUTE ON FUNCTION public.restaurant_diner_acquitter(bigint) TO authenticated;
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
 IF v_data IS NULL OR NOT(public.restaurant_luthecia_carte(v_data,v_moi) @> jsonb_build_array(p_recette)) OR NOT EXISTS(SELECT 1 FROM public.recettes_commerce WHERE id=p_recette AND categorie='boisson') THEN
  RETURN jsonb_build_object('ok',false,'raison','boisson_non_proposee'); END IF;
 -- Ordre de verrouillage commun a tous les participants, y compris deux organisateurs concurrents.
 PERFORM 1 FROM public.personnages_donnees WHERE name=ANY(v_invites||ARRAY[v_moi]) ORDER BY name FOR UPDATE;
 SELECT * INTO v_p FROM public.personnages_donnees WHERE name=v_moi;
 IF NOT FOUND OR v_p.country IS DISTINCT FROM v_data->>'country' OR v_p.current_city IS DISTINCT FROM v_data->>'city' OR v_p.current_building IS DISTINCT FROM v_data->>'buildingId' OR v_p.current_room IS NULL OR
   (v_data->>'roomId' IS NOT NULL AND v_p.current_room IS DISTINCT FROM v_data->>'roomId') THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 IF public.restaurant_luthecia_est_commerce(v_data) AND v_p.current_room<>'bar' THEN RETURN '{"ok":false,"raison":"ordre_non_disponible"}'; END IF;
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
COMMIT;
