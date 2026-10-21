-- LECTURE SEULE, a collecter par un outil autorise avant validation de la PR #56.
-- Aucun appel metier, aucun solde/personnage/auth.users exporte.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT version,name FROM supabase_migrations.schema_migrations WHERE name ILIKE '%presence%' OR name ILIKE '%combat%' OR name ILIKE '%rue%' OR name ILIKE '%impact%' ORDER BY version;
SELECT p.oid::regprocedure AS signature,p.prosecdef,p.provolatile,p.proconfig,md5(p.prosrc),pg_get_functiondef(p.oid),
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon
 FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND
 (p.proname IN ('rue_position_enregistrer','rue_sortie_batiment_lire','impact_deposer','impact_marquer_traite','impact_realite_appliquer','impacts_realites_synchroniser','personnages_preserver_impact_serveur','rue_position_enregistrer_moteur_20261021','payer_ordre','exiger_acteur','personnages_ecrire','presences_realites_lire','mon_personnage') OR p.proname LIKE 'militaire_bataille%' OR p.proname LIKE 'combat_%') ORDER BY 1;
SELECT c.relname,a.attname,format_type(a.atttypid,a.atttypmod) FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
 WHERE c.relnamespace='public'::regnamespace AND c.relname IN ('personnages_donnees','personnages','presences','impacts_indices_attente') AND a.attnum>0 AND NOT a.attisdropped ORDER BY c.relname,a.attnum;
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
 WHERE c.relnamespace='public'::regnamespace AND c.relname IN ('personnages_donnees','personnages','presences','impacts_indices_attente') AND NOT t.tgisinternal;
SELECT tablename,policyname,roles,cmd,qual,with_check FROM pg_policies WHERE schemaname='public' AND tablename IN ('personnages_donnees','personnages','presences','impacts_indices_attente');
SELECT extname,extversion FROM pg_extension WHERE extname IN ('pg_cron','pg_net');
SELECT schemaname,tablename FROM pg_tables WHERE schemaname='cron';
-- Ne pas exporter les commandes de jobs sans occultation des secrets eventuels.
ROLLBACK;
