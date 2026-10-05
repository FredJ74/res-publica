-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913185129
-- Nom original      : chantier_c_phase2_criee_taxe_soins
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 18:51:29 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3d81f125e8953bb1f393c36615876318
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
-- CHANTIER C / PHASE 2 — CRIEE DU PORT, TAXE DE TRANSACTION, SOINS
-- 13 septembre 2026.
-- ============================================================================

-- --- F3 : CRIEE DU PORT -----------------------------------------------------
-- Le navigateur decrementait lui-meme port.criee.stock et creditait la caisse.
-- Prix : getPrixRessourceEntrepot = prix de base, sans variation de remplissage.
CREATE OR REPLACE FUNCTION public.acheter_a_la_criee(
  p_acteur text, p_pays text, p_ville text, p_batiment text, p_achats jsonb)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_etat jsonb; v_port jsonb; v_criee jsonb; v_stock jsonb;
  v_cle text; v_qte int; v_dispo numeric; v_prix numeric;
  v_total numeric := 0; v_lignes jsonb := '[]'::jsonb;
  v_inv jsonb; v_place int; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0; v_pris_liquide numeric; v_pris_national numeric;
  v_paye numeric := 0; v_idx int; v_ligne jsonb; v_ajoute int; v_caisse_id text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'port_introuvable'); END IF;
  v_port := coalesce(v_etat->'port', '{}'::jsonb);
  v_criee := coalesce(v_port->'criee', '{}'::jsonb);
  v_stock := coalesce(v_criee->'stock', '{}'::jsonb);

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(liquide,0), coalesce(arg,0)
    INTO v_inv, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);
  v_place := public.inventaire_place_restante(v_inv);

  FOR v_cle, v_qte IN SELECT key, (value #>> '{}')::int FROM jsonb_each(p_achats) LOOP
    IF v_qte IS NULL OR v_qte <= 0 THEN CONTINUE; END IF;
    SELECT prix_base INTO v_prix FROM public.ressources_economie WHERE cle = v_cle;
    IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle); END IF;
    v_dispo := coalesce((v_stock->>v_cle)::numeric, 0);
    IF v_qte > v_dispo THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'cle', v_cle, 'disponible', v_dispo);
    END IF;
    v_total := v_total + v_qte * v_prix;
    v_lignes := v_lignes || jsonb_build_object('cle', v_cle, 'qte', v_qte, 'prix', v_prix);
  END LOOP;
  IF jsonb_array_length(v_lignes) = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_acheter'); END IF;
  IF v_liquide + v_solde < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total,
                              'disponible', v_liquide + v_solde);
  END IF;

  FOR v_idx IN 0 .. jsonb_array_length(v_lignes) - 1 LOOP
    v_ligne := v_lignes -> v_idx; v_cle := v_ligne->>'cle';
    v_ajoute := least((v_ligne->>'qte')::int, v_place);
    IF v_ajoute <= 0 THEN CONTINUE; END IF;
    v_place := v_place - v_ajoute;
    v_paye := v_paye + v_ajoute * (v_ligne->>'prix')::numeric;
    v_inv := public.inventaire_ajouter(v_inv, v_cle, v_ajoute,
               'Marchandise achetée à la Criée du Port de Port-Sainte-Marie.');
    v_stock := jsonb_set(v_stock, ARRAY[v_cle], to_jsonb(coalesce((v_stock->>v_cle)::numeric,0) - v_ajoute));
  END LOOP;
  IF v_paye <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;

  v_pris_liquide := least(v_liquide, v_paye);
  v_pris_national := v_paye - v_pris_liquide;
  UPDATE public.personnages_donnees
     SET inventory = v_inv, liquide = v_liquide - v_pris_liquide, arg = v_arg - v_paye
   WHERE name = p_acteur;
  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national, updated_at = now() WHERE id = v_compte_id;
  END IF;

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('port',
           v_port || jsonb_build_object('criee', v_criee || jsonb_build_object('stock', v_stock))))::text),
         updated_at = now()
   WHERE id = v_id;

  -- Le produit va a la caisse du port, comme avant (crediterCaisseBatiment).
  v_caisse_id := p_pays || '_' || p_batiment;
  UPDATE public.caisses_batiments
     SET data = jsonb_set(coalesce(data,'{}'::jsonb), '{solde}',
                to_jsonb(coalesce((data->>'solde')::numeric,0) + v_paye)), updated_at = now()
   WHERE id = v_caisse_id;
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data) VALUES (v_caisse_id, jsonb_build_object('solde', v_paye))
    ON CONFLICT (id) DO UPDATE SET data = jsonb_set(coalesce(public.caisses_batiments.data,'{}'::jsonb),
      '{solde}', to_jsonb(coalesce((public.caisses_batiments.data->>'solde')::numeric,0) + v_paye));
  END IF;

  RETURN jsonb_build_object('ok', true, 'paye', v_paye, 'lignes', v_lignes, 'inventory', v_inv,
    'liquide', v_liquide - v_pris_liquide, 'arg', v_arg - v_paye, 'solde_national', v_solde - v_pris_national);
