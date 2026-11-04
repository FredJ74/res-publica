-- Collecte technique, lecture seule. Aucun compte, solde individuel ou inventaire exporté.
-- À exécuter via le canal Supabase autorisé par l'intégrateur, pas par le game designer.
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT version(), now() AS capture;
SELECT count(*) AS migrations,max(version) AS derniere_version FROM supabase_migrations.schema_migrations;
SELECT version,name FROM supabase_migrations.schema_migrations
 WHERE name ILIKE '%chantier_naval%' ORDER BY version;
SELECT table_name,column_name,data_type,is_nullable,column_default FROM information_schema.columns
 WHERE table_schema='public' AND table_name IN('chantier_naval_modeles','chantier_naval_commandes','chantier_naval_bateaux','personnages_donnees','comptes_bancaires')
 AND (table_name LIKE 'chantier_naval_%' OR column_name IN('user_id','inventory','inventory_revision','pa','liquide','arg','solde','banque','personnage'))
 ORDER BY table_name,ordinal_position;
SELECT c.relname,c.relrowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname IN('chantier_naval_modeles','chantier_naval_commandes','chantier_naval_bateaux');
SELECT tablename,policyname,roles,cmd,qual,with_check FROM pg_policies WHERE schemaname='public' AND tablename LIKE 'chantier_naval_%';
SELECT p.oid::regprocedure AS signature,md5(pg_get_functiondef(p.oid)) AS empreinte_definition,
 pg_get_functiondef(p.oid) AS definition,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anonyme,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authentifie,
 has_function_privilege('service_role',p.oid,'EXECUTE') AS serveur
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prokind='f' AND (p.proname LIKE 'chantier_naval_%' OR p.proname IN
 ('helvetia_debiter_fonds_ordinaires','caisse_institution_mouvement','entrepot_caisse_id','entrepot_caisse_mouvement','inventaire_reception_etat','entrepot_livrer_transits','est_appel_serveur'))
 ORDER BY p.oid::regprocedure::text;
SELECT tgrelid::regclass AS table_source,tgname,pg_get_triggerdef(oid) FROM pg_trigger
 WHERE NOT tgisinternal AND tgrelid IN('public.personnages_donnees'::regclass,'public.caisses_batiments'::regclass,'public.batiments_etat'::regclass);
SELECT * FROM public.chantier_naval_modeles ORDER BY code;
SELECT cle,prix_base,plafond,source FROM public.ressources_economie WHERE cle IN('bois','metal','derives_petrochimiques');
SELECT public.entrepot_caisse_id('republic_ville_a_entrepot-logistique-psm') AS caisse_entrepot;
-- Agrégats de cohérence seulement : ni identité ni détail de patrimoine joueur.
SELECT count(*) AS commandes,
 count(*) FILTER(WHERE somme_versee>prix_total OR depense_matieres>somme_versee OR jours_faits>jours_total) AS incoherences,
 count(*) FILTER(WHERE etat='acheve' AND NOT EXISTS(SELECT 1 FROM public.chantier_naval_bateaux b WHERE b.commande_id=c.id)) AS livraisons_manquantes
 FROM public.chantier_naval_commandes c;
SELECT count(*) AS bateaux,
 count(*) FILTER(WHERE b.proprietaire_user_id IS DISTINCT FROM c.proprietaire_user_id OR b.modele IS DISTINCT FROM c.modele OR b.navigation_active OR b.etat<>'au_port') AS incoherences
 FROM public.chantier_naval_bateaux b JOIN public.chantier_naval_commandes c ON c.id=b.commande_id;
ROLLBACK;
