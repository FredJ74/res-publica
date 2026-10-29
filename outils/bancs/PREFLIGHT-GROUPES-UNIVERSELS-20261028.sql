-- #219 : le MD5 annoncé 5e819694359c4bf2f11470c7f9f95ad8 est une information
-- documentaire, pas une autorisation DDL. Le corps Git correspondant est archivé
-- dans fixtures/groupes-corps-git-20261028.json ; comparer encore au catalogue.
-- Lecture seule préparée, NON EXÉCUTÉE sur Supabase dans la session Codex.
-- Complète PREFLIGHT-AUDIT-SECURITE-135.sql avant tout DDL d'adhésion PJ.
BEGIN;
SET TRANSACTION READ ONLY;
-- Retrouver toute relation existante, y compris JSON et colonnes hors schéma public.
-- Métadonnées seulement, aucun personnage ni inventaire de joueur exporté.
SELECT n.nspname,c.relname,a.attname,format_type(a.atttypid,a.atttypmod) AS type
FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE a.attnum>0 AND NOT a.attisdropped AND c.relkind IN ('r','p','v','m')
 AND n.nspname NOT IN ('pg_catalog','information_schema')
 AND (a.attname ~* '(groupe|group|leader|chef)' OR c.relname ~* '(groupe|group|adhesion)')
ORDER BY 1,2,3;
-- Tous les lecteurs/écrivains candidats : ne pas prendre une empreinte pour un corps.
SELECT n.nspname,p.proname,p.oid::regprocedure::text AS signature,
 md5(pg_get_functiondef(p.oid)) AS empreinte,md5(p.prosrc) AS empreinte_corps,
 pg_get_functiondef(p.oid) AS definition,
 p.proowner::regrole AS proprietaire,p.proacl,p.prosecdef,p.provolatile,p.proconfig
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind IN ('f','p') AND
 (p.proname ~* '^(pnj_|groupe_|navigation_|transport_|douane_|rue_position_|militaire_bataille_|police_)'
  OR p.proname IN ('deplacement_enregistrer','personnages_vue_modifier','mon_personnage','est_appel_serveur',
   'militaire_camps_hostiles','militaire_taux_combat','militaire_degre_combat','militaire_pa_restants','militaire_gilet_absorber','militaire_soldat_supprimer','militaire_soldat_pa_fixer','militaire_passe_jour','militaire_blob_projeter','militaire_section_de_moi','militaire_autorite_de_perimetre',
   'force_publique_effectif_acte','effectifs_ecriture_metier_garder','compagnie_ecriture_metier_garder','batiment_etat_sous_cle_ecrire',
   'militaire_deposer_soldats','militaire_recuperer_soldats','militaire_affecter_leader','militaire_ordre_collectif',
   'payer_ordre','payer_ordre_interne','ambassade_acces_bureau','ambassade_acces_bureau_interne','terrain_etat_lire',
   'crime_neutraliser','inventaire_confisquer','justice_recherches','justice_executer_condamnation_soi',
   'inventaire_reception_etat','inventaire_sauver_revision','inventaire_objet_protege','assemblee_loi_en_vigueur','detention_ouvrir_interne','detention_ouvrir_soi','detention_transferer_qhs','detention_qhs_poser_interne',
   'terrain_squatteurs_issue_interne','terrain_squatteurs_issue_bataille_interne','combat_gilet_pnj_absorber_interne','combat_membre_decrire_interne','crime_corrompre_douanier','crime_detecter_interne','crime_malus_isn_interne','crime_etat_acteur_interne')
  OR p.prosrc ~* '(leader_pj|leader_pnj_id|groupes_pj_adhesions|current_street|current_building)')
ORDER BY p.proname,p.oid;
-- Les triggers sur les positions et les deux projections police/soldats sont indispensables.
SELECT n.nspname,c.relname,t.tgname,pg_get_triggerdef(t.oid) AS definition,
 pg_get_functiondef(t.tgfoid) AS fonction
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE NOT t.tgisinternal AND n.nspname='public'
 AND c.relname IN ('personnages','personnages_donnees','presences','pnj_membres',
 'pnj_possessions','compagnies_militaires','batiments_etat','groupes_pj_adhesions','navigation_lieux_regles',
 'batailles','batailles_engagements','batailles_groupes','batailles_rounds','terrains_etat','comptes_bancaires','navigation_requetes','navigation_passages_douaniers','jugements','detentions','prisonniers_qhs')
ORDER BY c.relname,t.tgname;
-- Droits et RLS des magasins lus/écrits par les adaptateurs. Métadonnées seules.
SELECT c.relname,c.relrowsecurity,c.relforcerowsecurity,c.relacl,
 p.polname,p.polcmd,p.polroles,pg_get_expr(p.polqual,p.polrelid) AS lecture,
 pg_get_expr(p.polwithcheck,p.polrelid) AS ecriture
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
LEFT JOIN pg_policy p ON p.polrelid=c.oid
WHERE n.nspname='public' AND c.relname IN ('personnages_donnees','pnj_membres','pnj_possessions',
 'batailles','batailles_engagements','batailles_groupes','batailles_rounds','terrain_acquisitions_recus','postes_attribues','compagnies_militaires','batiments_etat','navigation_requetes','navigation_passages_douaniers','jugements','detentions','prisonniers_qhs','confiscations_douanieres','police_interceptions','police_detection_attempts','police_action_receipts','infractions')
