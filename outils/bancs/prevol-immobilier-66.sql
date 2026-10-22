-- Lecture seule : aucun acteur, aucune signature, aucun mouvement financier.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT version,name FROM supabase_migrations.schema_migrations WHERE name ILIKE '%immobil%' OR name ILIKE '%terrain%' OR name ILIKE '%fonds%' OR name ILIKE '%cession%' OR name ILIKE '%construction%' ORDER BY version;
SELECT p.oid::regprocedure AS signature,p.prosecdef,p.provolatile,p.proconfig,md5(p.prosrc),pg_get_functiondef(p.oid),
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated,has_function_privilege('anon',p.oid,'EXECUTE') AS anon
 FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND
 (p.proname LIKE 'immobilier_%' OR p.proname IN('entreprise_acte_rachat','entreprise_signer_compromis','entreprise_prix_rachat','vendre_fonds_commerce','imprimerie_cession_finaliser','mouvement_titulaire','helvetia_debiter_fonds_ordinaires','helvetia_crediter_destination','payer_ordre','recette_municipale','mail_systeme_poser_interne','bail_destination_attestee','prelever_loyer_bail','est_appel_serveur','acteur_poste_courant','succession_regler')) ORDER BY 1;
SELECT c.relname,a.attname,format_type(a.atttypid,a.atttypmod) FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
 WHERE c.relnamespace='public'::regnamespace AND c.relname IN('terrains_etat','entreprises','locations_actives','comptes_bancaires','prets','personnages_donnees','recettes_municipales') AND a.attnum>0 AND NOT a.attisdropped ORDER BY c.relname,a.attnum;
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
 WHERE c.relnamespace='public'::regnamespace AND c.relname IN('terrains_etat','entreprises','locations_actives','personnages_donnees','mails') AND NOT t.tgisinternal;
SELECT conrelid::regclass,conname,pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid IN('public.recettes_municipales'::regclass,'public.terrains_etat'::regclass,'public.entreprises'::regclass);
SELECT tablename,policyname,roles,cmd,qual,with_check FROM pg_policies WHERE schemaname='public' AND tablename IN('terrains_etat','entreprises','locations_actives','prets','personnages_donnees');
SELECT fn,pa,cost FROM public.ordres_couts WHERE fn IN('officialiser_transaction','deposer_demande_permis');
SELECT count(*) FILTER(WHERE liquide::numeric<>trunc(liquide::numeric)) AS liquides_non_entiers,count(*) FILTER(WHERE arg::numeric<>trunc(arg::numeric)) AS fortunes_non_entieres FROM public.personnages_donnees;
SELECT count(*) FILTER(WHERE solde<>trunc(solde)) AS comptes_fractionnaires FROM public.comptes_bancaires;
SELECT extname,extversion FROM pg_extension WHERE extname IN('pg_cron','pg_net');
-- Ne jamais exporter les commandes de jobs brutes : elles pourraient contenir des secrets.
ROLLBACK;
