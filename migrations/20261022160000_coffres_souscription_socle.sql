-- #69 PREPAREE. Souscription annuelle atomique. Aucun abonnement cree par le DDL.
BEGIN;
DO $g$ BEGIN
IF to_regclass('public.coffres_couts_autorises') IS NOT NULL AND obj_description(to_regclass('public.coffres_couts_autorises'),'pg_class') IS DISTINCT FROM 'HG69 cout PA transactionnel' THEN RAISE EXCEPTION 'coffres_couts_schema_non_examine';END IF;
END;$g$;
CREATE TABLE IF NOT EXISTS public.coffres_couts_autorises (
 transaction_id bigint NOT NULL,personnage_id uuid NOT NULL,PRIMARY KEY(transaction_id,personnage_id));
COMMENT ON TABLE public.coffres_couts_autorises IS 'HG69 cout PA transactionnel';
ALTER TABLE public.coffres_couts_autorises ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.coffres_couts_autorises FROM PUBLIC,anon,authenticated,service_role;
-- La creation du contrat et de son coffre est une seule transaction, dans cet ordre logique.
ALTER TABLE public.coffres_bancaires ALTER CONSTRAINT coffres_bancaires_bail_id_fkey DEFERRABLE INITIALLY DEFERRED;
COMMIT;
