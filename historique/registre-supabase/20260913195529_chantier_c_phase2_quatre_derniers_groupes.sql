-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913195529
-- Nom original      : chantier_c_phase2_quatre_derniers_groupes
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 19:55:29 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8cb2cc74b2563f08dc44241d92b89049
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
-- ============================================================================
-- CHANTIER C / PHASE 2 — LES QUATRE DERNIERS GROUPES ECONOMIQUES
-- 13 septembre 2026. Armoire, vente medicale, prix des directeurs, caisses.
-- ============================================================================

-- Miroirs de configuration, transcrits a l'identique depuis le code du jeu.
CREATE TABLE IF NOT EXISTS public.directeurs_usine (
  poste_id text PRIMARY KEY, ville text NOT NULL, building_id text NOT NULL, produits jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS public.entrepots_par_ville (
  ville text PRIMARY KEY, building_id text NOT NULL
);
CREATE TABLE IF NOT EXISTS public.structures_medicales (
  building_id text PRIMARY KEY, ressources jsonb NOT NULL, financement text NOT NULL, categorie_caisse text
);
CREATE TABLE IF NOT EXISTS public.produits_manufactures (
  produit text PRIMARY KEY, ville text NOT NULL, building_id text NOT NULL,
  recette jsonb NOT NULL, pa integer NOT NULL, prix_vente numeric NOT NULL, encombrement integer NOT NULL
);
ALTER TABLE public.directeurs_usine      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entrepots_par_ville   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.structures_medicales  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produits_manufactures ENABLE ROW LEVEL SECURITY;
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['directeurs_usine','entrepots_par_ville','structures_medicales','produits_manufactures'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I_lecture ON public.%I', t, t);
    EXECUTE format('CREATE POLICY %I_lecture ON public.%I FOR SELECT TO anon, authenticated USING (true)', t, t);
  END LOOP;
END $$;

TRUNCATE public.directeurs_usine;
INSERT INTO public.directeurs_usine VALUES
('directeur_pharma','capitale','usine-pharmaceutique-luthecia','["medicaments","desinfectant"]'::jsonb),
('directeur_tabac_alcools','ville_a','pole-tabac-alcools-psm','["alcool","tabac"]'::jsonb),
('directeur_raffinerie','ville_b','raffinerie-montrouge','["carburant"]'::jsonb);
TRUNCATE public.entrepots_par_ville;
INSERT INTO public.entrepots_par_ville VALUES
('capitale','entrepot-logistique-luthecia'),('ville_a','entrepot-logistique-psm'),
('ville_b','entrepot-logistique-montrouge');
TRUNCATE public.structures_medicales;
INSERT INTO public.structures_medicales VALUES
('dispensaire-public','["desinfectant"]'::jsonb,'institution','dispensaire'),
('dispensaire-public-v','["desinfectant"]'::jsonb,'institution','dispensaire'),
('clinique-privee','["desinfectant","medicaments"]'::jsonb,'propre',NULL);
TRUNCATE public.produits_manufactures;
INSERT INTO public.produits_manufactures VALUES
('armoire_souvenirs','ville_a','zone-production','{"bois":2,"minerai":2}'::jsonb,3,390,3);

-- --- GROUPE 1 : ARMOIRE A SOUVENIRS -----------------------------------------
CREATE OR REPLACE FUNCTION public.fabriquer_produit_manufacture(
  p_acteur text, p_pays text, p_produit text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_ville text; v_bat text; v_recette jsonb; v_id text;
  v_etat jsonb; v_usine jsonb; v_sm jsonb; v_sp jsonb;
  v_cle text; v_q numeric; v_manque text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT ville, building_id, recette INTO v_ville, v_bat, v_recette
  FROM public.produits_manufactures WHERE produit = p_produit;
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'produit_inconnu'); END IF;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'atelier_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
  v_sp := coalesce(v_usine->'stockProduits', '{}'::jsonb);

  -- Verification COMPLETE avant toute mutation : refus sans mutation partielle.
  FOR v_cle, v_q IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(v_recette) LOOP
    IF coalesce((v_sm->>v_cle)::numeric, 0) < v_q THEN v_manque := v_cle; EXIT; END IF;
  END LOOP;
  IF v_manque IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'matiere', v_manque);
  END IF;

  FOR v_cle, v_q IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(v_recette) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[v_cle], to_jsonb(coalesce((v_sm->>v_cle)::numeric,0) - v_q));
  END LOOP;
  v_sp := jsonb_set(v_sp, ARRAY[p_produit], to_jsonb(coalesce((v_sp->>p_produit)::numeric,0) + 1));

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('stockMatieres', v_sm, 'stockProduits', v_sp)))::text),
         updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'stock_produit', coalesce((v_sp->>p_produit)::numeric,0));
