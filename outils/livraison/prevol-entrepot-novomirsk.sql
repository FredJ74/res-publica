-- Lecture seule, à exécuter par l'intégrateur technique avant toute application.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT version(), current_database();
SELECT count(*) AS migrations, max(version) AS derniere_version FROM supabase_migrations.schema_migrations;
SELECT version,name FROM supabase_migrations.schema_migrations
 WHERE name ILIKE '%trading%' OR name ILIKE '%entrepot%' ORDER BY version;
SELECT column_name,data_type,is_nullable,column_default FROM information_schema.columns
 WHERE table_schema='public' AND table_name='entrepots_par_ville' ORDER BY ordinal_position;
SELECT conname,pg_get_constraintdef(oid) FROM pg_constraint
 WHERE conrelid='public.entrepots_par_ville'::regclass OR confrelid='public.entrepots_par_ville'::regclass;
SELECT * FROM public.entrepots_par_ville ORDER BY ville,building_id;
-- Seulement définitions publiques : aucun compte ni donnée de joueur.
SELECT p.oid::regprocedure AS signature,pg_get_functiondef(p.oid) AS definition,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authentifie,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anonyme
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f'
 AND (p.prosrc LIKE '%entrepots_par_ville%' OR p.proname IN
 ('entrepot_commander','acheter_a_entrepot','offre_achat_servir','entrepot_caisse_id','caisse_refus_autorite','poste_autorite_de'))
 ORDER BY p.oid::regprocedure::text;
SELECT tablename,policyname,roles,cmd,qual,with_check FROM pg_policies
 WHERE schemaname='public' AND tablename IN ('entrepots_par_ville','entrepot_journal','entrepot_transits','offres_achat');
SELECT * FROM public.villes WHERE pays='soviet' AND ville='capitale';
SELECT country,city,noeud,building FROM public.rue_sorties_batiments WHERE country='soviet' AND noeud='novomirsk-vue-8';
SELECT motif,est_prefixe,postes_debit FROM public.caisses_autorites WHERE motif LIKE 'entrepot%';
ROLLBACK;
