-- REMISE À ZÉRO DU LANCEMENT (19/12/2026) — PRÉPARÉE, JAMAIS EXÉCUTÉE SANS FRED.
-- Mission du soir du 25/11/2026 (Claude), bloc 4.5. Fichier GÉNÉRÉ par outils/lancement/generer-remise-a-zero.py à partir de
-- baseline/classification-donnees.csv et outils/lancement/classement-complementaire-20261125.csv : ne pas l'éditer à la main.
-- Procédure complète, ce qui est effacé ou gardé, retour arrière : docs/premium/REMISE-A-ZERO-20261219.md.
-- Listes : garder 159 ; vider 433 ; reinitialiser 45 ; a_verifier 0
--
-- Ce que fait le script, dans UNE transaction (tout ou rien) :
--   1. garde-fous : phrase de confirmation posée dans la session, date de Paris ≥ 19/12/2026, aucune table « à vérifier »,
--      aucune table inconnue non vide ;
--   2. relève les comptes de la bêta (comptes ayant un personnage, comptes de test exclus) dans lancement_comptes_beta ;
--   3. vide les tables d'état vivant (TRUNCATE sans CASCADE ; une table référencée par une table gardée est vidée par DELETE,
--      qui applique la règle de la clé : une clé étrangère inattendue fait échouer, rien n'est effacé) ;
--   4. remet les tables mixtes à leur état initial, table par table (outils/lancement/reinitialisations.modele.sql) ;
--   5. accorde l'offre des testeurs : personnalisation d'un commerce, une annonce dans la presse, une publicité dans la rue.
-- Tous les personnages disparaissent (décision de Fred du 25/11/2026 en fin de soirée) : chacun recrée le sien.
-- Les comptes de connexion (auth.users), les accès du MJ, les achats premium payés et les référentiels sont gardés.
--
-- Pour l'exécuter (Fred décide du moment) :
--   SET human_gambit.remise_a_zero = 'JE-CONFIRME-LA-REMISE-A-ZERO-DU-19-12-2026';
--   puis ce fichier entier.
BEGIN;

-- 1. Garde-fous. ------------------------------------------------------------------------------------------------------
DO $garde$
BEGIN
  IF current_setting('human_gambit.remise_a_zero', true) IS DISTINCT FROM 'JE-CONFIRME-LA-REMISE-A-ZERO-DU-19-12-2026' THEN
    RAISE EXCEPTION 'REMISE À ZÉRO REFUSÉE : phrase de confirmation absente (voir docs/premium/REMISE-A-ZERO-20261219.md)';
  END IF;
  IF (now() AT TIME ZONE 'Europe/Paris')::date < DATE '2026-12-19' THEN
    RAISE EXCEPTION 'REMISE À ZÉRO REFUSÉE : pas avant le 19/12/2026 (heure de Paris)';
  END IF;
END $garde$;
-- fin des garde-fous

