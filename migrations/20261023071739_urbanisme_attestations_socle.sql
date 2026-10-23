-- #94 PREPAREE : autorisations uniquement internes aux transactions d'urbanisme.
BEGIN;
CREATE TABLE IF NOT EXISTS public.urbanisme_archives_attestees (
 archive text PRIMARY KEY REFERENCES public.dossiers_urbanisme(id),
 cle_evenement text NOT NULL UNIQUE,emetteur text,objet_id text
);
ALTER TABLE public.urbanisme_archives_attestees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.urbanisme_archives_attestees FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS public.urbanisme_decisions_internes(transaction_id bigint PRIMARY KEY,acteur uuid NOT NULL,terrain text NOT NULL);
CREATE TABLE IF NOT EXISTS public.urbanisme_plans_internes(transaction_id bigint PRIMARY KEY,acteur uuid NOT NULL,terrain text NOT NULL);
ALTER TABLE public.urbanisme_decisions_internes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.urbanisme_plans_internes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.urbanisme_decisions_internes,public.urbanisme_plans_internes FROM PUBLIC,anon,authenticated;
COMMIT;
