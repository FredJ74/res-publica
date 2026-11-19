-- État de catastrophe naturelle : « budget de l'État » = caisse du gouvernement tenue par le Premier ministre
-- (caisses_batiments « <pays>_gouvernement-pm »), qui déclare. La réserve journalière de budgets_nationaux, vide en
-- pratique, n'est plus lue. Refus « budget_insuffisant » si la caisse ne couvre pas l'option choisie.
BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN RAISE EXCEPTION '% : ancrage (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;
SELECT pg_temp.rp_raccorder('public.catastrophe_etat(bigint)'::regprocedure,
  $a$'reserve', (SELECT coalesce((data->>'reserveJour')::numeric, 0) FROM public.budgets_nationaux WHERE id = e.pays))$a$,
  $b$'reserve', (SELECT coalesce((data->>'solde')::numeric, 0) FROM public.caisses_batiments WHERE id = e.pays || '_gouvernement-pm')) /* catastrophe_caisse_pm_v1 */$b$,
  'catastrophe_caisse_pm_v1');
SELECT pg_temp.rp_raccorder('public.catastrophe_declarer(bigint,boolean)'::regprocedure,
  $a$  SELECT data INTO v_nat FROM public.budgets_nationaux WHERE id = e.pays FOR UPDATE;
  IF coalesce((v_nat->>'reserveJour')::numeric, 0) < v_total THEN RETURN jsonb_build_object('ok', false, 'raison', 'budget_insuffisant', 'cout', v_total, 'reserve', coalesce((v_nat->>'reserveJour')::numeric, 0)); END IF;
  UPDATE public.budgets_nationaux SET data = jsonb_set(coalesce(v_nat, '{}'::jsonb), '{reserveJour}', to_jsonb(coalesce((v_nat->>'reserveJour')::numeric, 0) - v_total)), updated_at = now() WHERE id = e.pays;$a$,
  $b$  -- catastrophe_caisse_pm_v1 : la caisse du gouvernement tenue par le Premier ministre paie.
  IF v_total > 0 THEN
    v_flag := current_setting('rp.caisse_interne', true);
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v_rep := public.caisse_institution_mouvement(e.pays || '_gouvernement-pm', -v_total, false);
    PERFORM set_config('rp.caisse_interne', coalesce(v_flag, ''), true);
    IF (v_rep->>'ok')::boolean IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'budget_insuffisant', 'cout', v_total,
        'reserve', (SELECT coalesce((data->>'solde')::numeric, 0) FROM public.caisses_batiments WHERE id = e.pays || '_gouvernement-pm')); END IF;
  END IF;$b$,
  'catastrophe_caisse_pm_v1');
COMMIT;
