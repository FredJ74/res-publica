-- Lecture seule, reservee au canal technique autorise. Aucun personnage temoin en production.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) signature,
 md5(p.prosrc) empreinte,p.prosecdef,p.proconfig,pg_get_userbyid(p.proowner) proprietaire,
 has_function_privilege('anon',p.oid,'EXECUTE') anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') authenticated_execute,
 pg_get_functiondef(p.oid) definition
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN
 ('mon_personnage','exiger_acteur','employer_fonds','commerce_production_autorisee','commerce_produire','fonds_reference_produire_lots',
 'commerce_vendre_produit','commerce_vendre_produit_interne','tournee_cloturer',
 'tournee_contrat_lire','tournee_creer','tournee_repondre','tournee_cloturer_boire',
 'helvetia_debiter_fonds_ordinaires','appliquer_taxe_transaction','caisse_institution_mouvement')
ORDER BY p.proname,signature;
SELECT c.relname,c.relrowsecurity,t.tgname,pg_get_triggerdef(t.oid) definition
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace LEFT JOIN pg_trigger t ON t.tgrelid=c.oid AND NOT t.tgisinternal
WHERE n.nspname='public' AND c.relname IN('tournees','invitations_diner','entreprises','personnages_donnees');
SELECT tablename,policyname,roles,cmd,qual,with_check FROM pg_policies
WHERE schemaname='public' AND tablename IN('tournees','invitations_diner','entreprises','personnages_donnees');
SELECT table_name,column_name,data_type,is_nullable,column_default FROM information_schema.columns
WHERE table_schema='public' AND table_name IN('tournees','invitations_diner','personnages_donnees')
ORDER BY table_name,ordinal_position;
SELECT c.relname,con.conname,pg_get_constraintdef(con.oid) definition FROM pg_constraint con
JOIN pg_class c ON c.oid=con.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN('tournees','invitations_diner');
SELECT statut,count(*) FROM public.tournees GROUP BY statut ORDER BY statut;
SELECT cle,valeur FROM public.entreprises_constantes WHERE cle='pa_tournee';
-- Inventaire des dependances directes ; les appels PL/pgSQL exigent egalement la lecture des corps ci-dessus.
SELECT p.proname,pg_describe_object(d.classid,d.objid,d.objsubid) dependant,d.deptype
FROM pg_proc p JOIN pg_depend d ON d.refclassid='pg_proc'::regclass AND d.refobjid=p.oid
WHERE p.pronamespace='public'::regnamespace AND p.proname IN('commerce_vendre_produit','tournee_cloturer','commerce_produire','fonds_reference_produire_lots');
ROLLBACK;
