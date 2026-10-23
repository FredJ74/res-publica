-- #94 PREPAREE : depend du moteur de premier plan de #114, aucune autre regle de plan.
BEGIN;
DO $g$ DECLARE h text;d text;BEGIN
 SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.chantier_plan_enregistrer_interne(jsonb,jsonb,boolean,text,text,text,text,integer)');
 IF h='463c43d2933cca956023561921eaf6f1' THEN
  d:=replace(d,$a$ INSERT INTO public.dossiers_urbanisme($a$,$b$ INSERT INTO public.urbanisme_plans_internes VALUES(txid_current(),auth.uid(),p_terrain);
 INSERT INTO public.dossiers_urbanisme($b$);
  d:=replace(d,$a$ RETURN p_etat;$a$,$b$ DELETE FROM public.urbanisme_plans_internes WHERE transaction_id=txid_current();
 RETURN p_etat;$b$);
  EXECUTE d;
 ELSIF h IS DISTINCT FROM '1319eefd2e0bfd7903c82f37647c5ef6' THEN RAISE EXCEPTION 'definition_non_examinee_ou_absente: plan PR114';END IF;
END;$g$;
REVOKE ALL ON FUNCTION public.chantier_plan_enregistrer_interne(jsonb,jsonb,boolean,text,text,text,text,integer) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
