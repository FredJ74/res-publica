-- #379, intégrateur : lecture seule, aucun acteur/compte privé extrait.
-- Ce relevé complète celui communiqué (1137 migrations, 20261102191015), sans le remplacer.
-- Un MD5 différent exige la relecture privée du corps réel, jamais une empreinte ajustée pour passer.
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT now() AS releve_utc,count(*)AS migrations,max(version)AS derniere_version FROM supabase_migrations.schema_migrations;
WITH attendues(signature,md5_baseline_examine)AS(VALUES
 ('public.militaire_subtiliser_tenter(text)','1beb8dac38360e6433f9e151a71e7601'),
 ('public.impact_marquer_traite(text)','da9be1d37343d17b4b5c1ec5bae250e6'),
 ('public.crime_voler(text,text,boolean,integer,integer)','5385192f8743683ef974df4b19dfeb23'),
 ('public.employe_recruter(text,text,text,text,integer,integer)','0ff18ce06b089e2e8c10c28742ceb350'))
SELECT a.signature,a.md5_baseline_examine,p.oid IS NOT NULL AS presente,md5(p.prosrc)AS md5_vivant,
       md5(p.prosrc)=a.md5_baseline_examine AS baseline_inchange,
       has_function_privilege('authenticated',p.oid,'EXECUTE')AS authenticated_execute,
       has_function_privilege('anon',p.oid,'EXECUTE')AS anon_execute
FROM attendues a LEFT JOIN pg_proc p ON p.oid=to_regprocedure(a.signature)ORDER BY a.signature;
SELECT p.oid::regprocedure AS signature,md5(p.prosrc)AS md5_corps,
       has_function_privilege('authenticated',p.oid,'EXECUTE')AS authenticated_execute,
       has_function_privilege('anon',p.oid,'EXECUTE')AS anon_execute
FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.proname IN
 ('impact_marquer_traite','militaire_subtiliser_tenter','employe_metiers_recrutables','inventaire_deposer_interne','hospitalisation_pa_epuises_declencheur')ORDER BY p.oid::regprocedure::text;
SELECT type_butin,traite,count(*)AS nombre FROM public.vols_en_attente GROUP BY type_butin,traite ORDER BY type_butin,traite;
SELECT indice,traite,count(*)AS nombre FROM public.impacts_indices_attente GROUP BY indice,traite ORDER BY indice,traite;
SELECT metier,recrutable,cout_initial,cout_jour FROM public.pnj_metiers_profils WHERE metier='codetenu';
SELECT count(*)AS candidats_codetenu_actifs FROM public.pnj_candidats_catalogue WHERE metier='codetenu'AND actif;
SELECT tgname,tgenabled,pg_get_triggerdef(oid,true)AS definition FROM pg_trigger
 WHERE tgrelid='public.personnages_donnees'::regclass AND tgname IN('trg_hospitalisation_pa_epuises','zzzz_hg_inventory_revision');
-- Contrats de sauvegarde à rapprocher du diagnostic --ancien-cache, sans lignes PJ.
SELECT p.oid::regprocedure::text AS signature,md5(p.prosrc)AS md5_vivant
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public'AND p.proname IN('personnages_vue_modifier','personnages_fusionner_pop','fiche_fusionner_ecran','est_appel_serveur')ORDER BY p.oid::regprocedure::text;
SELECT version,name FROM supabase_migrations.schema_migrations
 WHERE version IN('20261102202046','20261102202047');
ROLLBACK;
