-- Lecture seule du catalogue du projet jxpwoosmmhohoihxpbuc, avant toute migration.
-- PREPARE, NON EXECUTE dans cette session ; ne consulte aucun personnage reel.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS arguments,
       p.prosecdef, p.proconfig, p.proacl, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN
 ('police_detection_verifier','police_reddition_resoudre','police_fuite_resoudre',
  'police_combat_resoudre','rue_position_lire','rue_position_enregistrer',
  'combat_coup_resoudre','justice_recherches','justice_executer_condamnation_soi')
ORDER BY p.proname,arguments;
SELECT c.relname,c.relrowsecurity,c.relforcerowsecurity,c.relacl,
       a.attname,format_type(a.atttypid,a.atttypmod) AS type,a.attnotnull
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
WHERE n.nspname='public' AND c.relname IN
 ('police_interceptions','police_combat_rounds','police_detection_attempts','rue_noeuds_serveur')
ORDER BY c.relname,a.attnum;
SELECT tablename,policyname,roles,cmd,qual,with_check FROM pg_policies
WHERE schemaname='public' AND tablename IN ('police_interceptions','police_combat_rounds','personnages_donnees');
SELECT tablename,indexname,indexdef FROM pg_indexes
WHERE schemaname='public' AND tablename IN ('police_interceptions','police_combat_rounds');
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid)
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND NOT t.tgisinternal
AND c.relname IN ('police_interceptions','police_combat_rounds','personnages_donnees');
ROLLBACK;
