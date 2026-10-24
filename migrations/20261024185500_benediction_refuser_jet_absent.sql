-- Une erreur de tirage annule le PA et le reçu, sans verdict fictif.
BEGIN;
DO $g$ DECLARE h text;d text;BEGIN
 SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.religion_benediction_demander(text,uuid)');
 IF h='469dcbbccb2f987b550e3cac67d2100f' THEN
  d:=replace(d,'IF jet NOT BETWEEN 1 AND 100 THEN','IF jet IS NULL OR jet NOT BETWEEN 1 AND 100 THEN');EXECUTE d;
 ELSIF h IS DISTINCT FROM 'b0150836980f15427f3abb8604c10146' THEN RAISE EXCEPTION 'definition_non_examinee: religion_benediction_demander';END IF;
END;$g$;
COMMIT;
