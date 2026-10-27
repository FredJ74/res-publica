-- #63 Republica : conserver taxe, caisse, stock et créer une nuit par vente payée.
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
  v_r:=public.restaurant_luthecia_vente_verifier(v_data,p_acteur,p_produits,p_mode,p_ordre);
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

  -- La chambre payee survit meme si le navigateur se ferme avant sa sauvegarde.
  -- Aucun second paiement : meme transaction que payer_ordre, taxe et caisse ci-dessus.
  IF public.restaurant_luthecia_est_commerce(v_data) AND p_ordre='reserver_chambre_hotel' THEN
    PERFORM public.hotel_nuitee_ajouter_interne(p_acteur,'hotel-republica');
  END IF;

  RETURN jsonb_build_object('ok', true, 'mode', p_mode,
    'total', v_dynamique, 'assiette', v_assiette, 'net', v_net,
    'paMetier', v_pa_metier,
    'arg', v_arg, 'liquide', v_liquide, 'pa', v_pa_reste,
    'livraison', v_livraison);
END; $function$;
