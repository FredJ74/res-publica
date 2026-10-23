-- LECTURE SEULE. Executer par le connecteur autorise avant tout lot, pas de donnees joueur.
BEGIN TRANSACTION READ ONLY;
SELECT version,name FROM supabase_migrations.schema_migrations WHERE version IN
 ('20261020214955','20261020222029','20261022123320','20261022124056','20261022130417','20261022143001') ORDER BY version;
WITH attendu(signature,empreinte_observee) AS (VALUES
 ('public.payer_ordre(text,text,integer,integer)','92234a6b14ff176d2c2c2236f705683e'),
 ('public.terrain_permis_acte(text,text,jsonb)','bb14432f6064d189cdf9b3b85637f844'),
 ('public.chantier_lancer(text,text,text,text,integer)','f7e9fbfc8c0b0e722659f7c870354159'),
 ('public.chantier_verser(text,text,text,integer)','3675b46e3e997575a173766f0e02c6f4'),
 ('public.chantier_travailler(text,text,text,integer)','f20ec50e8dddd7586eb67ff7fb13c6ca'),
 ('public.vendre_materiaux_chantier(text,text,text,text,integer,integer)','454957349e1b59a60f4313b9f60eebe8'),
 ('public.terrain_lots_acte(text,text,jsonb,text[])','9d648dfb4f5248faf18b4373083ba57f'),
 ('public.terrain_reamenagement_poser(text,jsonb)','a8a85325e5e42892733af3c1d0d97124'),
 ('public.pret_national_contracter(numeric,integer,text,text)','8a08c4561a32f8eafb3c03429fa63b38'))
SELECT a.*,p.oid::regprocedure AS signature_reelle,md5(p.prosrc) AS empreinte_reelle,
 p.prosecdef,p.proconfig,p.proacl,pg_get_functiondef(p.oid) AS definition_reelle
FROM attendu a LEFT JOIN pg_proc p ON p.oid=to_regprocedure(a.signature);
-- Definitions communes supplementaires : absence ou variation => examen, jamais substitution aveugle.
SELECT p.oid::regprocedure,md5(p.prosrc),p.prosecdef,p.proconfig,p.proacl,pg_get_functiondef(p.oid)
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN
 ('terrain_etat_verrouiller_interne','terrain_etat_fusionner_interne','chantier_commande','chantier_jour_traiter',
 'chantier_plan_enregistrer_interne','chantier_autorite_exiger_interne','chantier_financeur_verrouiller_interne',
 'objet_sas_deposer','recherche_inscrire','combat_coup_resoudre','prelever_loyer_bail','bail_cle_coherente',
 'helvetia_debiter_fonds_ordinaires','mail_systeme_poser_interne','detention_active','acteur_poste_courant');
SELECT c.relname,c.relrowsecurity,c.relforcerowsecurity,c.relacl
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'
AND c.relname IN('terrains_etat','dossiers_urbanisme','objets_recus','locations_actives','personnages_donnees',
 'comptes_bancaires','organisations','caisses_batiments','chantier_commandes_recus');
SELECT tablename,policyname,roles,cmd,qual,with_check FROM pg_policies WHERE schemaname='public'
AND tablename IN('terrains_etat','dossiers_urbanisme','objets_recus','locations_actives','personnages_donnees','comptes_bancaires');
SELECT t.tgrelid::regclass,pg_get_triggerdef(t.oid) FROM pg_trigger t WHERE NOT t.tgisinternal AND t.tgrelid IN
 (to_regclass('public.terrains_etat'),to_regclass('public.dossiers_urbanisme'),to_regclass('public.objets_recus'),
 to_regclass('public.locations_actives'),to_regclass('public.personnages_donnees'));
ROLLBACK;