CREATE TEMP TABLE rz_listes ON COMMIT DROP AS SELECT
  ARRAY['accueil_chemins', 'accueil_etapes', 'accueil_journalistes', 'accueil_parametres', 'accueil_parametres_textes', 'actes_nocturnes_mecanismes', 'admin_actions_tribunal', 'admin_journal', 'administrateurs', 'administrateurs_invitations', 'aliments_parametres', 'armureries_dotations', 'assemblee_catalogue_illegal', 'assemblee_categories_interdiction', 'budget_national_champs_regles', 'caisses_autorites', 'camions_destinations', 'camions_militaires', 'carrieres', 'chaines_production_pays', 'chaines_production_usine', 'chantier_naval_modeles', 'chantiers_besoins_jour', 'chantiers_paliers', 'climat_boutiques', 'climat_lieux_vente', 'climat_parametres', 'climat_points_eau', 'climat_villes_exclues', 'climat_zones_inondables', 'clubs_football', 'clubs_sportifs_regles', 'commerces_dotations', 'commerces_types', 'communications_salles', 'compagnies_militaires_snapshot_20260926', 'comptes_test', 'comptes_test_parametres', 'contacts_organisations_passeurs', 'crim_boutiques', 'crim_parametres', 'directeurs_usine', 'directeurs_usine_pays', 'directions_etablissements', 'dossiers_judiciaires_actes_types', 'entreprises_constantes', 'entreprises_prix_rachat', 'escorts_agences', 'escorts_catalogue', 'fonds_credits_sources', 'frontieres_fermees', 'furets_boutiques', 'garde_republicaine_postes', 'graisses_points_vente', 'greffes_tribunaux', 'groupes_presse', 'guide_carrieres_criteres', 'guide_pistes', 'habilitations', 'habilitations_carrieres', 'habilitations_postes', 'immobilier_baremes', 'imprimeries_declarees', 'indices_villes', 'informateurs_pnj', 'infractions', 'infractions_alias', 'infractions_categories', 'infractions_empreinte', 'journaux', 'justice_avocats_commis', 'justice_faits_publics', 'kolkhoze_caisse_quotas', 'lancement_comptes_beta', 'lancement_dotations_caisses', 'lancement_dotations_commerces', 'locaux_loyers_referentiel', 'mails_expediteurs_systeme', 'maladies_parametres', 'marche_krasnov_produits', 'navigation_lieux_regles', 'objets_achetables', 'offres_emploi_bne', 'ordres_couts', 'ordres_couts_empreinte', 'ordres_couts_pays', 'ordres_generiques', 'pa_bonus_differes', 'pa_bonus_differes_empreinte', 'pa_bonus_hotel', 'pa_credits_sources', 'pharmacies_points_vente', 'pnj_axes_autorite', 'pnj_candidats_catalogue', 'pnj_employeurs', 'pnj_familles_classes', 'pnj_fonctions', 'pnj_guides_habitants', 'pnj_institutions', 'pnj_lieux_metiers', 'pnj_metiers_profils', 'pnj_mouvement_individuel', 'pnj_referents', 'pnj_referents_sujets_connus', 'pnj_social_jalons_regles', 'postes_electifs_regles', 'postes_nommes_regles', 'postes_nommes_regles_empreinte', 'premium_abonnements', 'premium_achats', 'premium_droits', 'premium_parametres', 'premium_produits', 'premium_pub_externe_annonces', 'premium_renouvellements', 'presidence_memoire_ordres', 'presidence_memoire_sources', 'presidence_memoire_sources_absentes', 'produits_manufactures', 'qualifications', 'rapports_cellules_artefacts_20260926', 'recettes_militaires', 'recettes_militaires_empreinte', 'recettes_production', 'renseignement_couvertures', 'renseignement_identites_reelles', 'repartitions_budgetaires', 'ressources_economie', 'ressources_economie_empreinte', 'revenu_universel_parametres', 'routes_vehicules', 'rp_epoques', 'rue_noeuds_serveur', 'rue_sorties_batiments', 'salaires_caisses', 'salaires_civils_declares', 'salaires_production_pays', 'salaires_religieux_declares', 'sante_parametres', 'sante_repas_categories', 'sante_sommeil_lieux', 'scandales_predefinis', 'souvenirs_emplacements', 'souvenirs_listes', 'souvenirs_objets', 'sovarka_goulag_configuration', 'sovarka_urbanisme', 'subventions_familles', 'terrains_referentiel', 'titulaires_pnj', 'tracts_pnj_catalogue', 'universite_cursus', 'universite_cursus_jalons', 'usines_rachat_config', 'vehicules_modeles', 'villes', 'villes_empreinte', 'zz_snap_cka_blob', 'zz_snap_cka_metier']::text[] AS garder, ARRAY['acces_actes', 'acces_intrusions', 'acces_tentatives', 'accueil_personnages', 'acquisitions_transactions_internes', 'actes_illegaux', 'actes_nocturnes', 'actions_tracables', 'agent_tentatives', 'agents_renseignement', 'aliments_avaries_annonces', 'ambassades_asiles', 'ambassades_audiences', 'ambassades_ouvertes', 'amendes_tresor', 'antipoison_reapprovisionnements', 'apports_matieres', 'armoires_contenus', 'assemblee_debats', 'assemblee_disciplines', 'assemblee_indemnites', 'assemblee_intentions', 'assemblee_paroles', 'assemblee_presidence_bulletins', 'assemblee_presidence_dues', 'assemblee_presidence_scrutins', 'assemblee_presidence_tirage_vu', 'assemblee_propositions', 'assemblee_protestations', 'assemblee_reports', 'assemblee_reports_suspension', 'assemblee_requetes', 'assemblee_sanctions_paliers', 'assemblee_scrutins', 'assemblee_suspensions', 'assemblee_votes', 'audience_messages', 'audience_paroles', 'auteurs_secrets', 'avocats_barreau', 'batailles', 'batailles_engagements', 'batailles_groupes', 'batailles_rounds', 'batiments_fermes', 'benedictions', 'biens_saisis_helvetia', 'blocus_ordres_batiments', 'bne_annonces', 'bnr_refinancements_helvetia', 'boissons_du_jour', 'bureaux_option_premium', 'caches_pj', 'caisses_collectives_operations', 'caisses_fret', 'caisses_mouvements_clients', 'calomnies_actes', 'cameras_decouvertes', 'cameras_posees', 'camions_embarquements', 'camions_ordres', 'candidatures', 'candidatures_militaires', 'carrieres_acquises', 'cellules_renseignement', 'championnat', 'championnat_tentatives', 'chantier_commandes_recus', 'chantier_naval_bateaux', 'chantier_naval_commandes', 'chantier_requetes', 'chat_piece', 'chat_signaux', 'chronique_nationale', 'climat_accueils', 'climat_catastrophes', 'climat_crue_pertes', 'climat_effets_personnages', 'climat_evenements', 'climat_points_eau_puisages', 'climat_protections', 'clinique_nuitees', 'commandes_militaires', 'commerce_contrats', 'commerce_decors', 'commerce_decors_sources', 'commerce_passes', 'compagnies_militaires', 'compromis_historique', 'comptes_bancaires', 'conferences_jours', 'conferences_presse', 'conferences_presse_echanges', 'confiscations_douanieres', 'contacts_militaires', 'contacts_organisations', 'contenu_caisses_fret', 'contre_espionnage_tentatives', 'contributions_piete', 'corruptions_presse', 'crim_affaires', 'crim_constats', 'crim_corruptions_qhs', 'crim_evenements', 'crim_intrusions', 'crim_jetons_masque', 'crim_laissez_passer', 'crim_laissez_passer_passages', 'crim_qhs_demandes', 'crim_traces_achat', 'crim_vols_differes', 'cron_journal', 'cycles_electoraux', 'decorations_militaires', 'defenses_demandes', 'demandes_grace', 'demandes_manifestation', 'demandes_mariage', 'demandes_naturalisation', 'detentions', 'documents_officiels', 'dons_en_attente', 'dons_requetes', 'dossiers_auditions', 'dossiers_informatiques', 'dossiers_judiciaires_actes', 'dossiers_urbanisme', 'elections_tracts_pnj', 'employes_paies_recus', 'engagements_militaires', 'enigmes_resolues', 'ent_gains_quotidiens', 'entrainements_football', 'entrepot_journal', 'entrepot_transits', 'entrepots_reversements', 'equipements_installes', 'equipements_saisis', 'escort_appels', 'escort_evenements_commerciaux', 'escort_piratages_nuits', 'escort_relations', 'escort_scandales', 'escorts_complicite', 'escorts_intimite_recus', 'escorts_paies_recus', 'etat_civil_deces', 'etat_civil_naissances', 'etats_urgence', 'evenements_globaux', 'exportations_recues', 'fiche_hausses_observees', 'fiche_inventaire_observe', 'fiscalite_journal', 'flagrants_delits_attente', 'fonds_credits_uniques', 'fonds_debits', 'fonds_en_transit', 'football_primes_versees', 'forum_posts', 'forum_topics', 'fraudes_electorales', 'fuites_journalistiques', 'furets_ventes', 'garage_fabrications', 'garde_republicaine_renfort', 'greves_generales', 'groupes_pj_adhesions', 'guerres', 'guide_etat', 'guide_messages', 'guide_musee_dialogues', 'guide_reponses', 'heros_travail_clotures', 'heros_travail_points', 'heros_travail_records', 'heros_travail_requetes', 'historique_deplacements', 'hotel_nuitees', 'ia_appels_jour', 'immobilier_actes_recus', 'impacts_indices_attente', 'incidents_client', 'indices_diplomatiques', 'indices_diplomatiques_journal', 'informateurs_achats', 'interieur_dossiers', 'interviews_jodie', 'inventaire_actions_recus', 'inventaire_ecarts_observes', 'inventaire_livraisons_recues', 'investissements', 'invitations_diner', 'jardins_ouvriers_reserve', 'jardins_ouvriers_travail', 'jauges_actions_recus', 'jauges_objectifs_bascule', 'jauges_objectifs_etats', 'journal_articles_en_attente', 'journal_editions', 'journal_ventes_lectures', 'journaux_redacteurs', 'jugements', 'justice_indemnites', 'kolkhoze_dons_journaliers', 'lectures_chat', 'lectures_hebdo', 'locations_actives', 'locations_archives', 'locations_recus', 'logements_attributions_historique', 'logements_colocations', 'logements_decors', 'logements_decors_sources', 'logements_demandes', 'logements_loyers_historique', 'logements_premium', 'logements_premium_demandes', 'logements_reprises', 'logements_sociaux_historiques', 'logements_sociaux_internes', 'mails', 'mails_envois_systeme', 'mairie_successions', 'maladies_contacts', 'mandats_maires_archives', 'manifestations_spontanees', 'mariages', 'medecin_propositions', 'medicaments_pnj_passes', 'messages_chat', 'militaire_detections', 'militaire_terminal_requetes', 'militants_recrutes', 'mst_en_attente', 'mutineries', 'mutineries_membres', 'navigation_passages_douaniers', 'navigation_requetes', 'nominations_en_attente', 'nominations_militaires', 'nominations_poste_attente', 'notifications_chat', 'objets_abandonnes', 'objets_recus', 'objets_trouves_jours', 'obligations_helvetia', 'oeuvres', 'offres', 'offres_achat', 'ordres_couts_ecarts', 'ordres_couts_inconnus', 'organisation_commandes_recus', 'organisation_materiel_autorises', 'pa_credits_uniques', 'paris_sportifs', 'parti_boite_acces', 'parti_denonciations', 'parti_denonciations_requetes', 'pavillon_baux', 'pavillon_receptions', 'pavillon_recus', 'penuries', 'permis_depots_recus', 'permis_transactions_internes', 'personnage_evenements', 'personnages', 'personnages_donnees', 'personnages_maladies', 'personnages_qualifications', 'personnages_secrets', 'personnages_signaux', 'personnages_supprimes', 'petites_annonces', 'pharmacies_ventes', 'piratages_acces', 'placements_bancaires', 'plaintes_en_cours', 'plaintes_historique', 'pnj_ced_achats_recus', 'pnj_evenements', 'pnj_referents_pedagogie', 'pnj_social_escort_choisi', 'pnj_social_relations', 'pnj_transitions', 'pnj_verres_offerts', 'poissonniere_ventes', 'police_action_receipts', 'police_combat_rounds', 'police_detection_attempts', 'police_interceptions', 'ports_balance_jours', 'ports_journal', 'premium_pub_externe_vues', 'presences', 'presidence_memoire', 'presidents_clubs', 'presse_membres', 'prets', 'prets_bancaires', 'prets_ecritures_internes', 'prets_nationaux_demandes', 'prison_visites', 'prisonniers_qhs', 'production_recoltes_jour', 'production_regulations', 'productions_references', 'propositions_diplomatiques', 'publicites_joueurs', 'publicites_joueurs_vues', 'publicites_premium_presse', 'publicites_premium_sources', 'purges_residus_bancs', 'quetes_actives', 'rapports_cellules', 'rapports_renseignement', 'recettes_municipales', 'recoltes_journalieres', 'reconciliation_fantomes', 'registre_ventes_armes', 'regularisations_fiche', 'renseignements_connus', 'repartitions_versements', 'repas_differes_nuits', 'reservations_salle_reception', 'residence_locations', 'retraits_materiel_militaire', 'rumeurs_actives', 'salaires_civils_verses', 'salaires_religieux_verses', 'salles_signaux', 'salon_coupes', 'salons_chat', 'salons_membres', 'sante_sommeils', 'scandales_presse', 'scandales_tentatives', 'scandales_tirages', 'serrures', 'service_etage_commandes', 'services_militaires', 'signalements_messages', 'signalements_police', 'soins_antipoison_tentatives', 'soldes_militaires', 'souvenirs_accueil', 'sovarka_approbations', 'sovarka_autocritiques', 'sovarka_baux_internes', 'sovarka_bons_etat', 'sovarka_cafes_magistrat', 'sovarka_cafes_requetes', 'sovarka_cessions', 'sovarka_conscription', 'sovarka_conscrits', 'sovarka_consignes_ministre', 'sovarka_demandes', 'sovarka_droits_journal', 'sovarka_ecoutes_consultations', 'sovarka_ecoutes_rapports', 'sovarka_ecoutes_vols', 'sovarka_entrepots_passes', 'sovarka_foret_actes', 'sovarka_foret_journal', 'sovarka_foret_perdus', 'sovarka_foret_rencontres', 'sovarka_foret_visites', 'sovarka_goulag_autorisations', 'sovarka_goulag_controles', 'sovarka_goulag_corruptions', 'sovarka_goulag_depots', 'sovarka_goulag_entrees', 'sovarka_goulag_incidents', 'sovarka_goulag_interrogatoires', 'sovarka_goulag_refuges', 'sovarka_goulag_registre', 'sovarka_goulag_registre_jugements', 'sovarka_goulag_tentatives', 'sovarka_goulag_traces_revelees', 'sovarka_goulag_traversees', 'sovarka_goulag_visites', 'sovarka_habilitations_ecoute', 'sovarka_immeubles', 'sovarka_indemnites', 'sovarka_maisons_actes', 'sovarka_maisons_demandes', 'sovarka_maisons_hospitalite', 'sovarka_maisons_ragots', 'sovarka_manif_demandes', 'sovarka_manifs', 'sovarka_musee_billets', 'sovarka_production_passes', 'sovarka_repas_presidentiels', 'sovarka_reunions_beneficiaires', 'sovarka_reunions_evenements', 'sovarka_reunions_reservations', 'sovarka_saisines', 'sovarka_seances', 'sovarka_signalements', 'sovarka_sondages', 'sovarka_surveillance_rapports', 'sovarka_surveillances', 'ssm_rendezvous', 'subventions_entreprises_traces', 'subventions_municipales', 'successions', 'supporters_manifestations_sovarka', 'syndicat_etat_manifestations', 'temoins_citations', 'terrain_acquisitions_recus', 'terrain_actions_recus', 'terrain_negociations_recus', 'terrain_negociations_refus', 'terrain_visites_actives', 'terrains_historique_ventes', 'testaments', 'tournees', 'tractorisme_medailles', 'transferts_clubs', 'tribune_articles_etouffes', 'universite_inscriptions', 'universite_jalons_accomplis', 'usines_reversements', 'vehicules', 'ventes_snapshots', 'verres_du_jour', 'virements_automatiques', 'visuels_moderation', 'visuels_versions', 'vols_en_attente', 'votes_confiance', 'votes_confiance_bulletins', 'votes_electoraux']::text[] AS vider, ARRAY['assemblee_sieges', 'batiments_etat', 'budgets_clubs', 'budgets_municipaux', 'budgets_nationaux', 'caisses_batiments', 'catalogue_correspondance_legacy', 'catalogue_familles', 'catalogue_generique_type', 'catalogue_generiques', 'catalogue_types', 'catalogue_variantes', 'dotations_amorcage_caisses', 'drogues_stocks_dealers', 'enigme_tresor_tsars', 'entrepots_par_ville', 'entreprises', 'garde_republicaine_effectifs', 'kolkhoze_caisse', 'lois_assemblee', 'marche_krasnov_stock', 'medicaments_stocks', 'militaire_armes_bonus', 'murs_loyers', 'murs_titres', 'niveaux_prison', 'objets_modeles', 'organisations', 'pnj_employes_metier', 'pnj_force_publique_metier', 'pnj_membres', 'pnj_militants_metier', 'pnj_possessions', 'pnj_soldats_metier', 'ports_commerce', 'ports_productions', 'ports_stock', 'postes_attribues', 'recettes_commerce', 'rp_transitions', 'sovarka_locaux', 'sovarka_productions_villes', 'structures_medicales', 'terrain_actions_regles', 'terrains_etat']::text[] AS reinitialiser, ARRAY[]::text[] AS a_verifier;

