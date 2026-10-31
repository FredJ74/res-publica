-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261026221837.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 26/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261026221837.
-- Eprouvee apres application en transaction annulee (credit non adosse refuse, credit adosse accepte, vente de bois, virements usine-ministere). Baseline NON reextrait.
-- ============================================================================
-- CAISSES (suite de 20261026020000) : credit de caisse de batiment adosse, primitives retirees
-- au navigateur, virements usine <-> ministere par le serveur (26 octobre 2026).
-- Voir l'en-tete de 20261026020000_caisses_fin_creation_argent.sql. Idempotente.
-- ============================================================================

-- Credit d'une caisse de batiment (recettes de redaction) : consomme les fonds en transit.
CREATE OR REPLACE FUNCTION public.batiment_caisse_client_crediter(p_pays text, p_ville text, p_building text, p_souscle text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF p_pays IS DISTINCT FROM v_pays THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_pays'); END IF;
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant > 100000000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  IF NOT public.fonds_transit_consommer_interne(v_moi, p_montant) THEN
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_pays || '_' || p_ville || '_' || p_building || '/' || p_souscle, p_montant, 'batiment', false, 'credit_non_adosse');
    RETURN jsonb_build_object('ok', false, 'raison', 'credit_non_adosse');
  END IF;
  v_res := public.batiment_caisse_mouvement(p_pays, p_ville, p_building, p_souscle, p_montant, NULL, 0, NULL, true);
  IF NOT coalesce((v_res ->> 'ok')::boolean, false) THEN
    PERFORM public.fonds_transit_deposer_interne(v_moi, p_montant, 'rendu:batiment');
  END IF;
  RETURN v_res;
