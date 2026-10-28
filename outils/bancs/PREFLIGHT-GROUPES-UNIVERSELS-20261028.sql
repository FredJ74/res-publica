-- Lecture seule préparée, NON EXÉCUTÉE sur Supabase dans la session Codex.
-- Complète PREFLIGHT-AUDIT-SECURITE-135.sql avant tout DDL d'adhésion PJ.
BEGIN;
SET TRANSACTION READ ONLY;
-- Retrouver toute relation existante, y compris JSON et colonnes hors schéma public.
-- Métadonnées seulement, aucun personnage ni inventaire de joueur exporté.
SELECT n.nspname,c.relname,a.attname,format_type(a.atttypid,a.atttypmod) AS type
FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE a.attnum>0 AND NOT a.attisdropped AND c.relkind IN ('r','p','v','m')
 AND n.nspname NOT IN ('pg_catalog','information_schema')
 AND (a.attname ~* '(groupe|group|leader|chef)' OR c.relname ~* '(groupe|group|adhesion)')
ORDER BY 1,2,3;
-- Tous les lecteurs/écrivains candidats : ne pas prendre une empreinte pour un corps.
SELECT n.nspname,p.proname,p.oid::regprocedure::text AS signature,
 md5(pg_get_functiondef(p.oid)) AS empreinte,pg_get_functiondef(p.oid) AS definition,
 p.proacl,p.prosecdef,p.provolatile,p.proconfig
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind IN ('f','p') AND
 (p.proname ~* '^(pnj_|groupe_|rue_position_|militaire_bataille_|police_)'
  OR p.proname IN ('deplacement_enregistrer','personnages_vue_modifier')
  OR p.prosrc ~* '(leader_pj|leader_pnj_id|groupes_pj_adhesions|current_street|current_building)')
ORDER BY p.proname,p.oid;
-- Les triggers sur les positions et les deux projections police/soldats sont indispensables.
SELECT n.nspname,c.relname,t.tgname,pg_get_triggerdef(t.oid) AS definition,
 pg_get_functiondef(t.tgfoid) AS fonction
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE NOT t.tgisinternal AND n.nspname='public'
 AND c.relname IN ('personnages','personnages_donnees','presences','pnj_membres',
 'pnj_possessions','compagnies_militaires','batiments_etat','groupes_pj_adhesions')
ORDER BY c.relname,t.tgname;
SELECT version,name FROM supabase_migrations.schema_migrations
WHERE version IN ('20261027222500','20261028074753','20261028074754',
 '20261028122000','20261028122500','20261028123000','20261028123500',
 '20261028124000','20261028135642','20261028135643','20261028140626','20261028141500')
ORDER BY version;
ROLLBACK;
