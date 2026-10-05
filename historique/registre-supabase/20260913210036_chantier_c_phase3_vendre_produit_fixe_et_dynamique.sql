-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913210036
-- Nom original      : chantier_c_phase3_vendre_produit_fixe_et_dynamique
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 21:00:36 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6c0e75e0c6c30f746323a2abb5b3b30f
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
-- CHANTIER C / PHASE 3 — FAMILLE 4, VERSION DEFINITIVE.
--
-- ROLE DE payer_ordre, arrete ici : elle reste la primitive des COUTS FIXES D'ORDRE (les PA et
-- les FR reellement declares dans data.js, miroites dans ordres_couts). Elle ne devient PAS la
-- primitive des prix de transaction variables -- elle ne peut pas l'etre : le prix d'une arme est
-- fixe par le proprietaire de l'armurerie, il n'existe dans aucun catalogue statique.
--
-- Un ordre qui melange les deux (choisir_arme : 1 PA fixe + le prix de l'arme) est donc traite en
-- DEUX temps, dans la meme transaction :
--   1. la part FIXE passe par payer_ordre, qui la valide contre le miroir. Une valeur non
--      declaree est refusee -- le navigateur ne gagne aucune liberte.
--   2. la part DYNAMIQUE est recalculee ici, a partir du prix reellement inscrit dans le blob du
--      commerce, puis prelevee. Aucun montant transmis par le client n'est cru.
-- Ni double debit (la part fixe n'est prelevee qu'une fois, par payer_ordre), ni absence de
-- debit (la part dynamique l'est toujours avant le prelevement de stock).
CREATE OR REPLACE FUNCTION public.commerce_vendre_produit(
  p_acteur text, p_entreprise text, p_produit text, p_qte integer,
  p_mode text DEFAULT 'comptoir', p_ordre text DEFAULT NULL,
  p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_data jsonb; v_type text; v_pays text; v_ville text; v_jour integer;
  v_sp jsonb; v_stock numeric; v_prix numeric; v_dynamique numeric; v_assiette numeric;
  v_net numeric; v_caisse numeric; v_categorie text; v_caisse_id text;
  v_r jsonb; v_taxe jsonb; v_rec record; v_au_catalogue boolean;
  v_arg numeric; v_liquide numeric; v_pa_reste integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_qte IS NULL OR p_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF p_mode NOT IN ('comptoir', 'service', 'marche_noir') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_type  := COALESCE(v_data->>'type','');
  v_pays  := COALESCE(v_data->>'country','republic');
  v_ville := COALESCE(v_data->>'city','capitale');

  -- Le produit doit reellement etre propose ici : carte du commerce, ou recette du pays pour une
  -- armurerie. Un identifiant invente est refuse.
  IF v_type = 'armurerie' THEN
    SELECT EXISTS (SELECT 1 FROM public.recettes_production
                    WHERE id = p_produit AND pays = v_pays) INTO v_au_catalogue;
  ELSE
    v_au_catalogue := COALESCE(v_data->'carte','[]'::jsonb) @> jsonb_build_array(to_jsonb(p_produit));
  END IF;
  IF NOT v_au_catalogue THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_non_propose');
  END IF;

  v_sp := COALESCE(v_data->'stockProduits', '{}'::jsonb);
  v_stock := COALESCE((v_sp->>p_produit)::numeric, 0);
  IF v_stock < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'stock', v_stock);
  END IF;

  v_prix := (v_data->'parametres'->'prixVente'->>p_produit)::numeric;
  IF v_prix IS NULL AND p_mode <> 'service' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_non_defini');
  END IF;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;

  -- ---- 1. PART FIXE DE L'ORDRE (PA et FR declares) -----------------------
  IF COALESCE(p_ordre,'') <> '' AND (COALESCE(p_pa,0) > 0 OR COALESCE(p_cost,0) > 0) THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, COALESCE(p_pa,0), COALESCE(p_cost,0));
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','paiement_refuse'),
                                'detail', v_r);
    END IF;
  END IF;

  -- ---- 2. PART DYNAMIQUE (recalculee, jamais transmise) ------------------
  v_dynamique := CASE p_mode
                   WHEN 'comptoir'    THEN v_prix * p_qte
                   WHEN 'marche_noir' THEN v_prix * p_qte * 3
                   ELSE 0 END;
  IF v_dynamique > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_dynamique) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                                'prix', v_prix, 'total', v_dynamique);
    END IF;
  END IF;

  SELECT COALESCE(arg,0), COALESCE(liquide,0), COALESCE(pa,0)
    INTO v_arg, v_liquide, v_pa_reste
    FROM public.personnages_donnees WHERE name = p_acteur;

  -- ---- 3. TAXE ET RECETTE DU COMMERCE ------------------------------------
  -- L'assiette taxable est ce que le commerce a reellement encaisse : le prix dynamique pour une
  -- vente au comptoir, le cout de l'ordre pour une prestation facturee.
  v_assiette := CASE p_mode WHEN 'service' THEN COALESCE(p_cost,0) ELSE v_dynamique END;
  IF p_mode = 'marche_noir' THEN
    -- Ni taxe ni recette : le commerce est vole, il ne vend pas. Regle existante.
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

  -- ---- 4. STOCK -----------------------------------------------------------
  v_data := jsonb_set(v_data, '{stockProduits}',
                      jsonb_set(v_sp, ARRAY[p_produit], to_jsonb(v_stock - p_qte)), true);
  v_data := public.entreprise_ajouter_historique(v_data, v_net,
              CASE WHEN p_mode = 'marche_noir' THEN 'Vol — ' ELSE 'Vente — ' END
              || p_produit || ' x' || p_qte || ' — ' || p_acteur, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  -- ---- 5. CE QUI EST LIVRE : decrit par le SERVEUR ------------------------
  SELECT * INTO v_rec FROM public.recettes_commerce WHERE id = p_produit;

  RETURN jsonb_build_object('ok', true, 'produit', p_produit, 'qte', p_qte,
    'prixUnitaire', v_prix, 'total', v_dynamique, 'assiette', v_assiette, 'net', v_net,
    'arg', v_arg, 'liquide', v_liquide, 'pa', v_pa_reste,
    'stockRestant', v_stock - p_qte,
    'livraison', CASE WHEN v_rec.id IS NULL THEN NULL ELSE jsonb_build_object(
        'id', v_rec.id, 'label', v_rec.label, 'categorie', v_rec.categorie,
        'effets', COALESCE(v_rec.effets, '{}'::jsonb), 'icone', v_rec.icone,
        'image', v_rec.image, 'description', v_rec.description,
        'familleProduitMarche', v_rec.famille_produit_marche,
        'bonusIntegrationVille', v_rec.bonus_integration_ville) END);
END; $$;

REVOKE EXECUTE ON FUNCTION public.commerce_vendre_produit(text,text,text,integer,text,text,integer,integer)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.commerce_vendre_produit(text,text,text,integer,text,text,integer,integer)
  TO authenticated, service_role;
