-- #69 PREPAREE. Pas d'orphelin pendant le raccordement du moteur successoral.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffres_suppression_garder()');IF h IS NOT NULL AND h<>'18fe81303c601ac9ae88c3975425d594' THEN RAISE EXCEPTION 'definition_non_examinee: coffres_suppression_garder()';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.coffres_suppression_garder()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
BEGIN
 IF EXISTS(SELECT 1 FROM public.coffres_bancaires WHERE titulaire_id=OLD.id) THEN
  RAISE EXCEPTION 'coffres_succession_non_raccordee';
 END IF;
 RETURN OLD;
END;$f$;
REVOKE ALL ON FUNCTION public.coffres_suppression_garder() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS zzzz_coffres_suppression ON public.personnages_donnees;
CREATE TRIGGER zzzz_coffres_suppression BEFORE DELETE ON public.personnages_donnees FOR EACH ROW EXECUTE FUNCTION public.coffres_suppression_garder();
COMMIT;