ORDER BY c.relname,p.polname;
-- Le mandat ne doit pas être reconstruit depuis une position de voyage.
-- Compte agrégé, aucune identité de joueur extraite.
SELECT count(*) AS mandats_police_historiques_non_attestes
FROM public.personnages_donnees d WHERE d.poste->>'id'='commissaire'
AND NOT EXISTS(SELECT 1 FROM public.postes_attribues a WHERE a.country=coalesce(d.country,'republic')
 AND a.poste_id='commissaire' AND a.city=d.poste->>'city' AND a.titulaire=d.name)
AND NOT EXISTS(SELECT 1 FROM public.postes_attribues a WHERE a.poste_id='commissaire' AND a.titulaire=d.name);
SELECT count(*) AS mandats_douane_historiques_non_attestes
FROM public.personnages_donnees d WHERE d.poste->>'id'='chef_douanes'
AND NOT EXISTS(SELECT 1 FROM public.postes_attribues a
 WHERE a.poste_id='chef_douanes' AND a.city IS NULL AND a.titulaire=d.name);
SELECT country,city,building_id,count(*) AS etats_ambigus
FROM public.batiments_etat WHERE building_id IN ('commissariat','commissariat-local','port-sainte-marie')
GROUP BY country,city,building_id HAVING count(*)>1;
SELECT poste_id,country,city,count(*) AS mandats_ambigus
FROM public.postes_attribues WHERE poste_id IN ('commissaire','chef_douanes')
GROUP BY poste_id,country,city HAVING count(*)>1;
-- Les tarifs de recrutement doivent être uniques et inchangés : 1 PA, 0 FR.
SELECT fn,count(*) AS definitions,min(pa) AS pa_min,max(pa) AS pa_max,min(cost) AS cout_min,max(cost) AS cout_max
FROM public.ordres_couts WHERE fn IN ('recruter_policier','recruter_policier_cynophile','recruter_douanier','recruter_douanier_cynophile') GROUP BY fn ORDER BY fn;
-- Types, identités et index de la bataille ; aucun participant exporté.
SELECT a.attname,format_type(a.atttypid,a.atttypmod) AS type
FROM pg_attribute a WHERE a.attrelid IN ('public.batailles'::regclass,'public.batailles_engagements'::regclass)
AND a.attnum>0 AND NOT a.attisdropped ORDER BY a.attrelid,a.attnum;
SELECT conname,pg_get_constraintdef(oid) AS definition FROM pg_constraint
WHERE conrelid IN ('public.batailles'::regclass,'public.batailles_engagements'::regclass);
SELECT indexname,indexdef FROM pg_indexes WHERE schemaname='public' AND tablename='batailles_engagements';
-- PR233 : attendus agression 25 % / 1 jour / 500 FR ; meurtre 25 % / 2 jours / 1500 FR.
SELECT fn,type,detect_rate,peine_jours,amende FROM public.actes_illegaux WHERE fn IN ('agression','meurtre') ORDER BY fn;
-- Profils éventuellement déjà configurés : ne pas fabriquer leurs valeurs.
SELECT metier,car_vol,car_per,car_dup,pa_initial FROM public.pnj_metiers_profils
WHERE metier IN ('citoyen','squatter_cool','squatter_agr') ORDER BY metier;
SELECT version,name FROM supabase_migrations.schema_migrations
WHERE version IN ('20261027222500','20261028074753','20261028074754',
 '20261028122000','20261028122500','20261028123000','20261028123500',
 '20261028124000','20261028135642','20261028135643','20261028140626','20261028141500','20261028161732','20261028163800','20261028164500','20261028165000','20261028180000','20261028180100','20261028183000','20261028185300','20261028185301','20261028185302','20261028185303','20261028185304','20261028185305','20261028185500','20261028185600','20261028185800','20261028191900',
 '20261028193000','20261028193500','20261028194000','20261028194100','20261028213200','20261028213400',
 '20261028215000','20261028215100','20261028215200','20261028215400','20261028215500','20261028215600','20261028215800','20261028215900','20261028222000','20261029100000','20261029110000','20261029110100','20261029110200','20261029110300','20261029120000','20261029121000','20261029122000','20261029123000','20261029124000','20261029125000','20261029130000','20261029131000','20261029210000','20261029210100','20261029211000','20261029181000','20261029212000','20261029220000','20261029220100','20261029190000')
ORDER BY version;
-- Contrats supplémentaires du contrôle ordinaire et collision de main :
-- le registre 190000 doit être rapproché des deux fichiers locaux avant tout DDL.
SELECT c.relname,a.attname,format_type(a.atttypid,a.atttypmod) AS type
FROM pg_class c JOIN pg_attribute a ON a.attrelid=c.oid
WHERE c.oid IN (to_regclass('public.police_interceptions'),to_regclass('public.infractions'))
 AND a.attnum>0 AND NOT a.attisdropped ORDER BY c.relname,a.attnum;
SELECT id,jours_reference,amende_reference FROM public.infractions WHERE id='possession_illegale_douane';
ROLLBACK;