END; $function$;
REVOKE ALL ON FUNCTION public.batiment_caisse_client_crediter(text, text, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.batiment_caisse_client_crediter(text, text, text, text, numeric) TO authenticated;

-- Les primitives heritees ne sont plus appelables par un navigateur.
REVOKE EXECUTE ON FUNCTION public.caisse_institution_mouvement(text, numeric, boolean) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.caisse_institution_mouvement_plafonne(text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.batiment_caisse_mouvement(text, text, text, text, numeric, text, numeric, numeric, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.caisse_institution_mouvement(text, numeric, boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.caisse_institution_mouvement_plafonne(text, numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.batiment_caisse_mouvement(text, text, text, text, numeric, text, numeric, numeric, boolean) TO service_role;

-- Les usines du ministere : poste du directeur -> ville et batiment (miroir de DIRECTEUR_USINE_INFO).
CREATE OR REPLACE FUNCTION public.usine_du_directeur_interne(p_poste text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p_poste
    WHEN 'directeur_pharma' THEN jsonb_build_object('ville', 'capitale', 'batiment', 'usine-pharmaceutique-luthecia')
    WHEN 'directeur_tabac_alcools' THEN jsonb_build_object('ville', 'ville_a', 'batiment', 'pole-tabac-alcools-psm')
    WHEN 'directeur_raffinerie' THEN jsonb_build_object('ville', 'ville_b', 'batiment', 'raffinerie-montrouge')
  END;
$function$;

CREATE OR REPLACE FUNCTION public.usine_virer_vers_ministere(p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_poste text; v_bat text; u jsonb; v_res jsonb; v_paie jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic'), poste ->> 'id', current_building INTO v_pays, v_poste, v_bat
    FROM public.personnages_donnees WHERE name = v_moi;
  u := public.usine_du_directeur_interne(v_poste);
  IF u IS NULL OR NOT public.mon_poste_est_dans(v_poste, v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_directeur'); END IF;
  IF v_bat IS DISTINCT FROM u ->> 'batiment' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant <> trunc(p_montant) OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  v_paie := public.payer_ordre(v_moi, 'virement_usine_ministere', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_res := public.batiment_caisse_mouvement(v_pays, u ->> 'ville', u ->> 'batiment', 'usine', -p_montant, NULL, 0, NULL, true);
  IF NOT coalesce((v_res ->> 'ok')::boolean, false) THEN
    RAISE EXCEPTION USING MESSAGE = 'hg_caisse_usine_insuffisante';
  END IF;
  v_res := public.caisse_institution_mouvement(v_pays || '_gouvernement-min_fin', p_montant, false);
  IF NOT coalesce((v_res ->> 'ok')::boolean, false) THEN
    RAISE EXCEPTION USING MESSAGE = 'hg_caisse_ministere_refus';
  END IF;
  RETURN jsonb_build_object('ok', true, 'montant', p_montant, 'paie', v_paie);
EXCEPTION WHEN raise_exception THEN
  IF SQLERRM = 'hg_caisse_usine_insuffisante' THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante'); END IF;
  IF SQLERRM = 'hg_caisse_ministere_refus' THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_ministere_refus'); END IF;
  RAISE;
END; $function$;
REVOKE ALL ON FUNCTION public.usine_virer_vers_ministere(numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.usine_virer_vers_ministere(numeric) TO authenticated;

CREATE OR REPLACE FUNCTION public.ministere_virer_vers_usine(p_poste_usine text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; u jsonb; v_res jsonb; v_paie jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('min_fin', v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_finances'); END IF;
  u := public.usine_du_directeur_interne(p_poste_usine);
  IF u IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_inconnue'); END IF;
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant <> trunc(p_montant) OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  v_paie := public.payer_ordre(v_moi, 'gestion_industrielle_portuaire', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_res := public.caisse_institution_mouvement(v_pays || '_gouvernement-min_fin', -p_montant, true);
  IF NOT coalesce((v_res ->> 'ok')::boolean, false) THEN
    RAISE EXCEPTION USING MESSAGE = 'hg_caisse_ministere_insuffisante';
  END IF;
  v_res := public.batiment_caisse_mouvement(v_pays, u ->> 'ville', u ->> 'batiment', 'usine', p_montant, NULL, 0, NULL, true);
  IF NOT coalesce((v_res ->> 'ok')::boolean, false) THEN
    RAISE EXCEPTION USING MESSAGE = 'hg_caisse_usine_absente';
  END IF;
  RETURN jsonb_build_object('ok', true, 'montant', p_montant, 'paie', v_paie);
EXCEPTION WHEN raise_exception THEN
  IF SQLERRM = 'hg_caisse_ministere_insuffisante' THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante'); END IF;
  IF SQLERRM = 'hg_caisse_usine_absente' THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_usine_absente'); END IF;
  RAISE;
END; $function$;
REVOKE ALL ON FUNCTION public.ministere_virer_vers_usine(text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ministere_virer_vers_usine(text, numeric) TO authenticated;

-- Vente de bois a une imprimerie, par le serveur. Le vendeur est sur place ; prix = cours de
-- reference du bois + 10 % ; l'imprimerie (PNJ) n'entrepose que 10 bois ; sa caisse paie.
CREATE OR REPLACE FUNCTION public.imprimerie_acheter_bois(p_qte integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_bat text; v_inv jsonb; v_arg numeric; v_liquide numeric;
  v_id text; v_etat jsonb; v_imp jsonb; v_caisse numeric; v_stock numeric; v_prix numeric; v_qte integer; v_total numeric;
  v_plafond integer := 10;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_qte IS NULL OR p_qte <= 0 OR p_qte > 1000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  SELECT coalesce(country, 'republic'), coalesce(current_city, 'capitale'), current_building,
         coalesce(inventory, '[]'::jsonb), coalesce(arg, 0), coalesce(liquide, 0)
    INTO v_pays, v_ville, v_bat, v_inv, v_arg, v_liquide
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_bat NOT IN ('la-tribune', 'imprimerie-librairie') THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF public.inventaire_quantite(v_inv, 'bois') < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', public.inventaire_quantite(v_inv, 'bois')); END IF;
  SELECT round(coalesce(prix_base, 5) * 1.10, 2) INTO v_prix FROM public.ressources_economie WHERE cle = 'bois';
  v_prix := coalesce(v_prix, 5.5);
  v_id := v_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'imprimerie_introuvable'); END IF;
  v_imp := coalesce(v_etat -> 'imprimerie', '{}'::jsonb);
  v_caisse := coalesce((v_imp ->> 'caisse')::numeric, 0);
  v_stock := coalesce((v_imp ->> 'stockBois')::numeric, 0);
  -- Vente partielle : l'imprimerie prend ce que sa caisse et sa place permettent.
  v_qte := least(p_qte, greatest(0, v_plafond - v_stock)::integer, floor(v_caisse / v_prix)::integer);
  IF v_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', CASE WHEN v_stock >= v_plafond THEN 'stock_plafond' ELSE 'caisse_insuffisante' END,
                              'stock', v_stock, 'plafond', v_plafond, 'caisse', v_caisse); END IF;
  v_total := round(v_qte * v_prix, 2);
  UPDATE public.personnages_donnees
     SET inventory = public.inventaire_retirer(v_inv, 'bois', v_qte), arg = v_arg + v_total, liquide = v_liquide + v_total
   WHERE name = v_moi;
  v_imp := v_imp || jsonb_build_object('caisse', v_caisse - v_total, 'stockBois', v_stock + v_qte);
  UPDATE public.batiments_etat SET data = to_jsonb((v_etat || jsonb_build_object('imprimerie', v_imp))::text), updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'qte', v_qte, 'demande', p_qte, 'prixUnitaire', v_prix, 'total', v_total,
                            'arg', v_arg + v_total, 'liquide', v_liquide + v_total,
                            'inventory', public.inventaire_retirer(v_inv, 'bois', v_qte));
END; $function$;
REVOKE ALL ON FUNCTION public.imprimerie_acheter_bois(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.imprimerie_acheter_bois(integer) TO authenticated;