END; $$;
REVOKE ALL ON FUNCTION public.fabriquer_produit_manufacture(text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fabriquer_produit_manufacture(text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.acheter_produit_manufacture(
  p_acteur text, p_pays text, p_produit text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_ville text; v_bat text; v_prix numeric; v_enc int; v_id text;
  v_etat jsonb; v_usine jsonb; v_sp jsonb; v_stock numeric;
  v_inv jsonb; v_place int; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0; v_pl numeric; v_pn numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT ville, building_id, prix_vente, encombrement INTO v_ville, v_bat, v_prix, v_enc
  FROM public.produits_manufactures WHERE produit = p_produit;
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'produit_inconnu'); END IF;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'atelier_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_sp := coalesce(v_usine->'stockProduits', '{}'::jsonb);
  v_stock := coalesce((v_sp->>p_produit)::numeric, 0);
  IF v_stock <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'rupture_stock'); END IF;

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(liquide,0), coalesce(arg,0)
    INTO v_inv, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_place := public.inventaire_place_restante(v_inv);
  -- Un objet non empilable a encombrement > 1 est refuse EN BLOC, jamais partiellement.
  IF v_place < v_enc THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_insuffisant', 'encombrement', v_enc);
  END IF;

  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);
  IF v_liquide + v_solde < v_prix THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_prix,
                              'disponible', v_liquide + v_solde);
  END IF;
  v_pl := least(v_liquide, v_prix); v_pn := v_prix - v_pl;

  v_sp := jsonb_set(v_sp, ARRAY[p_produit], to_jsonb(v_stock - 1));
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('stockProduits', v_sp,
             'caisse', coalesce((v_usine->>'caisse')::numeric,0) + v_prix)))::text), updated_at = now()
   WHERE id = v_id;

  v_inv := v_inv || jsonb_build_array(jsonb_build_object(
    'type', p_produit, 'name', p_produit, 'encombrement', v_enc,
    'desc', 'Acheté à l''atelier.'));
  UPDATE public.personnages_donnees
     SET inventory = v_inv, liquide = v_liquide - v_pl, arg = v_arg - v_prix
   WHERE name = p_acteur;
  IF v_pn > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pn, updated_at = now() WHERE id = v_compte_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'prix', v_prix, 'inventory', v_inv,
    'liquide', v_liquide - v_pl, 'arg', v_arg - v_prix, 'solde_national', v_solde - v_pn);
END; $$;
REVOKE ALL ON FUNCTION public.acheter_produit_manufacture(text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.acheter_produit_manufacture(text,text,text) TO authenticated;

-- --- GROUPE 2 : VENTE DE RESSOURCE MEDICALE ---------------------------------
CREATE OR REPLACE FUNCTION public.vendre_ressource_medicale(
  p_acteur text, p_pays text, p_ville text, p_batiment text, p_ressource text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_ressources jsonb; v_financement text;
  v_etat jsonb; v_sante jsonb; v_sm jsonb; v_cmm jsonb;
  v_plafond numeric; v_stock numeric; v_place numeric; v_prix numeric; v_total numeric;
  v_caisse numeric; v_inv jsonb; v_detenu numeric; v_arg numeric; v_liquide numeric;
  v_cout_moyen numeric; v_caisse_id text; v_solde_inst numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_qte IS NULL OR p_qte <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  SELECT ressources, financement INTO v_ressources, v_financement
  FROM public.structures_medicales WHERE building_id = p_batiment;
  IF v_ressources IS NULL OR NOT (v_ressources ? p_ressource) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_non_acceptee');
  END IF;

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(arg,0), coalesce(liquide,0)
    INTO v_inv, v_arg, v_liquide
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_detenu := public.inventaire_quantite(v_inv, p_ressource);
  IF v_detenu < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu);
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'structure_introuvable'); END IF;
  v_sante := coalesce(v_etat->'sante', '{}'::jsonb);
  v_sm := coalesce(v_sante->'stockMatieres', '{}'::jsonb);
  v_cmm := coalesce(v_sante->'coutMoyenMatieres', '{}'::jsonb);

  SELECT plafond, prix_achat_fournisseur INTO v_plafond, v_prix
  FROM public.ressources_economie WHERE cle = p_ressource;
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
  v_stock := coalesce((v_sm->>p_ressource)::numeric, 0);
  v_place := greatest(0, coalesce(v_plafond,0) - v_stock);
  IF v_place < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein', 'placeRestante', v_place);
  END IF;
  v_total := v_prix * p_qte;

  -- Deux financements, deux caisses -- exactement comme le client le faisait.
  IF v_financement = 'propre' THEN
    v_caisse := coalesce((v_sante->>'caisse')::numeric, 0);
    IF v_caisse < v_total THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
    END IF;
    v_sante := v_sante || jsonb_build_object('caisse', v_caisse - v_total);
  ELSE
    v_caisse_id := p_pays || '_' || p_batiment;
    SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde_inst
    FROM public.caisses_batiments WHERE id = v_caisse_id FOR UPDATE;
    IF v_solde_inst IS NULL OR v_solde_inst < v_total THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                                'caisse', coalesce(v_solde_inst, 0));
    END IF;
    UPDATE public.caisses_batiments
       SET data = jsonb_set(coalesce(data,'{}'::jsonb), '{solde}', to_jsonb(v_solde_inst - v_total)),
           updated_at = now()
     WHERE id = v_caisse_id;
  END IF;

  v_cout_moyen := CASE WHEN v_stock + p_qte = 0 THEN 0
    ELSE round(((coalesce((v_cmm->>p_ressource)::numeric,0) * v_stock) + (v_prix * p_qte))
               / (v_stock + p_qte), 4) END;
  v_sante := v_sante || jsonb_build_object(
    'stockMatieres', jsonb_set(v_sm, ARRAY[p_ressource], to_jsonb(v_stock + p_qte)),
    'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[p_ressource], to_jsonb(v_cout_moyen)));
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('sante', v_sante))::text), updated_at = now()
   WHERE id = v_id;

  UPDATE public.personnages_donnees
     SET inventory = public.inventaire_retirer(v_inv, p_ressource, p_qte),
         arg = v_arg + v_total, liquide = v_liquide + v_total
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'prixUnitaire', v_prix, 'qte', p_qte,
    'arg', v_arg + v_total, 'liquide', v_liquide + v_total,
    'inventory', public.inventaire_retirer(v_inv, p_ressource, p_qte));
END; $$;
REVOKE ALL ON FUNCTION public.vendre_ressource_medicale(text,text,text,text,text,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vendre_ressource_medicale(text,text,text,text,text,integer) TO authenticated;