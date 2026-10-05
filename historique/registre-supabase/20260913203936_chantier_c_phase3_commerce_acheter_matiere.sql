-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913203936
-- Nom original      : chantier_c_phase3_commerce_acheter_matiere
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 20:39:36 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ad76ac0e10a69ca12d8e2400fd928122
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
-- CHANTIER C / PHASE 3 — FAMILLE 3 : LE COMMERCE ACHETE UNE MATIERE A UN JOUEUR.
--
-- Sites migres : vendreMatiereCommerce (commerces alimentaires/marche) et confirmerVenteMatiere
-- (armurerie) -- une seule et meme operation metier, migree une seule fois.
-- Le navigateur calculait le prix, le total, le nouveau cout moyen, le stock final, retirait le
-- lot de son propre inventaire et se creditait lui-meme. Tout est relu et recalcule ici.
--
-- Calque direct de vendre_matiere_a_usine (phase 2) : meme ordonnancement, memes primitives
-- d'inventaire, meme formule de cout moyen pondere -- rien de nouveau n'est invente.
CREATE OR REPLACE FUNCTION public.commerce_acheter_matiere(
  p_acteur text, p_entreprise text, p_matiere text, p_qte integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_data jsonb; v_type text; v_pays text; v_ville text;
  v_inv jsonb; v_arg numeric; v_liquide numeric; v_detenu numeric;
  v_sm jsonb; v_cmm jsonb; v_caisse numeric; v_stock numeric;
  v_plafond numeric; v_declare numeric; v_smc numeric;
  v_prix numeric; v_total numeric; v_cout_moyen numeric;
  v_categorie text; v_caisse_id text; v_r jsonb; v_inv_apres jsonb;
  v_accepte boolean;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_qte IS NULL OR p_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_type  := COALESCE(v_data->>'type','');
  v_pays  := COALESCE(v_data->>'country','republic');
  v_ville := COALESCE(v_data->>'city','capitale');

  -- Matiere acceptee : union des materiaux de la CARTE pour un commerce, union des materiaux
  -- des recettes du pays pour une armurerie. Jamais une liste codee en dur.
  IF v_type = 'armurerie' THEN
    SELECT EXISTS (SELECT 1 FROM public.recettes_production r, jsonb_object_keys(r.materiaux) m
                    WHERE r.pays = v_pays AND m = p_matiere) INTO v_accepte;
  ELSE
    SELECT EXISTS (
      SELECT 1 FROM jsonb_array_elements_text(COALESCE(v_data->'carte','[]'::jsonb)) c
        JOIN public.recettes_commerce r ON r.id = c.value, jsonb_object_keys(r.materiaux) m
       WHERE m = p_matiere) INTO v_accepte;
  END IF;
  IF NOT v_accepte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee');
  END IF;

  SELECT COALESCE(inventory,'[]'::jsonb), COALESCE(arg,0), COALESCE(liquide,0)
    INTO v_inv, v_arg, v_liquide
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_detenu := public.inventaire_quantite(v_inv, p_matiere);
  IF v_detenu < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu);
  END IF;

  v_sm     := COALESCE(v_data->'stockMatieres', '{}'::jsonb);
  v_cmm    := COALESCE(v_data->'coutMoyenMatieres', '{}'::jsonb);
  v_caisse := GREATEST(0, COALESCE((v_data->>'caisse')::numeric, 0));
  v_stock  := COALESCE((v_sm->>p_matiere)::numeric, 0);

  -- Plafond : min(stockMax declare, STOCK_MAX_COMMERCE), exactement plafondEffectifCommerce.
  -- L'armurerie n'a jamais eu de plafond sur ses matieres : on ne lui en invente pas un.
  IF v_type = 'armurerie' THEN
    v_plafond := NULL;
  ELSE
    SELECT valeur INTO v_smc FROM public.entreprises_constantes WHERE cle = 'stock_max_commerce';
    v_declare := (v_data->'parametres'->'stockMax'->>p_matiere)::numeric;
    v_plafond := CASE WHEN v_declare IS NOT NULL THEN LEAST(v_declare, COALESCE(v_smc, 20))
                      ELSE COALESCE(v_smc, 20) END;
    IF v_stock + p_qte > v_plafond THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein',
                                'placeRestante', GREATEST(0, v_plafond - v_stock));
    END IF;
  END IF;

  -- prixAchatMatiereCommerce : le prix manuel du commerce, sinon le tarif fournisseur.
  v_prix := (v_data->'parametres'->'prixAchatMatiere'->>p_matiere)::numeric;
  IF v_prix IS NULL THEN
    SELECT prix_achat_fournisseur INTO v_prix FROM public.ressources_economie WHERE cle = p_matiere;
  END IF;
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
  v_total := v_prix * p_qte;

  -- Caisse : autonome, ou institutionnelle (buvette -> stade, marche -> marche), via la
  -- primitive atomique deja existante caisse_institution_mouvement.
  v_categorie := CASE v_type WHEN 'buvette' THEN 'stade' WHEN 'marche' THEN 'marche' ELSE NULL END;
  IF v_categorie IS NOT NULL THEN
    v_caisse_id := v_pays || '_' || v_categorie || '_' || v_ville;
    v_r := public.caisse_institution_mouvement(v_caisse_id, -v_total, false);
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
    END IF;
  ELSE
    IF v_caisse < v_total THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
    END IF;
  END IF;

  -- Cout moyen pondere, meme formule que crediterStockMatiereCommerce.
  v_cout_moyen := CASE WHEN v_stock + p_qte = 0 THEN 0
    ELSE round(((COALESCE((v_cmm->>p_matiere)::numeric, 0) * v_stock) + (v_prix * p_qte))
               / (v_stock + p_qte), 4) END;

  v_inv_apres := public.inventaire_retirer(v_inv, p_matiere, p_qte);
  UPDATE public.personnages_donnees
     SET inventory = v_inv_apres, arg = v_arg + v_total, liquide = v_liquide + v_total,
         updated_at = now()
   WHERE name = p_acteur;

  v_data := v_data || jsonb_build_object(
    'stockMatieres', jsonb_set(v_sm, ARRAY[p_matiere], to_jsonb(v_stock + p_qte)),
    'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[p_matiere], to_jsonb(v_cout_moyen)));
  IF v_categorie IS NULL THEN
    v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_total), true);
  END IF;
  v_data := public.entreprise_ajouter_historique(v_data, -v_total,
    'Achat de matière première (' || p_matiere || ' x' || p_qte || ') — ' || p_acteur);

  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'prixUnitaire', v_prix, 'qte', p_qte,
    'arg', v_arg + v_total, 'liquide', v_liquide + v_total, 'inventory', v_inv_apres);
END; $$;
