-- #57 / #69 — PREVOL REEL OBLIGATOIRE. LECTURE SEULE.
-- A executer avec l'acces administratif autorise, jamais une cle dans le navigateur.
-- Aucun appel metier, aucune ecriture, aucun nom/UID/inventaire ou solde individuel exporte.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT version,name FROM supabase_migrations.schema_migrations
 WHERE name ILIKE ANY(ARRAY['%chantier%','%construction%','%coffre%','%inventaire%','%reception%','%succession%','%loyer%','%organisation%']) ORDER BY version;

-- Examiner definitions, proprietaires, search_path, signatures et droits AVANT d'accepter les gardes.
SELECT p.oid::regprocedure AS signature,pg_get_userbyid(p.proowner) AS proprietaire,
 p.prosecdef,p.provolatile,p.proconfig,md5(p.prosrc) AS empreinte,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated,
 has_function_privilege('service_role',p.oid,'EXECUTE') AS service_role,
 pg_get_functiondef(p.oid) AS definition
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND (p.proname LIKE 'chantier_%' OR p.proname LIKE 'coffre_%' OR p.proname='coffres_suppression_garder'
 OR p.proname IN ('approvisionner_chantier','entrepot_caisse_id','caisse_institution_mouvement','vendre_materiaux_chantier',
 'terrain_permis_acte','terrain_lots_acte','terrain_reamenagement_poser','terrain_etat_fusionner_interne','restituer_reliquats_chantier',
 'helvetia_debiter_fonds_ordinaires','helvetia_inventaire_sortie','inventaire_localiser','inventaire_retirer',
 'inventaire_revision_garder','inventaire_reception_etat','inventaire_occupation_unites','inventaire_place_restante',
 'payer_ordre','acteur_identifie','prelever_loyer_bail','terminer_bail','resilier_bail_volontaire','bail_cle_coherente','bail_autorite_de','bail_destination_attestee',
 'succession_regler','personnages_vue_supprimer','organisation_equipement_exiger','poste_est_atteste','detention_active','objet_sas_deposer')) ORDER BY 1;
SELECT p.oid::regprocedure AS fonction,pg_describe_object(d.refclassid,d.refobjid,d.refobjsubid) AS dependance
 FROM pg_depend d JOIN pg_proc p ON d.classid='pg_proc'::regclass AND d.objid=p.oid
 WHERE p.pronamespace='public'::regnamespace AND
 (p.proname LIKE 'chantier_%' OR p.proname LIKE 'coffre_%' OR p.proname IN ('helvetia_inventaire_sortie','terminer_bail','succession_regler')) ORDER BY 1,2;
-- Les appels SQL dynamiques ne sont PAS tous representes par pg_depend : relire les definitions.
SELECT c.relname,c.relrowsecurity,c.relforcerowsecurity,a.attname,format_type(a.atttypid,a.atttypmod) AS type
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid
 WHERE n.nspname='public' AND c.relname IN ('personnages_donnees','terrains_etat','organisations','comptes_bancaires',
 'caisses_batiments','batiments_etat','locations_actives','locations_archives','successions','testaments',
 'chantier_commandes_recus','coffres_bancaires','coffres_requetes') AND a.attnum>0 AND NOT a.attisdropped ORDER BY 1,a.attnum;
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid) AS definition FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
 JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN
 ('personnages_donnees','terrains_etat','organisations','locations_actives','coffres_bancaires') AND NOT t.tgisinternal ORDER BY 1,2;
SELECT tablename,policyname,roles,cmd,qual,with_check FROM pg_policies WHERE schemaname='public'
 AND tablename IN ('personnages_donnees','terrains_etat','organisations','caisses_batiments','locations_actives',
 'locations_archives','successions','testaments','coffres_couts_autorises','chantier_commandes_recus','coffres_bancaires','coffres_requetes') ORDER BY 1,2;
SELECT table_name,grantee,privilege_type FROM information_schema.role_table_grants WHERE table_schema='public'
 AND table_name IN ('personnages','personnages_donnees','terrains_etat','organisations','locations_actives',
 'chantier_commandes_recus','coffres_bancaires','coffres_requetes') ORDER BY 1,2,3;

-- Agregats historiques seulement. Un ecart bloque, il n'autorise aucune reparation automatique.
SELECT count(*) AS titres,
 count(*) FILTER(WHERE proprietaire IS DISTINCT FROM data::jsonb->>'proprietaire') AS proprietaires_desaccord,
 count(*) FILTER(WHERE building_id LIKE 'terrain-a-batir%' AND nullif(data::jsonb->>'surface','') IS NULL) AS terrains_surface_absente,
 count(*) FILTER(WHERE jsonb_typeof(data::jsonb->'chantier')='object') AS chantiers,
 count(*) FILTER(WHERE jsonb_typeof(data::jsonb->'chantierReamenagement')='object') AS reamenagements,
 count(*) FILTER(WHERE data::jsonb->>'proprietaire' LIKE 'orga:%') AS proprietes_organisations,
 count(*) FILTER(WHERE data::jsonb->>'proprietaire' LIKE 'ville:%') AS proprietes_communales
 FROM public.terrains_etat;
SELECT count(*) AS contrats_coffres_historiques,
 count(*) FILTER(WHERE data->>'prix'='600') AS anciens_600,
 count(*) FILTER(WHERE nullif(data->>'orgaId','') IS NOT NULL) AS anciens_organisations,
 count(*) FILTER(WHERE data->>'periodicite'='annuelle') AS declares_annuels
 FROM public.locations_actives WHERE country='republic' AND data->>'city'='capitale'
 AND data->>'buildingId'='banque-nationale' AND data->>'roomId'='coffre_privatif';
SELECT count(*) FILTER(WHERE liquide<>trunc(liquide) OR arg<>trunc(arg)) AS personnages_fractionnaires,
 count(*) FILTER(WHERE liquide<0) AS liquides_negatifs,
 count(*) FILTER(WHERE inventory IS NOT NULL AND jsonb_typeof(inventory)<>'array') AS inventaires_non_tableaux
 FROM public.personnages_donnees;
SELECT count(*) FILTER(WHERE solde<>trunc(solde)) AS comptes_fractionnaires,
 count(*) FILTER(WHERE solde<0) AS comptes_negatifs FROM public.comptes_bancaires WHERE banque='nationale';
ROLLBACK;
