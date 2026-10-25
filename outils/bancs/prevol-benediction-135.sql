-- Lecture seule, par l’agent principal. Aucun acte, aucune donnée de personnage exportée.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT p.oid::regprocedure::text AS signature,md5(p.prosrc) AS empreinte,p.proconfig,p.proacl,p.prosecdef,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS client_execute,pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN
 ('religion_benediction_lire','religion_benediction_demander','religion_benediction_consommer_interne',
 'pnj_position_effective','pnj_co_present','terrain_negociation_jet_interne','payer_ordre','mon_personnage',
 'chantier_vol_commande','inventaire_reception_etat','inventaire_reclamer_livraison','inventaire_revision_garder','indice_ville_ajuster_interne','acteur_poste_courant','filature_deplacements','police_filature_commande','personnage_stat_jet_interne','personnage_securite_jet_interne','commissaire_enqueter','plainte_instruire_interne','detention_clore_evasion',
 'detention_clore_interne','recherche_inscrire','terrain_chantier_acte','caisse_institution_mouvement',
 'caisse_client_mouvement','helvetia_debiter_fonds_ordinaires','helvetia_crediter_destination') ORDER BY 1;
SELECT c.relname,a.attname,format_type(a.atttypid,a.atttypmod),a.attnotnull FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid
WHERE n.nspname='public' AND c.relname IN('religion_benedictions','religion_benedictions_recus','religion_benedictions_consommations',
 'personnages_donnees','pnj_membres','pnj_employes_metier','vols_en_attente','caisses_batiments','postes_attribues','historique_deplacements','indices_villes','caisses_mouvements_clients','police_filatures_recus','ordres_jets_sites','chantier_vols_recus','inventaire_livraisons_recues','objets_recus','actions_tracables','terrains_etat') AND a.attnum>0 AND NOT a.attisdropped ORDER BY 1,a.attnum;
SELECT m.id,m.nom,m.famille,m.statut,m.pays,m.ville,m.building_id,m.room_id,m.leader_pj IS NOT NULL AS suit_un_pj
FROM public.pnj_membres m WHERE m.nom IN('Père Ception','Enfant de chœur Lacroix','Père Iscope','Abbé Tonnière');
SELECT schemaname,tablename,policyname,roles,cmd,qual,with_check FROM pg_policies WHERE schemaname='public'
AND tablename IN('religion_benedictions','religion_benedictions_recus','religion_benedictions_consommations','vols_en_attente','personnages_donnees');
ROLLBACK;
