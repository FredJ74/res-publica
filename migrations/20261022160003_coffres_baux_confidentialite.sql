-- #69 PREPAREE. Les contrats de coffres prives ne rejoignent pas la liste publique des locaux.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_bail_consultable(text)');IF h IS NOT NULL AND h<>'704df68f6fe857818f283a154dfa9446' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_bail_consultable';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.coffre_bail_consultable(p_bail_id text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $f$
 SELECT NOT EXISTS(SELECT 1 FROM public.coffres_bancaires WHERE bail_id=p_bail_id)
 OR EXISTS(SELECT 1 FROM public.coffres_bancaires c JOIN public.personnages_donnees p ON p.id=c.titulaire_id
  WHERE c.bail_id=p_bail_id AND p.user_id=auth.uid() AND p.name=public.mon_personnage());
$f$;
REVOKE ALL ON FUNCTION public.coffre_bail_consultable(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.coffre_bail_consultable(text) TO anon,authenticated;
ALTER TABLE public.locations_actives ENABLE ROW LEVEL SECURITY;
DO $p$ DECLARE p record;BEGIN
 SELECT * INTO p FROM pg_policy WHERE polrelid='public.locations_actives'::regclass AND polname='coffres_baux_lecture_privee';
 IF NOT FOUND THEN
  EXECUTE 'CREATE POLICY coffres_baux_lecture_privee ON public.locations_actives AS RESTRICTIVE FOR SELECT TO anon,authenticated USING(public.coffre_bail_consultable(id))';
 ELSIF p.polpermissive OR p.polcmd<>'r' OR pg_get_expr(p.polqual,p.polrelid)<>'coffre_bail_consultable(id)' OR cardinality(p.polroles)<>2
 OR NOT (p.polroles @> ARRAY[(SELECT oid FROM pg_roles WHERE rolname='anon'),(SELECT oid FROM pg_roles WHERE rolname='authenticated')]::oid[]) THEN
  RAISE EXCEPTION 'coffres_policy_non_examinee';
 END IF;
END;$p$;
COMMIT;