DO $controle$
DECLARE l record; v_inconnues text; v_n bigint; t text; v_vides text[] := '{}';
BEGIN
  SELECT * INTO l FROM rz_listes;
  IF cardinality(l.a_verifier) > 0 THEN
    RAISE EXCEPTION 'REMISE À ZÉRO REFUSÉE : tables encore « à vérifier » : %', array_to_string(l.a_verifier, ', ');
  END IF;
  -- Une table créée depuis la préparation : vide, elle est simplement ignorée ; non vide, la remise est refusée.
  FOR t IN SELECT c.relname::text FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'p')
             AND NOT (c.relname::text = ANY (l.garder || l.vider || l.reinitialiser)) ORDER BY 1 LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', t) INTO v_n;
    IF v_n > 0 THEN v_vides := v_vides || (t || ' (' || v_n || ')'); END IF;
  END LOOP;
  IF cardinality(v_vides) > 0 THEN
    RAISE EXCEPTION 'REMISE À ZÉRO REFUSÉE : tables non classées et non vides : %', array_to_string(v_vides, ', ');
  END IF;
END $controle$;

-- 2. Relevé des comptes de la bêta (avant tout effacement). Comptes de test exclus. ---------------------------------
CREATE TABLE IF NOT EXISTS public.lancement_comptes_beta (
  user_id uuid PRIMARY KEY,
  personnages text[] NOT NULL,
  releve_le timestamptz NOT NULL DEFAULT now(),
  offre_accordee_le timestamptz
);
ALTER TABLE public.lancement_comptes_beta ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lancement_comptes_beta FROM PUBLIC, anon, authenticated;
INSERT INTO public.lancement_comptes_beta (user_id, personnages)
SELECT p.user_id, array_agg(p.name ORDER BY p.name)
  FROM public.personnages p
 WHERE p.user_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM public.comptes_test ct WHERE ct.personnage = p.name)
   AND NOT EXISTS (SELECT 1 FROM public.personnages p2 JOIN public.comptes_test ct2 ON ct2.personnage = p2.name WHERE p2.user_id = p.user_id)
 GROUP BY p.user_id
