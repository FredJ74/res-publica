BEGIN;
DO $nouveau$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='pret_versionne_ecriture_proteger' AND (p.oid IS DISTINCT FROM to_regprocedure('public.pret_versionne_ecriture_proteger()') OR md5(p.prosrc)<>'fa64121184a6feaa71f20227b4a41d91')) THEN RAISE EXCEPTION 'definition_non_examinee: pret_versionne_ecriture_proteger';END IF;END;$nouveau$;

CREATE OR REPLACE FUNCTION public.pret_versionne_ecriture_proteger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE version integer;
BEGIN
 IF TG_OP='DELETE' THEN version:=OLD.contrat_version;ELSE version:=NEW.contrat_version;END IF;
 IF TG_OP='UPDATE' THEN version:=coalesce(OLD.contrat_version,NEW.contrat_version);END IF;
 IF version=2 AND NOT EXISTS(SELECT 1 FROM public.prets_ecritures_internes WHERE transaction_id=txid_current()) THEN RAISE EXCEPTION 'pret_commande_versionnee_requise';END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;ELSE RETURN NEW;END IF;
END;$f$;
REVOKE ALL ON FUNCTION public.pret_versionne_ecriture_proteger() FROM PUBLIC,anon,authenticated,service_role;
DO $trigger$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.prets'::regclass AND tgname='pret_versionne_ecriture') THEN
  CREATE TRIGGER pret_versionne_ecriture BEFORE INSERT OR UPDATE OR DELETE ON public.prets FOR EACH ROW EXECUTE FUNCTION public.pret_versionne_ecriture_proteger();
 ELSIF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.prets'::regclass AND tgname='pret_versionne_ecriture' AND tgfoid='public.pret_versionne_ecriture_proteger()'::regprocedure AND tgtype=31 AND tgenabled='O') THEN
  RAISE EXCEPTION 'trigger_pret_non_examine';
 END IF;
END;$trigger$;
COMMIT;
