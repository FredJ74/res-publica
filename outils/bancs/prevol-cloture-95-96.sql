-- Lecture seule. Ne valide pas un deploiement a partir du seul schema archive.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) AS arguments,
 p.prosecdef,p.proconfig,md5(pg_get_functiondef(p.oid)) AS definition,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS client_execute,
 has_function_privilege('service_role',p.oid,'EXECUTE') AS service_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN('succession_regler','succession_repondre','succession_creation_garder',
 'personnages_vue_supprimer','acheter_produit_commerce','consommer_sur_place_commerce',
 'creer_placement_national_securise','creer_placement_national','banque_nationale_placer','payer_ordre','terminer_bail');
SELECT tablename,policyname,permissive,roles,cmd,qual,with_check FROM pg_policies
WHERE schemaname='public' AND tablename IN('successions','testaments','ventes_snapshots','personnages_donnees','comptes_bancaires');
SELECT table_name,grantee,privilege_type FROM information_schema.role_table_grants WHERE table_schema='public'
 AND table_name IN('successions','testaments','ventes_snapshots') ORDER BY table_name,grantee,privilege_type;
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
 JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND NOT t.tgisinternal
 AND c.relname IN('successions','testaments','ventes_snapshots','personnages_donnees','comptes_bancaires');
SELECT table_name,column_name,data_type FROM information_schema.columns WHERE table_schema='public'
 AND table_name IN('successions','testaments','ventes_snapshots','coffres_bancaires','coffres_sources_successorales','journal_ventes_lectures')
 ORDER BY table_name,ordinal_position;
-- Aucun contenu d'inventaire ni nom de joueur exporte ici. Les dossiers anciens restent a auditer.
SELECT statut,count(*) AS dossiers,count(*) FILTER(WHERE argent_brut_total-droits_total<>argent_net_total
 OR part_etat+part_notaire<>droits_total) AS fiscalite_incoherente FROM public.successions GROUP BY statut;
SELECT count(*) AS ventes,count(DISTINCT requete) AS intentions_uniques FROM public.ventes_snapshots;
ROLLBACK;
