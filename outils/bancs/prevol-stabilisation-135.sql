-- Lecture seule, a executer par l'agent via le connecteur autorise avant toute installation.
-- Aucun appel a un acte metier ni export de personnage.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT version,name FROM supabase_migrations.schema_migrations
WHERE name ~ '(terrain|chantier|construction|squatteur|organisation|equipement|pret|loyer)' ORDER BY version;
SELECT p.oid::regprocedure::text AS signature,md5(p.prosrc) AS empreinte,p.prosecdef,p.proconfig,p.proacl,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS client_execute,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anonyme_execute,pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN
 ('organisation_commande_administrative','organisation_commande_membres','organisation_commande_evenement',
 'organisation_equipements_etat','organisation_equipement_deplacer','organisation_equipements_payeurs','organisation_equipement_acheter',
 'terrain_lots_acte','terrain_reamenagement_poser','chantier_commande','chantier_commande_recu','chantier_jour_traiter',
 'chantier_besoin_jour_interne','chantier_autorite_exiger_interne','chantier_plan_valider_interne','payer_ordre',
 'terrain_occupation_lire','terrain_negociation_preparer','terrain_negociation_conclure',
 'terrain_occupation_action','terrain_occupation_action_preparer','terrain_police_echeances_traiter',
 'pret_national_contracter','terrain_compromis_acte','terrain_proprietaire_muter','compromis_expire_resoudre',
 'helvetia_debiter_fonds_ordinaires','prelever_loyer_bail','recherche_inscrire','detention_active',
 'fermeture_definir_date_universelle','permis_depot_archive_proteger','acteur_est_moi') ORDER BY 1;
SELECT c.relname,c.relrowsecurity,c.relforcerowsecurity,c.relacl,a.attname,format_type(a.atttypid,a.atttypmod),a.attnotnull
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid
WHERE n.nspname='public' AND c.relname IN('personnages_donnees','terrains_etat','locations_actives','comptes_bancaires',
 'organisations','pnj_membres','pnj_employes_metier','objets_recus','entreprises','prets','terrain_actions_recus','terrain_actions_regles')
 AND a.attnum>0 AND NOT a.attisdropped ORDER BY c.relname,a.attnum;
SELECT schemaname,tablename,policyname,roles,cmd,qual,with_check FROM pg_policies WHERE schemaname='public'
 AND tablename IN('personnages_donnees','terrains_etat','locations_actives','comptes_bancaires','organisations','objets_recus','prets','terrain_actions_recus','terrain_actions_regles');
SELECT t.tgrelid::regclass,t.tgname,pg_get_triggerdef(t.oid) FROM pg_trigger t WHERE NOT t.tgisinternal
 AND t.tgrelid IN(to_regclass('public.personnages_donnees'),to_regclass('public.terrains_etat'),to_regclass('public.locations_actives'),to_regclass('public.organisations'));
ROLLBACK;
