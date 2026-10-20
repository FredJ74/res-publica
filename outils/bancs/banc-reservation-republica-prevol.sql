-- Canal technique autorise uniquement. Lecture seule, aucun appel de paiement/reservation.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT version,name FROM supabase_migrations.schema_migrations
WHERE version IN ('20261019213444','20261019221500','20261020114246') ORDER BY version;
SELECT p.oid::regprocedure AS signature,pg_get_userbyid(p.proowner) AS proprietaire,
 p.prosecdef,p.provolatile,p.proconfig,md5(p.prosrc) AS source_md5,pg_get_functiondef(p.oid) AS definition,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN
 ('restaurant_luthecia_est_commerce','restaurant_luthecia_vente_verifier',
  'commerce_vendre_produit_interne','commerce_vendre_produit','payer_ordre',
  'pa_bonus_chambre','pa_crediter_interne','personnages_vue_modifier');
SELECT t.tgrelid::regclass AS relation,t.tgname,pg_get_triggerdef(t.oid),pg_get_functiondef(t.tgfoid)
FROM pg_trigger t WHERE NOT t.tgisinternal AND t.tgrelid IN
 ('public.personnages_donnees'::regclass,'public.personnages'::regclass,'public.entreprises'::regclass);
SELECT building_id,montant FROM public.pa_bonus_hotel WHERE building_id='hotel-republica';
SELECT table_name,column_name,data_type FROM information_schema.columns
WHERE table_schema='public' AND table_name IN ('personnages_donnees','personnages') AND column_name='reservation_hotel';
-- Empreintes avant/apres DDL, pas de donnees personnelles dans le resultat.
-- Canal avec visibilite complete requis ; ne pas confondre une empreinte RLS partielle.
SELECT 'personnages_donnees' AS relation,count(*) AS nombre,
 md5(coalesce(string_agg(md5(to_jsonb(p)::text),'' ORDER BY name),'')) AS empreinte
FROM public.personnages_donnees p
UNION ALL
SELECT 'entreprises',count(*),md5(coalesce(string_agg(md5(to_jsonb(e)::text),'' ORDER BY id),'')) FROM public.entreprises e;
ROLLBACK;