END; $$;
REVOKE ALL ON FUNCTION public.acheter_a_la_criee(text,text,text,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.acheter_a_la_criee(text,text,text,text,jsonb) TO authenticated;

-- --- TAXE DE TRANSACTION ----------------------------------------------------
-- Transcription exacte de appliquerTaxeTransaction : taux local lu sur le budget
-- municipal, taux national sur le budget national, arrondi a l'unite, et les deux
-- taxes reellement creditees. Defaut 2 % (TAUX_TAXE_DEFAUT), comme cote client.
CREATE OR REPLACE FUNCTION public.appliquer_taxe_transaction(
  p_pays text, p_ville text, p_montant_brut numeric)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_cle_muni text := p_pays || '_' || p_ville;
  v_muni jsonb; v_nat jsonb; v_tl numeric; v_tn numeric;
  v_taxe_l numeric; v_taxe_n numeric;
BEGIN
  SELECT data INTO v_muni FROM public.budgets_municipaux WHERE id = v_cle_muni FOR UPDATE;
  SELECT data INTO v_nat FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  v_tl := coalesce((v_muni->>'tauxLocal')::numeric, 2);
  v_tn := coalesce((v_nat->>'tauxNational')::numeric, 2);
  v_taxe_l := round(p_montant_brut * v_tl / 100);
  v_taxe_n := round(p_montant_brut * v_tn / 100);

  IF v_muni IS NOT NULL THEN
    UPDATE public.budgets_municipaux
       SET data = jsonb_set(v_muni, '{caisse}', to_jsonb(coalesce((v_muni->>'caisse')::numeric,0) + v_taxe_l)),
           updated_at = now()
     WHERE id = v_cle_muni;
  END IF;
  IF v_nat IS NOT NULL THEN
    UPDATE public.budgets_nationaux
       SET data = jsonb_set(v_nat, '{reserveJour}', to_jsonb(coalesce((v_nat->>'reserveJour')::numeric,0) + v_taxe_n)),
           updated_at = now()
     WHERE id = p_pays;
  END IF;

  RETURN jsonb_build_object('net', p_montant_brut - v_taxe_l - v_taxe_n,
    'taxeLocale', v_taxe_l, 'taxeNationale', v_taxe_n, 'tauxLocal', v_tl, 'tauxNational', v_tn);
END; $$;

-- --- F7 : SOINS -------------------------------------------------------------
-- p_type : 'public' (dispensaire, finance par l'institution) ou 'clinique'.
-- Le client ne choisit ni le cout, ni les ressources consommees, ni le gain.
CREATE OR REPLACE FUNCTION public.recevoir_soin(
  p_acteur text, p_pays text, p_ville text, p_batiment text, p_type text, p_cout integer)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_etat jsonb; v_sante jsonb; v_sm jsonb;
  v_jour int; v_stats jsonb; v_marqueur text;
  v_hp numeric; v_pa numeric; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0; v_pris_liquide numeric; v_pris_national numeric;
  v_taxe jsonb; v_net numeric; v_gain_hp int; v_gain_pa int;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_type NOT IN ('public','clinique') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_inconnu');
  END IF;
  -- Le cout est celui declare par l'ordre : on le revalide contre le miroir.
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts
                 WHERE fn = CASE WHEN p_type='public' THEN 'soin_public' ELSE 'soins' END
                   AND cost = coalesce(p_cout,0)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare', 'cout', p_cout);
  END IF;
  v_marqueur := CASE WHEN p_type='public' THEN 'soinPublicJour' ELSE 'soinCliniqueJour' END;

  SELECT coalesce(stats,'{}'::jsonb), coalesce(day,1), coalesce(hp,0), coalesce(pa,0),
         coalesce(liquide,0), coalesce(arg,0)
    INTO v_stats, v_jour, v_hp, v_pa, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_stats IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  IF coalesce((v_stats->>v_marqueur)::int, -1) = v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_soigne_aujourdhui');
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'structure_introuvable'); END IF;
  v_sante := coalesce(v_etat->'sante', '{}'::jsonb);
  v_sm := coalesce(v_sante->'stockMatieres', '{}'::jsonb);

  IF p_type = 'public' THEN
    IF coalesce((v_sm->>'desinfectant')::numeric,0) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'rupture_stock');
    END IF;
    v_gain_hp := 20; v_gain_pa := 0;
  ELSE
    IF coalesce((v_sm->>'desinfectant')::numeric,0) < 1
       OR coalesce((v_sm->>'medicaments')::numeric,0) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'rupture_stock');
    END IF;
    v_gain_hp := 30; v_gain_pa := 2;
  END IF;

  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);
  IF v_liquide + v_solde < coalesce(p_cout,0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'disponible', v_liquide + v_solde);
  END IF;

  v_pris_liquide := least(v_liquide, coalesce(p_cout,0));
  v_pris_national := coalesce(p_cout,0) - v_pris_liquide;

  IF p_type = 'public' THEN
    v_sm := jsonb_set(v_sm, '{desinfectant}', to_jsonb(coalesce((v_sm->>'desinfectant')::numeric,0) - 1));
    v_sante := v_sante || jsonb_build_object('stockMatieres', v_sm);
  ELSE
    v_taxe := public.appliquer_taxe_transaction(p_pays, p_ville, coalesce(p_cout,0));
    v_net := (v_taxe->>'net')::numeric;
    v_sm := jsonb_set(jsonb_set(v_sm,
              '{desinfectant}', to_jsonb(coalesce((v_sm->>'desinfectant')::numeric,0) - 1)),
              '{medicaments}', to_jsonb(coalesce((v_sm->>'medicaments')::numeric,0) - 1));
    v_sante := v_sante || jsonb_build_object('stockMatieres', v_sm,
                 'caisse', coalesce((v_sante->>'caisse')::numeric,0) + v_net);
  END IF;

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('sante', v_sante))::text), updated_at = now()
   WHERE id = v_id;

  UPDATE public.personnages_donnees
     SET liquide = v_liquide - v_pris_liquide, arg = v_arg - coalesce(p_cout,0),
         hp = least(100, v_hp + v_gain_hp), pa = least(30, v_pa + v_gain_pa),
         stats = jsonb_set(v_stats, ARRAY[v_marqueur], to_jsonb(v_jour))
   WHERE name = p_acteur;
  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national, updated_at = now() WHERE id = v_compte_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'hp', least(100, v_hp + v_gain_hp),
    'pa', least(30, v_pa + v_gain_pa), 'liquide', v_liquide - v_pris_liquide,
    'arg', v_arg - coalesce(p_cout,0), 'solde_national', v_solde - v_pris_national,
    'gain_hp', v_gain_hp, 'gain_pa', v_gain_pa, 'taxe', v_taxe);
END; $$;
REVOKE ALL ON FUNCTION public.recevoir_soin(text,text,text,text,text,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recevoir_soin(text,text,text,text,text,integer) TO authenticated;