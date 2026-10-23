-- #57 PREPAREE. Les anciennes commandes sans recu ne restent pas une porte parallele.
BEGIN;
DO $g$ DECLARE h text;BEGIN
 SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_lancer(text,text,text,text,numeric)');
 IF h IS NOT NULL THEN
  IF h NOT IN ('f7e9fbfc8c0b0e722659f7c870354159','b880f5b95bb7f0da09d51f318ded9b20') THEN RAISE EXCEPTION 'ancienne_porte_non_examinee: chantier_lancer';END IF;
  REVOKE ALL ON FUNCTION public.chantier_lancer(text,text,text,text,numeric) FROM PUBLIC,anon,authenticated,service_role;
 END IF;
 SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_verser(text,text,text,numeric)');
 IF h IS NOT NULL THEN
  IF h NOT IN ('3675b46e3e997575a173766f0e02c6f4') THEN RAISE EXCEPTION 'ancienne_porte_non_examinee: chantier_verser';END IF;
  REVOKE ALL ON FUNCTION public.chantier_verser(text,text,text,numeric) FROM PUBLIC,anon,authenticated,service_role;
 END IF;
END;$g$;
COMMIT;
