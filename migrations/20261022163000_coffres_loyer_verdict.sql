-- #69 PREPAREE. Verdict comptable du meme encaissement, pas de seconde perception.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.prelever_loyer_bail_verdict(text)');IF h IS NOT NULL AND h<>'770d3e29304b0c5bbb9ec390abbc1a74' THEN RAISE EXCEPTION 'definition_non_examinee: prelever_loyer_bail_verdict';END IF;
END;$g$;
ALTER TABLE public.coffres_bancaires ADD COLUMN IF NOT EXISTS dernier_loyer_montant integer NOT NULL DEFAULT 0;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.coffre_loyer_terminer_interne(jsonb,text)');
IF h='e403d96fd695b0b6814ad0899dd85ddc' THEN s:=replace(s,$a$loyer_impaye=0,loyer_jour_traitement=j$a$,$b$loyer_impaye=0,dernier_loyer_montant=(p_preparation->>'montant')::integer,loyer_jour_traitement=j$b$);EXECUTE s;
ELSIF h IS DISTINCT FROM '71e63297238f3d9af1759c3a654832ab' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_loyer_terminer_interne';END IF;
END;$p$;
CREATE OR REPLACE FUNCTION public.prelever_loyer_bail_verdict(p_bail_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE v text;m numeric:=0;
BEGIN
 IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','reserve_au_serveur');END IF;
 v:=public.prelever_loyer_bail(p_bail_id);
 IF v='paye' THEN
  SELECT dernier_loyer_montant INTO m FROM public.coffres_bancaires WHERE bail_id=p_bail_id;
  IF NOT FOUND THEN SELECT coalesce((data->>'prix')::numeric,0) INTO m FROM public.locations_actives WHERE id=p_bail_id;END IF;
  IF m IS NULL OR m<=0 THEN RAISE EXCEPTION 'encaissement_montant_inconnu';END IF;
 END IF;
 RETURN jsonb_build_object('ok',true,'verdict',v,'montant',coalesce(m,0));
END;$f$;
REVOKE ALL ON FUNCTION public.prelever_loyer_bail_verdict(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.prelever_loyer_bail_verdict(text) TO service_role;
COMMIT;
