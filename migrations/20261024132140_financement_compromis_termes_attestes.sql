-- Les nouveaux financements relisent leurs termes privés, y compris après transfert.
BEGIN;
DO $g$ DECLARE h text;d text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.compromis_expire_resoudre(text,text)');
IF h='e683b9cda0a4080b545da328d2f6481c' THEN
d:=replace(d,$a$    v_montant := coalesce((v_pret->>'montant')::numeric, 0);$a$,$b$    v_montant := coalesce((v_pret->>'montant')::numeric, 0);
    IF v_type='terrain' AND v_data->>'acquisitionVersion'='2' THEN
      SELECT r.resultat->'pretCapture' INTO v_pret FROM public.terrain_acquisitions_recus r
      WHERE r.terrain=p_cible AND r.requete::text=v_data->>'acquisitionRequete' AND r.action='compromis';
      IF v_pret IS NULL OR v_pret='null'::jsonb THEN RAISE EXCEPTION 'financement_non_atteste';END IF;
      -- Le bénéficiaire peut avoir changé par transfert légitime, pas les termes payés/capturés.
      v_pret:=v_pret||jsonb_build_object('demandeur',v_data->>'compromisPar');
      v_montant:=(v_pret->>'montant')::numeric;
    END IF;$b$);
d:=replace(d,$a$(SELECT (r.resultat->'pretCapture'->>'taux')::numeric FROM public.terrain_acquisitions_recus r WHERE r.acteur=v_pret->>'demandeur' AND r.terrain=p_cible$a$,$b$(SELECT (r.resultat->'pretCapture'->>'taux')::numeric FROM public.terrain_acquisitions_recus r WHERE r.terrain=p_cible$b$);EXECUTE d;
ELSIF h IS DISTINCT FROM '838fce8517d8bb0830447a5bb3804489' THEN RAISE EXCEPTION 'definition_non_examinee: compromis_expire_resoudre termes';END IF;END;$g$;
COMMIT;
