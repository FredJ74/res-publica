-- LECTURE SEULE, NON EXECUTE ICI. Projet attendu : jxpwoosmmhohoihxpbuc.
-- N'applique rien, ne cree aucun PJ/objet, ne lit aucun mot de passe/secret.
BEGIN TRANSACTION READ ONLY;
SELECT version();
SELECT version,name FROM supabase_migrations.schema_migrations
 WHERE version>='20261027000000' ORDER BY version;
SELECT p.oid::regprocedure AS signature,p.prosecdef,p.proconfig,p.proacl,pg_get_functiondef(p.oid) AS definition
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN('inventaire_deposer_interne','inventaire_sauver_revision','inventaire_revision_garder',
 'objet_acheter','arme_acheter','recolte_effectuer','tracts_imprimer','objet_sas_deposer','pnj_objet_transferer','pnj_possessions_lire',
 'payer_ordre','helvetia_debiter_fonds_ordinaires','caisse_institution_mouvement','fret_dedouaner','mon_personnage','est_appel_serveur') ORDER BY 1;
SELECT c.relname,c.relrowsecurity,c.relacl,pg_get_userbyid(c.relowner) AS proprietaire
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'
 AND c.relname IN('objets_modeles','objets_achetables','objets_recus','pnj_possessions','pnj_membres','caisses_fret','contenu_caisses_fret',
 'budgets_clubs','clubs_sportifs_regles','quetes_actives','souvenirs_accueil','dossiers_urbanisme');
SELECT schemaname,tablename,policyname,roles,cmd,qual,with_check FROM pg_policies
 WHERE schemaname='public' AND tablename IN('personnages_donnees','objets_modeles','objets_achetables','pnj_possessions','pnj_membres',
 'caisses_fret','contenu_caisses_fret','budgets_clubs','clubs_sportifs_regles','quetes_actives','souvenirs_accueil','dossiers_urbanisme');
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
 WHERE NOT t.tgisinternal AND c.relnamespace='public'::regnamespace AND c.relname IN('personnages_donnees','personnages','pnj_possessions',
 'caisses_fret','contenu_caisses_fret','budgets_clubs','objets_recus','dossiers_urbanisme');
SELECT table_name,column_name,data_type FROM information_schema.columns WHERE table_schema='public'
 AND table_name IN('personnages_donnees','pnj_possessions','pnj_membres','caisses_fret','contenu_caisses_fret','budgets_clubs','dossiers_urbanisme')
 ORDER BY table_name,ordinal_position;
-- Agregats uniquement : ni noms, ni UID, ni contenus d'inventaire dans le rapport.
SELECT count(*) AS employes_avec_charge_historique,
 count(*) FILTER(WHERE nullif(e->>'pnjId','') IS NULL) AS sans_identifiant_pnj
 FROM public.personnages_donnees d CROSS JOIN LATERAL jsonb_array_elements(
 CASE WHEN jsonb_typeof(d.employes)='array' THEN d.employes ELSE '[]'::jsonb END) e
 WHERE coalesce(e->'charge','{}'::jsonb)<>'{}'::jsonb OR coalesce(e->'chargeUnique','[]'::jsonb)<>'[]'::jsonb;
SELECT count(*) AS inventaires_non_tableaux FROM public.personnages_donnees
 WHERE inventory IS NOT NULL AND jsonb_typeof(inventory)<>'array';
SELECT count(*) AS lignes_fret_quantite_invalide FROM public.contenu_caisses_fret WHERE quantite<0;
SELECT count(*) AS piles_identiques_historiques FROM (
 SELECT d.id,i->>'stackKey' FROM public.personnages_donnees d CROSS JOIN LATERAL jsonb_array_elements(
 CASE WHEN jsonb_typeof(d.inventory)='array' THEN d.inventory ELSE '[]'::jsonb END) i
 WHERE i->>'stackable'='true' AND nullif(i->>'stackKey','') IS NOT NULL GROUP BY d.id,i->>'stackKey' HAVING count(*)>1
) s;
-- Ces controles ne remplacent PAS les bancs : appels metier a faire sur fixtures en transaction
-- annulee, au role authenticated, avec request.path '/rpc/<fonction>' et UID de test autorise.
SELECT has_function_privilege('authenticated','public.inventaire_deposer_interne(text,jsonb,boolean)','EXECUTE') AS depot_expose,
 has_table_privilege('authenticated','public.objets_modeles','INSERT,UPDATE,DELETE') AS catalogue_modifiable,
 has_table_privilege('authenticated','public.pnj_possessions','INSERT,UPDATE,DELETE') AS possessions_modifiables;
ROLLBACK;
