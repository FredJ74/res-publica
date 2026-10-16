-- POUR L'AGENT AVEC CONNECTEUR : catalogue uniquement, aucune donnee joueur.
-- Aucune fonction metier appelee, aucune livraison reclamee.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT c.oid::regclass AS relation,c.relkind,c.relrowsecurity,c.relforcerowsecurity,c.relacl,
       a.attname,format_type(a.atttypid,a.atttypmod) AS type,a.attnotnull,
       pg_get_expr(d.adbin,d.adrelid) AS valeur_par_defaut
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
WHERE n.nspname='public' AND c.relname IN
 ('personnages','personnages_donnees','objets_recus','organisations','ventes_snapshots')
ORDER BY c.relname,a.attnum;

SELECT c.oid::regclass AS relation,t.tgname,t.tgenabled,pg_get_triggerdef(t.oid,true) AS definition
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
WHERE NOT t.tgisinternal AND c.relnamespace='public'::regnamespace
 AND c.relname IN ('personnages','personnages_donnees','objets_recus','organisations');

SELECT schemaname,tablename,policyname,roles,cmd,qual,with_check FROM pg_policies
WHERE schemaname='public' AND tablename IN
 ('personnages','personnages_donnees','objets_recus','organisations','ventes_snapshots');

SELECT conrelid::regclass AS relation,conname,pg_get_constraintdef(oid,true) AS definition
FROM pg_constraint WHERE conrelid IN
 (to_regclass('public.objets_recus'),to_regclass('public.personnages_donnees'),
  to_regclass('public.ventes_snapshots'),to_regclass('public.organisations'));

SELECT schemaname,tablename,indexname,indexdef FROM pg_indexes
WHERE schemaname='public' AND tablename IN
 ('objets_recus','personnages_donnees','ventes_snapshots','organisations');

SELECT p.proname,pg_get_function_identity_arguments(p.oid) AS arguments,
       pg_get_function_result(p.oid) AS resultat,md5(p.prosrc) AS md5_corps,
       p.prosecdef,p.proconfig,p.proacl,
       has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
       pg_get_functiondef(p.oid) AS definition
FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.prokind='f'
 AND (p.proname LIKE 'inventaire\_%' ESCAPE '\'
      OR p.proname IN ('tracts_reclamer_don','personnages_vue_modifier',
       'personnages_fusionner_pop','mon_personnage','exiger_acteur','mouvement_titulaire',
       'acheter_produit_commerce','donner_objet_joueur'))
ORDER BY p.proname,arguments;
ROLLBACK;
