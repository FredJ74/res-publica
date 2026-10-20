-- LECTURE SEULE. Aucun appel métier, aucune identité ni aucun solde individuel exporté.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT version FROM supabase_migrations.schema_migrations
 WHERE name ILIKE '%chantier%' OR name ILIKE '%terrain%' OR name ILIKE '%reception%' ORDER BY version;
SELECT p.oid::regprocedure AS signature,p.prosecdef,p.proconfig,md5(p.prosrc) AS empreinte,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon,pg_get_functiondef(p.oid) AS definition
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN
 ('vendre_materiaux_chantier','chantier_prix_definir','chantier_lancer','chantier_verser',
 'terrain_permis_acte','terrain_chantier_acte','terrain_lots_acte','restituer_reliquats_chantier',
 'inventaire_reception_etat','pret_national_contracter','terrain_proprietaire_muter',
 'exiger_acteur','titulaire_est_moi','terrain_etat_fusionner_interne','helvetia_debiter_fonds_ordinaires') ORDER BY 1;
SELECT c.relname,a.attname,format_type(a.atttypid,a.atttypmod) AS type
 FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname IN
 ('personnages','personnages_donnees','terrains_etat','caisses_batiments','batiments_etat','ressources_economie','comptes_bancaires')
 AND a.attnum>0 AND NOT a.attisdropped ORDER BY c.relname,a.attnum;
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid) AS definition
 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname IN ('personnages','personnages_donnees','terrains_etat') AND NOT t.tgisinternal;
SELECT schemaname,tablename,policyname,roles,cmd,qual,with_check FROM pg_policies
 WHERE schemaname='public' AND tablename IN
 ('personnages','personnages_donnees','terrains_etat','chantier_requetes','caisses_batiments','batiments_etat');
-- Toutes les dépendances SQL enregistrées des fonctions du chantier ; SQL dynamique à auditer séparément.
SELECT p.oid::regprocedure AS fonction,pg_describe_object(d.refclassid,d.refobjid,d.refobjsubid) AS dependance
 FROM pg_depend d JOIN pg_proc p ON d.classid='pg_proc'::regclass AND d.objid=p.oid
 WHERE p.pronamespace='public'::regnamespace AND
 (p.proname ILIKE '%chantier%' OR p.proname='terrain_permis_acte');
-- Agregats uniquement : ne pas exporter les comptes ni soldes individuels.
SELECT count(*) FILTER (WHERE liquide<>trunc(liquide) OR arg<>trunc(arg)) AS personnages_fractionnaires,
 count(*) FILTER (WHERE liquide<0) AS liquides_negatifs FROM public.personnages_donnees;
SELECT count(*) FILTER (WHERE solde<>trunc(solde)) AS comptes_fractionnaires,
 count(*) FILTER (WHERE solde<0) AS comptes_negatifs FROM public.comptes_bancaires WHERE banque='nationale';
ROLLBACK;