ON CONFLICT (user_id) DO NOTHING;

-- 3. Effacement de l'état vivant. -------------------------------------------------------------------------------------
-- TRUNCATE d'un seul tenant ; une table référencée par une table gardée (journaux.cree_par → personnages_donnees, ON DELETE
-- SET NULL) ne peut pas être tronquée : elle est vidée ensuite par DELETE, qui applique la règle de sa clé.
DO $vider$
DECLARE l record; v_tronquer text[]; v_supprimer text[]; t text;
BEGIN
  SELECT * INTO l FROM rz_listes;
  SELECT array_agg(c.relname::text ORDER BY c.relname) INTO v_supprimer
    FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'p') AND c.relname::text = ANY (l.vider)
     AND EXISTS (SELECT 1 FROM pg_constraint k WHERE k.contype = 'f' AND k.confrelid = c.oid
                  AND NOT ((SELECT e.relname::text FROM pg_class e WHERE e.oid = k.conrelid) = ANY (l.vider)));
  SELECT array_agg(format('public.%I', c.relname) ORDER BY c.relname) INTO v_tronquer
    FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'p') AND c.relname::text = ANY (l.vider)
     AND NOT (c.relname::text = ANY (coalesce(v_supprimer, '{}')));
  IF v_tronquer IS NOT NULL THEN
    EXECUTE 'TRUNCATE ' || array_to_string(v_tronquer, ', ') || ' RESTART IDENTITY';
  END IF;
  FOREACH t IN ARRAY coalesce(v_supprimer, '{}') LOOP
    EXECUTE format('DELETE FROM public.%I', t);
  END LOOP;
