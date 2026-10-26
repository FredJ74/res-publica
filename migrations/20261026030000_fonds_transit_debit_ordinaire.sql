-- APPLIQUEE le 26/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261026222518.
-- Eprouvee apres application en transaction annulee (debit de 40 FR -> credit de 40 accepte, credit suivant refuse). Baseline NON reextrait.
-- ============================================================================
-- FONDS EN TRANSIT (suite de 20261026020000) : le debit des fonds ordinaires alimente aussi le registre
-- ============================================================================
-- Plusieurs achats paient par debiter_fonds_ordinaires (et non payer_ordre) avant de verser la
-- recette a une caisse : location d'un box au port, sels de l'assemblee, petite annonce, lobbying de
-- presse, sponsoring de club... Sans ce depot, leur recette aurait ete refusee (credit_non_adosse).
-- Seulement pour un debit demande directement par le navigateur. Idempotente.
-- ============================================================================
DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'  RETURN jsonb_build_object(''ok'', true, ''montant'', p_montant, ''debit_id'', v_debit,';
  v_ajout text := E'  -- FONDS EN TRANSIT (26/10/2026) : ce que le navigateur vient de payer pourra etre verse a une\n  -- caisse par lui (recette d''un achat). Seulement pour un debit demande directement par le navigateur.\n  IF coalesce(current_setting(''request.path'', true), '''') = ''/rpc/debiter_fonds_ordinaires'' THEN\n    PERFORM public.fonds_transit_deposer_interne(p_acteur, p_montant, ''debit_ordinaire:'' || v_debit);\n  END IF;\n\n';
BEGIN
  v_def := pg_get_functiondef('public.debiter_fonds_ordinaires(text,numeric)'::regprocedure);
  IF position('fonds_transit_deposer_interne' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_ajout || v_frag);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : debiter_fonds_ordinaires'; END IF;
  EXECUTE v_new;
END $mig$;
