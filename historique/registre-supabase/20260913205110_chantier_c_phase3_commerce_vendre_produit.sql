-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913205110
-- Nom original      : chantier_c_phase3_commerce_vendre_produit
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 20:51:10 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 03e57c26bd6804e01a603a288c7ad8b9
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
-- CHANTIER C / PHASE 3 — FAMILLE 4 : LE COMMERCE VEND UN PRODUIT FINI.
--
-- Sept sites clients faisaient la meme chose : decrementer stockProduits, calculer la taxe, et
-- crediter la caisse -- en croyant le prix et la quantite annonces par le navigateur.
-- Une seule RPC, trois modes correspondant aux TROIS formes reellement existantes dans le jeu :
--
--   'comptoir'    : le client paie le prix affiche par le commerce (commanderProduitCommerce,
--                   confirmerAchatArme, resoudreTournee). Le prix est RELU dans le blob.
--   'service'     : la prestation est facturee par un ORDRE, pas par un prix de carte
--                   (repas gastronomique, diner d'affaires, chambre d'hotel). Le montant est
--                   valide par payer_ordre contre le miroir ordres_couts, et c'est cette RPC
--                   qui preleve -- le client ne doit donc plus appeler deduireCoutOrdre pour
--                   ces ordres, sous peine de double prelevement.
--   'marche_noir' : le prix triple est preleve et la caisse n'est PAS creditee
--                   (confirmerAchatArmeIllegal). Regle existante, recopiee telle quelle.
--
-- Aucun mode ne permet de retirer du stock sans qu'un paiement ait eu lieu dans la MEME
-- transaction : c'etait le risque a eviter en migrant ces sites.
CREATE OR REPLACE FUNCTION public.commerce_vendre_produit(
  p_acteur text, p_entreprise text, p_produit text, p_qte integer,
  p_mode text DEFAULT 'comptoir', p_ordre text DEFAULT NULL,
  p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_data jsonb; v_type text; v_pays text; v_ville text; v_jour integer;
  v_sp jsonb; v_stock numeric; v_prix numeric; v_total numeric; v_net numeric;
  v_caisse numeric; v_categorie text; v_caisse_id text;
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

  -- Le produit doit reellement etre propose ici : carte du commerce, ou recette du pays pour
  -- une armurerie. Un identifiant invente est refuse.
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

  -- ---- PAIEMENT (toujours dans la meme transaction que le prelevement de stock) ----
  IF p_mode = 'service' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, COALESCE(p_pa,0), COALESCE(p_cost,0));
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','paiement_refuse'),
                                'detail', v_r);
    END IF;
    v_total := COALESCE(p_cost, 0);
    v_pa_reste := (v_r->>'pa')::integer;
    v_arg := (v_r->>'arg')::numeric; v_liquide := (v_r->>'liquide')::numeric;
  ELSE
    -- 'marche_noir' : le triple du prix affiche, regle existante du jeu.
    v_total := v_prix * p_qte * CASE WHEN p_mode = 'marche_noir' THEN 3 ELSE 1 END;
    IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_total) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'prix', v_prix);
    END IF;
    SELECT COALESCE(arg,0), COALESCE(liquide,0), COALESCE(pa,0)
      INTO v_arg, v_liquide, v_pa_reste
      FROM public.personnages_donnees WHERE name = p_acteur;
  END IF;

  -- ---- TAXE ET CAISSE ----
  IF p_mode = 'marche_noir' THEN
    -- Ni taxe ni recette : le commerce est vole, il ne vend pas.
    v_net := 0;
  ELSE
    v_taxe := public.appliquer_taxe_transaction(v_pays, v_ville, v_total);
    v_net := COALESCE((v_taxe->>'net')::numeric, v_total);
    v_categorie := CASE v_type WHEN 'buvette' THEN 'stade' WHEN 'marche' THEN 'marche' ELSE NULL END;
    IF v_categorie IS NOT NULL THEN
      v_caisse_id := v_pays || '_' || v_categorie || '_' || v_ville;
      PERFORM public.caisse_institution_mouvement(v_caisse_id, v_net, false);
    ELSE
      v_caisse := GREATEST(0, COALESCE((v_data->>'caisse')::numeric, 0));
      v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse + v_net), true);
    END IF;
  END IF;

  -- ---- STOCK ----
  v_data := jsonb_set(v_data, '{stockProduits}',
                      jsonb_set(v_sp, ARRAY[p_produit], to_jsonb(v_stock - p_qte)), true);
  v_data := public.entreprise_ajouter_historique(v_data, v_net,
              CASE WHEN p_mode = 'marche_noir' THEN 'Vol — ' ELSE 'Vente — ' END
              || p_produit || ' x' || p_qte || ' — ' || p_acteur, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  -- ---- CE QUI EST LIVRE : decrit par le SERVEUR, depuis le miroir ----
  SELECT * INTO v_rec FROM public.recettes_commerce WHERE id = p_produit;

  RETURN jsonb_build_object('ok', true, 'produit', p_produit, 'qte', p_qte,
    'prixUnitaire', v_prix, 'total', v_total, 'net', v_net,
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