END $vider$;

-- DÉBUT DES RÉINITIALISATIONS
-- 4. Remise à l'état initial des tables mixtes (mission de fin de soirée du 25/11/2026, point 1.1). -----------------------
-- Une entrée par table « à réinitialiser » (marque « ▸ <table> : <stratégie> », contrôlée par le générateur : une table
-- sans entrée fait échouer la génération). Relevé en lecture de la production le 25/11/2026 (colonnes, nombre de lignes,
-- fonctions qui écrivent dans la table) ; états initiaux tirés des seeds baseline et des migrations de semis, jamais
-- inventés. Ce bloc s'exécute APRÈS l'effacement (étape 3) : les tables d'état qui pointaient vers ces lignes sont déjà vides.
-- Stratégies : aucune (référentiel qu'aucune fonction n'écrit), vider (état engendré à la demande : l'absence de ligne EST
-- l'état initial), filtrer (retirer ce qui vient des joueurs), colonnes (remettre à blanc les colonnes vivantes),
-- semis (rejouer le seed baseline ou la migration de semis).

-- ▸ catalogue_correspondance_legacy : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ catalogue_familles : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ catalogue_generique_type : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ catalogue_generiques : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ catalogue_types : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ catalogue_variantes : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ entrepots_par_ville : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ militaire_armes_bonus : aucune (barème, aucune fonction ne l'écrit)
-- ▸ objets_modeles : aucune (catalogue, aucune fonction ne l'écrit)
-- ▸ ports_productions : aucune (barème de production, aucune fonction ne l'écrit)
-- ▸ recettes_commerce : aucune (recettes, aucune fonction ne l'écrit)
-- ▸ sovarka_productions_villes : aucune (barème de production, aucune fonction ne l'écrit)
-- ▸ structures_medicales : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ terrain_actions_regles : aucune (règles, aucune fonction ne l'écrit)
-- ▸ rp_transitions : aucune (drapeaux transitoires du moteur : comportement à conserver, arbitrage du chantier 2C)
-- ▸ lois_assemblee : aucune (table morte : 0 ligne, aucune fonction ne la lit ni ne l'écrit)
-- ▸ dotations_amorcage_caisses : aucune (journal d'un amorçage déjà fait, ni lu ni écrit ; les caisses sont remises par
--   leur seed plus bas, ce journal reste pour l'histoire)

-- ▸ drogues_stocks_dealers : vider (ligne recréée au plafond du dealer au premier achat)
-- ▸ niveaux_prison : vider (ligne recréée à 100 au premier dégât)
-- ▸ kolkhoze_caisse : vider (dépôts des joueurs à la caisse du kolkhoze)
-- ▸ enigme_tresor_tsars : vider (progression des joueurs dans l'énigme)
-- ▸ murs_loyers : vider (échéancier recréé au premier prélèvement de loyer)
-- ▸ medicaments_stocks : vider (ligne recréée à 0 à la première production ; les usines remplissent)
-- ▸ ports_stock : vider (stock des ports accumulé pendant la bêta ; la production de la première nuit le remplit)
-- ▸ pnj_possessions : vider (objets acquis en partie ; arbitrage du 05/10 : aucune reprise)
-- ▸ postes_attribues : vider (registre des postes pris par des joueurs : nomination, élection, candidature, tirage)
TRUNCATE public.drogues_stocks_dealers, public.niveaux_prison, public.kolkhoze_caisse, public.enigme_tresor_tsars,
  public.murs_loyers, public.medicaments_stocks, public.ports_stock, public.pnj_possessions, public.postes_attribues;

-- ▸ pnj_membres : filtrer (les PNJ attachés à un joueur — recrutés, militants, soldats d'une compagnie menée par un joueur —
--   disparaissent avec lui ; le personnel des institutions reste, il n'est engendré qu'à la création de l'institution)
DELETE FROM public.pnj_membres WHERE proprietaire_pj IS NOT NULL OR leader_pj IS NOT NULL;
-- ▸ pnj_soldats_metier : filtrer (suit pnj_membres par sa clé ON DELETE CASCADE)
-- ▸ pnj_employes_metier : filtrer (suit pnj_membres par sa clé ON DELETE CASCADE)
-- ▸ pnj_force_publique_metier : filtrer (suit pnj_membres par sa clé ON DELETE CASCADE)
-- ▸ pnj_militants_metier : filtrer (suit pnj_membres par sa clé ON DELETE CASCADE)
-- ▸ garde_republicaine_effectifs : filtrer (suit pnj_membres par sa clé ON DELETE CASCADE)

-- ▸ organisations : filtrer (les organisations fondées par des joueurs disparaissent ; celles du monde, dirigées par un PNJ
--   — Syndicat des Dockers, Syndicat national de Sovarka —, restent, vidées de leurs membres, demandes et caisse)
DELETE FROM public.organisations
 WHERE NOT (data IS JSON OBJECT AND coalesce(data::jsonb ->> 'chefEstPnj', 'false') = 'true');
UPDATE public.organisations
   SET data = (data::jsonb || jsonb_build_object('membres', '[]'::jsonb, 'demandesAdhesion', '[]'::jsonb, 'caisse', 0))::text
 WHERE data IS JSON OBJECT;

-- ▸ entreprises : filtrer puis doter (les commerces des joueurs disparaissent ; TOUS les commerces restants, ceux des PNJ,
--   repartent de leur dotation initiale — décision n° 5 de Fred, 26/11 : caisse, et quantité de chaque matière et de chaque
--   produit qu'ils tiennent, lues dans lancement_dotations_commerces (type du commerce, sinon « * » du pays), réglables dans
--   la page MJ ; historique vidé)
DELETE FROM public.entreprises WHERE coalesce(data ->> 'proprietaire', '') NOT LIKE 'PNJ%';
CREATE TEMP TABLE rp_dot_commerce ON COMMIT DROP AS
  SELECT e.id, d.caisse, d.matieres_qte, d.produits_qte
    FROM public.entreprises e
    CROSS JOIN LATERAL (SELECT x.caisse, x.matieres_qte, x.produits_qte FROM public.lancement_dotations_commerces x
                         WHERE x.pays = e.data ->> 'country' AND x.type IN (e.data ->> 'type', '*')
                         ORDER BY (x.type = '*') LIMIT 1) d;
UPDATE public.entreprises e
   SET data = e.data || jsonb_build_object('caisse', r.caisse, 'historique', '[]'::jsonb,
         'stockMatieres', coalesce((SELECT jsonb_object_agg(k, r.matieres_qte) FROM jsonb_object_keys(
            CASE WHEN jsonb_typeof(e.data -> 'stockMatieres') = 'object' THEN e.data -> 'stockMatieres' ELSE '{}'::jsonb END) k), '{}'::jsonb),
         'stockProduits', coalesce((SELECT jsonb_object_agg(k, r.produits_qte) FROM jsonb_object_keys(
            CASE WHEN jsonb_typeof(e.data -> 'stockProduits') = 'object' THEN e.data -> 'stockProduits' ELSE '{}'::jsonb END) k), '{}'::jsonb))
  FROM rp_dot_commerce r WHERE r.id = e.id;

-- ▸ sovarka_locaux : colonnes (plus de demande en cours ; un local tenu par un commerce de joueur redevient libre)
UPDATE public.sovarka_locaux SET demande_id = NULL WHERE demande_id IS NOT NULL;
UPDATE public.sovarka_locaux s SET entreprise_id = NULL
 WHERE s.entreprise_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.entreprises e WHERE e.id = s.entreprise_id);

-- ▸ murs_titres : colonnes (les murs reviennent à la commune, propriétaire semé par la migration du socle ; offres retirées)
UPDATE public.murs_titres SET proprietaire = 'commune', offre = NULL, updated_at = now()
 WHERE proprietaire IS DISTINCT FROM 'commune' OR offre IS NOT NULL;

-- ▸ terrains_etat : colonnes (plus de propriétaire, de copropriétaire, de permis ni de chantier ; le blob garde seulement
--   ce que la migration de semis y pose : ville, surface, valeur, constructibilité, occupant PNJ ; l'occupation est
--   réinitialisée par le moteur au premier passage)
UPDATE public.terrains_etat
   SET proprietaire = NULL, coproprietaire = NULL, niveau_construction = NULL, valeur_totale = NULL, updated_at = now(),
       data = (SELECT coalesce(jsonb_object_agg(k, v), '{}'::jsonb) FROM jsonb_each(data::jsonb) x(k, v)
                WHERE k IN ('city', 'surface', 'valeur_totale', 'constructionAutorisee', 'pnj', 'pnjData'))::text
 WHERE data IS JSON OBJECT;

-- ▸ assemblee_sieges : colonnes (les 9 députés Gamma gardent leur identité permanente ; plus aucun siège endormi)
UPDATE public.assemblee_sieges SET endormi = false, endormi_ts = NULL, endormi_par = NULL, updated_at = now()
 WHERE endormi IS DISTINCT FROM false OR endormi_ts IS NOT NULL OR endormi_par IS NOT NULL;

-- ▸ budgets_clubs : colonnes (caisse à 0 et historique vide ; le barème des salaires est du socle et reste)
UPDATE public.budgets_clubs
   SET data = (data - 'derniereSubventionJour') || jsonb_build_object('caisse', 0, 'historique', '[]'::jsonb), updated_at = now();

-- ▸ budgets_municipaux : colonnes (taux foncier de départ, 0,05 FR/m²/jour : valeur par défaut de taxe_fonciere_prelever)
UPDATE public.budgets_municipaux SET data = (data - 'derniereMaj') || jsonb_build_object('tauxFoncier', 0.05), updated_at = now();

-- ▸ budgets_nationaux : colonnes (retour aux valeurs de départ, décision technique du 26/11 : celles que pose le serveur à la
--   création d'un budget — budgets_nationaux_ecran_fusionner : taux national 2, réserve du jour 0 — ; réfectoire et matières
--   de la caserne vides ; seuls les lots militaires de la « dotation-initiale » restent, et le stock de l'armurerie militaire
--   en est la somme ; les dates des derniers traitements, le couvre-feu, la mobilisation, l'effort de guerre, le régime
--   d'exception, la recherche militaire et la préemption disparaissent ; les taux municipal et de main-d'œuvre de Sovarka
--   reviennent à 10)
CREATE TEMP TABLE rp_lots_initiaux ON COMMIT DROP AS
  SELECT b.id,
         coalesce(jsonb_object_agg(o.k, o.lots) FILTER (WHERE o.k IS NOT NULL), '{}'::jsonb) AS lots,
         coalesce(jsonb_object_agg(o.k, o.qte) FILTER (WHERE o.k IS NOT NULL), '{}'::jsonb) AS stock
    FROM public.budgets_nationaux b
    LEFT JOIN LATERAL (
      SELECT t.k,
             coalesce((SELECT jsonb_agg(x) FROM jsonb_array_elements(CASE WHEN jsonb_typeof(t.v) = 'array' THEN t.v ELSE '[]'::jsonb END) x
                        WHERE x ->> 'lot' = 'dotation-initiale'), '[]'::jsonb) AS lots,
             coalesce((SELECT sum((x ->> 'qte')::numeric) FROM jsonb_array_elements(CASE WHEN jsonb_typeof(t.v) = 'array' THEN t.v ELSE '[]'::jsonb END) x
                        WHERE x ->> 'lot' = 'dotation-initiale'), 0) AS qte
        FROM jsonb_each(CASE WHEN jsonb_typeof(b.data -> 'lotsMilitaires') = 'object' THEN b.data -> 'lotsMilitaires' ELSE '{}'::jsonb END) t(k, v)) o ON true
   GROUP BY b.id;
UPDATE public.budgets_nationaux b
   SET data = jsonb_strip_nulls(jsonb_build_object(
         'tauxNational', 2, 'reserveJour', 0, 'refectoire', '{}'::jsonb, 'caserneMatieres', '{}'::jsonb,
         'tauxMunicipal', CASE WHEN b.data ? 'tauxMunicipal' THEN 10 END,
         'tauxMainOeuvre', CASE WHEN b.data ? 'tauxMainOeuvre' THEN 10 END,
         'lotsMilitaires', l.lots, 'stockArmurerieMilitaire', l.stock)),
       updated_at = now()
  FROM rp_lots_initiaux l WHERE l.id = b.id;
-- ▸ ports_commerce : colonnes (retour aux valeurs de départ, décision technique du 26/11 : celles de la création des ports —
--   valeurs par défaut des colonnes, migration 20261116113000 — ; nom, caisse, lieu, entrepôts et prise en charge du déficit
--   par les PNJ restent ; la caisse du port repart de sa dotation, avec les caisses publiques ci-dessous)
UPDATE public.ports_commerce SET taux_douane = DEFAULT, repartition = DEFAULT, prix_cession = DEFAULT, prix_export = DEFAULT,
       quotas_import = DEFAULT, quotas_export = DEFAULT, dotation_jour = DEFAULT, modifie_par = NULL, updated_at = now();

-- ▸ marche_krasnov_stock : semis (valeurs de la migration 20261122160000_krasnov_marche_unique)
TRUNCATE public.marche_krasnov_stock;
INSERT INTO public.marche_krasnov_stock (cle, qte) VALUES
  ('fruits_legumes', 20), ('oeufs', 10), ('viande', 10), ('sucre', 10), ('cereales', 10), ('poisson', 10), ('textile', 10),
  ('bouteille_eau', 30), ('graisse_ours', 10), ('confiture', 8), ('pain_noir', 10), ('goulash', 6), ('chemise', 4),
  ('tenue_ninja', 2), ('masque_carnaval', 2);

-- ▸ caisses_batiments : dotation (TOUTES les caisses publiques de Républia et de Sovarka repartent de leur dotation initiale —
--   décision n° 6 de Fred, 26/11 — lue dans lancement_dotations_caisses par catégorie, sinon « * » du pays, réglable dans la
--   page MJ ; les défauts de Républia sont les montants arbitrés le 05/10 ; le reste du contenu de la caisse est effacé).
--   Les caisses des empires fermés ne sont pas touchées.
UPDATE public.caisses_batiments c
   SET data = jsonb_build_object('solde', (SELECT x.montant FROM public.lancement_dotations_caisses x
                 WHERE x.pays = split_part(c.id, '_', 1) AND x.categorie IN (public.lancement_caisse_categorie(c.id), '*')
                 ORDER BY (x.categorie = '*') LIMIT 1)), updated_at = now()
 WHERE split_part(c.id, '_', 1) IN ('republic', 'soviet')
   AND EXISTS (SELECT 1 FROM public.lancement_dotations_caisses x WHERE x.pays = split_part(c.id, '_', 1));

-- ▸ batiments_etat : semis (les trois entrepôts logistiques de Républia reprennent leur stock décidé — seed
--   baseline/seeds/92_mixte/batiments_etat.sql ; les autres bâtiments, sans état initial décrit, sont gardés)
INSERT INTO public.batiments_etat (id, country, city, building_id, data) VALUES ('republic_capitale_entrepot-logistique-luthecia', 'republic', 'capitale', 'entrepot-logistique-luthecia', $x${"entrepot": {"stock": {"alcool": 100, "bois": 750, "carburant": 17, "cereales": 75, "charbon": 400, "desinfectant": 32, "fruits_legumes": 150, "medicaments": 25, "metal": 200, "minerai": 500, "petrole": 200, "plantes": 300, "poisson": 125, "produits_exotiques": 125, "tabac": 30, "textile": 125, "viande": 85}}}$x$::jsonb) ON CONFLICT (id) DO UPDATE SET country = EXCLUDED.country, city = EXCLUDED.city, building_id = EXCLUDED.building_id, data = EXCLUDED.data, updated_at = now();
INSERT INTO public.batiments_etat (id, country, city, building_id, data) VALUES ('republic_ville_a_entrepot-logistique-psm', 'republic', 'ville_a', 'entrepot-logistique-psm', $x${"entrepot": {"stock": {"alcool": 100, "bois": 750, "carburant": 17, "cereales": 75, "charbon": 400, "desinfectant": 32, "fruits_legumes": 150, "medicaments": 25, "metal": 200, "minerai": 500, "petrole": 200, "plantes": 300, "poisson": 125, "produits_exotiques": 125, "tabac": 30, "textile": 125, "viande": 85}}}$x$::jsonb) ON CONFLICT (id) DO UPDATE SET country = EXCLUDED.country, city = EXCLUDED.city, building_id = EXCLUDED.building_id, data = EXCLUDED.data, updated_at = now();
INSERT INTO public.batiments_etat (id, country, city, building_id, data) VALUES ('republic_ville_b_entrepot-logistique-montrouge', 'republic', 'ville_b', 'entrepot-logistique-montrouge', $x${"entrepot": {"stock": {"alcool": 100, "bois": 750, "carburant": 17, "cereales": 75, "charbon": 400, "desinfectant": 32, "fruits_legumes": 150, "medicaments": 25, "metal": 200, "minerai": 500, "petrole": 200, "plantes": 300, "poisson": 125, "produits_exotiques": 125, "tabac": 30, "textile": 125, "viande": 85}}}$x$::jsonb) ON CONFLICT (id) DO UPDATE SET country = EXCLUDED.country, city = EXCLUDED.city, building_id = EXCLUDED.building_id, data = EXCLUDED.data, updated_at = now();
-- FIN DES RÉINITIALISATIONS

-- 5. Offre ponctuelle des testeurs de la bêta (décision de Fred du 25/11/2026 au soir). --------------------------------
INSERT INTO public.premium_droits (user_id, produit, cible, source, note)
SELECT b.user_id, o.produit, NULL, 'offre_lancement', 'Merci d''avoir testé la bêta : ' || o.usage
  FROM public.lancement_comptes_beta b
 -- Publicités (décision du 26/11) : campagnes vendues pour tous les supports ; l'offre en donne deux courtes, prévues pour
 -- une annonce dans la presse et une publicité dans la rue.
 CROSS JOIN (VALUES ('personnalisation_local', 'personnalisation d''un commerce'), ('campagne_publicite_courte', 'une annonce dans la presse'),
                    ('campagne_publicite_courte', 'une publicité dans la rue')) o(produit, usage)
 WHERE b.offre_accordee_le IS NULL;
UPDATE public.lancement_comptes_beta SET offre_accordee_le = now() WHERE offre_accordee_le IS NULL;

COMMIT;
