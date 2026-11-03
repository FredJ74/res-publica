-- Métadonnées seulement ; aucune identité, aucun message ni donnée PJ lus.
-- À exécuter par le canal technique autorisé avant apply_migration, jamais
-- à faire lancer par le game designer. Un écart exige une relecture privée.
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT now()AS releve_utc,current_database()AS base,current_setting('server_version')AS version;
SELECT count(*)AS migrations,max(version)AS derniere_version FROM supabase_migrations.schema_migrations;
SELECT rolname,rolbypassrls FROM pg_roles WHERE rolname IN('anon','authenticated','service_role');
SELECT version,name FROM supabase_migrations.schema_migrations
 WHERE name ILIKE '%forum%'OR version='20261103222000'ORDER BY version;
SELECT p.oid::regprocedure::text AS signature,md5(p.prosrc)AS md5_corps,
 md5(pg_get_functiondef(p.oid))AS md5_definition,p.prosecdef,p.proconfig,
 has_function_privilege('authenticated',p.oid,'EXECUTE')AS authenticated_execute,
 has_function_privilege('anon',p.oid,'EXECUTE')AS anon_execute
 FROM pg_proc p WHERE p.pronamespace='public'::regnamespace
 AND(p.proname IN('mon_personnage','forum_lecture_autorisee')
 OR p.prosrc ILIKE '%forum_topics%'OR p.prosrc ILIKE '%forum_posts%')ORDER BY signature;
SELECT c.relname,c.relrowsecurity,c.relforcerowsecurity,
 has_table_privilege('anon',c.oid,'SELECT')AS anon_lecture,
 has_table_privilege('authenticated',c.oid,'SELECT')AS auth_lecture,
 has_table_privilege('authenticated',c.oid,'INSERT')AS auth_creation,
 has_table_privilege('authenticated',c.oid,'UPDATE')AS auth_modification,
 has_table_privilege('authenticated',c.oid,'DELETE')AS auth_suppression
 FROM pg_class c WHERE c.oid IN('public.forum_topics'::regclass,'public.forum_posts'::regclass);
SELECT c.relname,p.polname,p.polcmd,p.polpermissive,p.polroles,
 pg_get_expr(p.polqual,p.polrelid)AS filtre,pg_get_expr(p.polwithcheck,p.polrelid)AS verification
 FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid
 WHERE c.oid IN('public.forum_topics'::regclass,'public.forum_posts'::regclass)ORDER BY c.relname,p.polname;
SELECT c.relname,t.tgname,t.tgenabled,pg_get_triggerdef(t.oid,true)AS definition
 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
 WHERE c.oid IN('public.forum_topics'::regclass,'public.forum_posts'::regclass)AND NOT t.tgisinternal ORDER BY c.relname,t.tgname;
ROLLBACK;
