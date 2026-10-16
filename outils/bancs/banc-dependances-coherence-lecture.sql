-- Lecture seule pour l'agent disposant du connecteur Supabase.
-- Aucune creation, aucune ecriture, aucun appel de fonction metier.
SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS arguments,
       pg_get_function_result(p.oid) AS resultat, p.prosecdef AS security_definer,
       p.proconfig, p.proacl,
       has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
       pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN
 ('consommer_sur_place_commerce','tracts_electoraux_distribuer_collectif',
  'acheter_produit_commerce','mouvement_titulaire','exiger_acteur','personnages_vue_modifier')
ORDER BY p.proname,arguments;

SELECT c.oid::regclass AS relation,c.relkind,c.reloptions,c.relacl,
       CASE WHEN c.relkind IN ('v','m') THEN pg_get_viewdef(c.oid,true) END AS definition,
       has_table_privilege('anon',c.oid,'SELECT') AS anon_lecture,
       has_table_privilege('authenticated',c.oid,'SELECT') AS authenticated_lecture
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN ('archives_tribune_index','personnages','personnages_donnees');

SELECT p.proname, d.refobjid::regclass AS relation_dependante,d.deptype
FROM pg_depend d JOIN pg_proc p ON p.oid=d.objid
WHERE d.classid='pg_proc'::regclass AND d.refclassid='pg_class'::regclass
 AND p.pronamespace='public'::regnamespace
 AND p.proname IN ('consommer_sur_place_commerce','tracts_electoraux_distribuer_collectif','acheter_produit_commerce');
-- L'absence dans pg_depend ne prouve pas l'absence de dependance PL/pgSQL :
-- lire aussi le corps des fonctions. Les Edge Functions se controlent via
-- leur inventaire et leurs sources de deploiement, pas uniquement pg_proc.
