-- Prévol de lecture seule. Ne prouve aucune application ni aucune recette en jeu.
BEGIN;
SET TRANSACTION READ ONLY;
WITH noms(nom) AS (VALUES
 ('pnj_position_effective'),('pnj_prendre'),('pnj_quitter_groupe'),
 ('pnj_pas_de_sous_hierarchie'),('pnj_axe_position_refus'),
 ('pnj_mouvement_individuel_refus'),('pnj_peut_conduire'),
 ('militaire_deposer_soldats'),('militaire_recuperer_soldats'),
 ('militaire_affecter_leader'),('militaire_bataille_groupes_constituer'),
 ('police_detection_verifier'),('police_fuite_resoudre'),
 ('police_combat_resoudre'),('police_reddition_resoudre'),
 ('police_reprise_lire'),('police_action_resultat_lire'),
 ('combat_coup_resoudre'),('justice_executer_condamnation_soi'),
 ('justice_recherches'),('recherche_inscrire'),
 ('rue_position_enregistrer'),('rue_position_lire'),
 ('securite_agents_prives_presents_interne'),('securite_ordre_detection_interne'),
 ('pnj_deployer_unite'))
SELECT noms.nom,p.oid IS NULL AS absente,p.oid::regprocedure::text AS signature,p.prosecdef,p.provolatile,p.proconfig,
 p.proacl,md5(pg_get_functiondef(p.oid)) AS empreinte,
 pg_get_functiondef(p.oid) AS definition,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
 has_function_privilege('service_role',p.oid,'EXECUTE') AS service_execute
FROM noms LEFT JOIN pg_proc p ON p.proname=noms.nom
 AND p.pronamespace=to_regnamespace('public')
ORDER BY signature;
SELECT c.relname,c.relrowsecurity,c.relacl,a.attname,
 format_type(a.atttypid,a.atttypmod) AS type
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
JOIN pg_attribute a ON a.attrelid=c.oid
WHERE n.nspname='public' AND c.relname IN
 ('pnj_membres','pnj_employes_metier','pnj_force_publique_metier',
 'police_interceptions','police_detection_attempts','police_action_receipts','batiments_etat',
 'batailles_engagements','batailles_groupes')
 AND a.attnum>0 AND NOT a.attisdropped ORDER BY c.relname,a.attnum;
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid)
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN
 ('pnj_membres','pnj_employes_metier','police_interceptions','batiments_etat','personnages_donnees')
 AND NOT t.tgisinternal ORDER BY c.relname,t.tgname;
SELECT conname,pg_get_constraintdef(oid) FROM pg_constraint
WHERE conrelid IN ('public.pnj_membres'::regclass,'public.police_interceptions'::regclass)
ORDER BY conrelid,conname;
SELECT to_regclass('public.chantier_vigiles_affectations') AS table_specifique_196;
SELECT tablename,policyname,roles,cmd,qual,with_check FROM pg_policies
WHERE schemaname='public' AND tablename IN
 ('pnj_membres','pnj_employes_metier','pnj_force_publique_metier',
 'police_interceptions','police_detection_attempts','police_action_receipts','batiments_etat')
ORDER BY tablename,policyname;
SELECT version,name FROM supabase_migrations.schema_migrations
WHERE version IN ('20261031115734','20261031115735','20261031115736')
 OR name ILIKE '%securite_privee%' ORDER BY version;
-- Règles publiques et agrégats seulement : aucun nom de joueur ni contenu de fiche.
SELECT famille,axe,autorite FROM public.pnj_axes_autorite
WHERE famille IN ('employe','policier','soldat') ORDER BY famille,axe;
SELECT famille,autorise,raison FROM public.pnj_mouvement_individuel
WHERE famille IN ('employe','policier','soldat') ORDER BY famille;
SELECT famille,count(*) AS effectif,
 count(*) FILTER(WHERE leader_pj IS NOT NULL) AS suivent_pj,
 count(*) FILTER(WHERE leader_pnj_id IS NOT NULL) AS suivent_pnj
FROM public.pnj_membres GROUP BY famille ORDER BY famille;
ROLLBACK;
