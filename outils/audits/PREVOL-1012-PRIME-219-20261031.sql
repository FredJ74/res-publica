-- PREVOL LUTHÉCIA #219 après prime de signature #301. LECTURE SEULE.
-- Comparer md5(prosrc), jamais md5(pg_get_functiondef(...)), aux gardes SQL.
SELECT count(*) total,max(version) derniere FROM supabase_migrations.schema_migrations;
SELECT version,name FROM supabase_migrations.schema_migrations
 WHERE name LIKE '%caisses_collectives%' OR name LIKE '%transfert_prime_signature%'
 ORDER BY version;
SELECT p.oid::regprocedure AS contrat,md5(p.prosrc) AS md5_corps,
       md5(pg_get_functiondef(p.oid)) AS md5_definition,
       has_function_privilege('authenticated',p.oid,'EXECUTE') AS execute_auth
 FROM pg_proc p WHERE p.oid IN (
  to_regprocedure('public.club_transfert_conclure(text)'),
  to_regprocedure('public.transferts_clubs_garder()'),
  to_regprocedure('public.payer_ordre(text,text,integer,integer)')
 ) ORDER BY 1;
SELECT tgname,tgenabled FROM pg_trigger WHERE tgname IN
 ('trg_organisations_finances_garder','trg_transferts_clubs_garder') ORDER BY tgname;
SELECT count(*) AS transferts_en_cours FROM public.transferts_clubs;
