-- Logistique de Sovarka et contrats d'État (décisions de Fred, 15/11/2026 au soir ; GAME-DESIGN-NOVOMIRSK.md,
-- « Production et logistique de Sovarka »).
-- 1. Le port de Starovka ne sert qu'au commerce extérieur : le fournisseur national qui remplissait chaque
--    nuit les entrepôts de Sovarka disparaît (sovarka_entrepots_passe ne garde que les échanges entre villes).
--    Les entrepôts sont nourris par la production du pays (sovarka_production_passe), les échanges et les
--    importations.
-- 2. Un contrat d'État se paie au prix du pays d'origine ; en Sovarka, le prix d'exportation est le double
--    du prix de vente en Sovarka (exportations_sovarka_executer : prix de base × 2).
-- 3. Pénurie de médicaments en Républia (Fred : « il faut qu'ils en aient ») : dotation unique qui remet
--    chacun des trois entrepôts à 100 médicaments, une seule fois.
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.sovarka_entrepots_passe(date,text[])'::regprocedure);
  IF position('port_exterieur_seulement' in v_def) = 0 THEN
    v_new := replace(v_def,
$a$    FOR v_r IN SELECT cle, prix_achat_fournisseur, plafond FROM public.ressources_economie
                WHERE source = 'livraison' AND NOT (cle = ANY (p_interdites)) ORDER BY cle LOOP$a$,
$b$    FOR v_r IN SELECT cle, prix_achat_fournisseur, plafond FROM public.ressources_economie
                WHERE false /* port_exterieur_seulement (Fred, 15/11/2026) */
                  AND source = 'livraison' AND NOT (cle = ANY (p_interdites)) ORDER BY cle LOOP$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch sovarka_entrepots_passe non applique'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.exportations_sovarka_executer(date,jsonb)'::regprocedure);
  IF position('prix_base * 2' in v_def) = 0 THEN
    v_new := replace(v_def,
      $a$SELECT prix_base INTO v_prix FROM public.ressources_economie WHERE cle = v_cle;$a$,
      $b$SELECT prix_base * 2 INTO v_prix FROM public.ressources_economie WHERE cle = v_cle;$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch exportations_sovarka_executer non applique'; END IF;
    EXECUTE v_new;
  END IF;
END $mig$;

DO $dot$
DECLARE v_id text; v_stock integer;
BEGIN
  IF EXISTS (SELECT 1 FROM public.entrepot_journal WHERE operation = 'dotation_medicaments_20261115') THEN RETURN; END IF;
  FOREACH v_id IN ARRAY ARRAY['republic_capitale_entrepot-logistique-luthecia',
                              'republic_ville_a_entrepot-logistique-psm',
                              'republic_ville_b_entrepot-logistique-montrouge'] LOOP
    v_stock := public.exportation_stock_interne(v_id, 'medicaments', 0);
    IF v_stock IS NOT NULL AND v_stock < 100 THEN
      PERFORM public.exportation_stock_interne(v_id, 'medicaments', 100 - v_stock);
      INSERT INTO public.entrepot_journal(entrepot_id, operation, sens, contrepartie, ressource, quantite, prix_unitaire, fret_unitaire, montant, statut)
      VALUES (v_id, 'dotation_medicaments_20261115', 'entree', 'Dotation de l''État', 'medicaments', 100 - v_stock, 0, 0, 0, 'livre');
    END IF;
  END LOOP;
END $dot$;

-- Importations de Sovarka depuis un pays sans entrepot (El Estado : plantes, tabac). Prix du pays
-- d'origine = prix de base, faute de marche d'El Estado ; reception par exportation_recevoir (une fois par
-- jour et par matiere, payee par l'entrepot de Starovka, repartie en trois).
CREATE OR REPLACE FUNCTION public.importation_sovarka_recevoir(p_origine text, p_jour date, p_cle text, p_quantite integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE v_prix numeric;
BEGIN
  IF p_origine IS NULL OR p_origine IN ('soviet', 'republic') THEN
    RETURN jsonb_build_object('ok', false, 'acceptee', 0, 'raison', 'origine_invalide');
  END IF;
  SELECT prix_base INTO v_prix FROM public.ressources_economie WHERE cle = p_cle;
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'acceptee', 0, 'raison', 'ressource_inconnue'); END IF;
  RETURN public.exportation_recevoir(p_origine, 'soviet', p_jour, p_cle, p_quantite, v_prix);
END $f$;
REVOKE ALL ON FUNCTION public.importation_sovarka_recevoir(text, date, text, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.importation_sovarka_recevoir(text, date, text, integer) TO service_role;
