-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025221942.
-- Eprouvee apres application en transaction annulee (bancs SQL du 25/10). Baseline NON reextrait.
-- ============================================================================
-- CAISSE DU BUREAU DE L'EMPLOI : LE MINISTRE DES FINANCES S'Y SERT (Fred, 25 octobre 2026)
-- ============================================================================
-- « Le ministre de l'economie pourra se servir dans cette caisse pour alimenter celle de son
-- ministere. Rien n'est automatique, ce sera un acte volontaire. »
-- La caisse <pays>_bureau-national-emploi recoit l'argent des parutions dans la presse
-- (bne_annonce_publier). Le Ministre des Finances du pays (poste min_fin) peut en virer tout ou
-- partie vers la caisse de son ministere (<pays>_gouvernement-min_fin), pour 1 PA, depuis son
-- bureau. Un refus ne coute rien. Lecture du solde gratuite.
-- Le guerre_declarer de cette serie : -20 d'Indice Diplomatique pour le pays qui declare la guerre
-- (variation existante, conservee ; suite de 20261025120100).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('bne_caisse_prelever', 1, 0) ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.bne_caisse_lire()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_bne numeric; v_min numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('min_fin', v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_finances'); END IF;
  SELECT CASE WHEN jsonb_typeof(data -> 'solde') = 'number' THEN (data ->> 'solde')::numeric ELSE 0 END INTO v_bne
    FROM public.caisses_batiments WHERE id = v_pays || '_bureau-national-emploi';
  SELECT CASE WHEN jsonb_typeof(data -> 'solde') = 'number' THEN (data ->> 'solde')::numeric ELSE 0 END INTO v_min
    FROM public.caisses_batiments WHERE id = v_pays || '_gouvernement-min_fin';
  RETURN jsonb_build_object('ok', true, 'solde_bne', coalesce(v_bne, 0), 'solde_ministere', coalesce(v_min, 0));
END; $function$;
REVOKE ALL ON FUNCTION public.bne_caisse_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bne_caisse_lire() TO authenticated;

CREATE OR REPLACE FUNCTION public.bne_caisse_prelever(p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_src text; v_dst text; v_data jsonb; v_solde numeric; v_paie jsonb; v_min numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('min_fin', v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_finances'); END IF;
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant <> trunc(p_montant) OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  v_src := v_pays || '_bureau-national-emploi';
  v_dst := v_pays || '_gouvernement-min_fin';
  -- Verrous dans un ordre fixe : le Bureau puis le ministere.
  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_src FOR UPDATE;
  v_solde := CASE WHEN jsonb_typeof(v_data -> 'solde') = 'number' THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  IF coalesce(v_solde, 0) < p_montant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant', 'solde', coalesce(v_solde, 0)); END IF;
  v_paie := public.payer_ordre(v_moi, 'bne_caisse_prelever', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  UPDATE public.caisses_batiments SET data = coalesce(data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - p_montant),
         updated_at = now() WHERE id = v_src;
  INSERT INTO public.caisses_batiments (id, data, updated_at)
  VALUES (v_dst, jsonb_build_object('solde', p_montant), now())
  ON CONFLICT (id) DO UPDATE
     SET data = coalesce(public.caisses_batiments.data, '{}'::jsonb)
              || jsonb_build_object('solde', coalesce(CASE WHEN jsonb_typeof(public.caisses_batiments.data -> 'solde') = 'number'
                                                           THEN (public.caisses_batiments.data ->> 'solde')::numeric END, 0) + p_montant),
         updated_at = now()
  RETURNING (data ->> 'solde')::numeric INTO v_min;
  RETURN jsonb_build_object('ok', true, 'montant', p_montant, 'solde_bne', v_solde - p_montant,
                            'solde_ministere', v_min, 'paie', v_paie);
END; $function$;
REVOKE ALL ON FUNCTION public.bne_caisse_prelever(numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bne_caisse_prelever(numeric) TO authenticated;

-- Declarer une guerre : -20 d'Indice Diplomatique pour le pays qui la declare.
DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'  RETURN jsonb_build_object(''ok'', true, ''id'', v_id, ''attaquant'', v_pays, ''attaque'', p_pays_attaque);';
  v_ajout text := E'  -- Indice Diplomatique (25/10/2026) : -20 pour le pays qui declare la guerre.\n  PERFORM public.indice_diplomatique_varier_interne(v_pays, -20, ''guerre_declaree'', v_moi);\n\n';
BEGIN
  v_def := pg_get_functiondef('public.guerre_declarer(text)'::regprocedure);
  IF position('indice_diplomatique_varier_interne' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_ajout || v_frag);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : fragment de guerre_declarer introuvable'; END IF;
  EXECUTE v_new;
END $mig$;
