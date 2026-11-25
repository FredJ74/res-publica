-- REMISE À ZÉRO DU LANCEMENT (19/12/2026) — PRÉPARÉE, JAMAIS EXÉCUTÉE SANS FRED.
-- Mission du soir du 25/11/2026 (Claude), bloc 4.5. Fichier GÉNÉRÉ par outils/lancement/generer-remise-a-zero.py à partir de
-- baseline/classification-donnees.csv et outils/lancement/classement-complementaire-20261125.csv : ne pas l'éditer à la main.
-- Procédure complète, ce qui est effacé ou gardé, retour arrière : docs/premium/REMISE-A-ZERO-20261219.md.
-- Listes : garder 152 ; vider 309 ; reinitialiser 40 ; a_verifier 2
--
-- Ce que fait le script, dans UNE transaction (tout ou rien) :
--   1. garde-fous : phrase de confirmation posée dans la session, date de Paris ≥ 19/12/2026, aucune table « à vérifier »,
--      aucune table inconnue non vide, tables « à réinitialiser » déclarées traitées ;
--   2. relève les comptes de la bêta (comptes ayant un personnage, comptes de test exclus) dans lancement_comptes_beta ;
--   3. vide les tables d'état vivant (TRUNCATE sans CASCADE : une clé étrangère inattendue fait échouer, rien n'est effacé) ;
--   4. accorde l'offre des testeurs : personnalisation d'un commerce, une annonce dans la presse, une publicité dans la rue.
-- Les comptes de connexion (auth.users), les accès du MJ, les achats premium payés et les référentiels sont gardés.
--
-- Pour l'exécuter (Fred décide du moment) :
--   SET human_gambit.remise_a_zero = 'JE-CONFIRME-LA-REMISE-A-ZERO-DU-19-12-2026';
--   SET human_gambit.remise_reinitialisations = 'faites';   -- après l'étape « réinitialiser » de la procédure
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
  ARRAY['accueil_chemins', 'accueil_etapes', 'accueil_journalistes', 'accueil_parametres', 'accueil_parametres_textes', 'actes_nocturnes_mecanismes', 'admin_actions_tribunal', 'administrateurs', 'administrateurs_invitations', 'aliments_parametres', 'armureries_dotations', 'assemblee_catalogue_illegal', 'assemblee_categories_interdiction', 'budget_national_champs_regles', 'caisses_autorites', 'camions_destinations', 'camions_militaires', 'carrieres', 'chaines_production_pays', 'chaines_production_usine', 'chantier_naval_modeles', 'chantiers_besoins_jour', 'chantiers_paliers', 'climat_boutiques', 'climat_lieux_vente', 'climat_parametres', 'climat_points_eau', 'climat_villes_exclues', 'climat_zones_inondables', 'clubs_football', 'clubs_sportifs_regles', 'commerces_dotations', 'commerces_types', 'communications_salles', 'compagnies_militaires_snapshot_20260926', 'comptes_test', 'comptes_test_parametres', 'contacts_organisations_passeurs', 'crim_boutiques', 'crim_parametres', 'directeurs_usine', 'directeurs_usine_pays', 'directions_etablissements', 'dossiers_judiciaires_actes_types', 'entreprises_constantes', 'entreprises_prix_rachat', 'escorts_agences', 'escorts_catalogue', 'fonds_credits_sources', 'furets_boutiques', 'garde_republicaine_postes', 'graisses_points_vente', 'greffes_tribunaux', 'groupes_presse', 'guide_carrieres_criteres', 'guide_pistes', 'habilitations', 'habilitations_carrieres', 'habilitations_postes', 'immobilier_baremes', 'imprimeries_declarees', 'indices_villes', 'informateurs_pnj', 'infractions', 'infractions_alias', 'infractions_categories', 'infractions_empreinte', 'journaux', 'justice_avocats_commis', 'justice_faits_publics', 'kolkhoze_caisse_quotas', 'lancement_comptes_beta', 'locaux_loyers_referentiel', 'mails_expediteurs_systeme', 'maladies_parametres', 'marche_krasnov_produits', 'navigation_lieux_regles', 'objets_achetables', 'offres_emploi_bne', 'ordres_couts', 'ordres_couts_empreinte', 'ordres_couts_pays', 'ordres_generiques', 'pa_bonus_differes', 'pa_bonus_differes_empreinte', 'pa_bonus_hotel', 'pa_credits_sources', 'pharmacies_points_vente', 'pnj_axes_autorite', 'pnj_candidats_catalogue', 'pnj_employeurs', 'pnj_familles_classes', 'pnj_fonctions', 'pnj_guides_habitants', 'pnj_institutions', 'pnj_lieux_metiers', 'pnj_metiers_profils', 'pnj_mouvement_individuel', 'pnj_referents', 'pnj_referents_sujets_connus', 'pnj_social_jalons_regles', 'postes_electifs_regles', 'postes_nommes_regles', 'postes_nommes_regles_empreinte', 'premium_abonnements', 'premium_achats', 'premium_droits', 'premium_parametres', 'premium_produits', 'premium_pub_externe_annonces', 'premium_renouvellements', 'presidence_memoire_ordres', 'presidence_memoire_sources', 'presidence_memoire_sources_absentes', 'produits_manufactures', 'qualifications', 'rapports_cellules_artefacts_20260926', 'recettes_militaires', 'recettes_militaires_empreinte', 'recettes_production', 'renseignement_couvertures', 'renseignement_identites_reelles', 'repartitions_budgetaires', 'ressources_economie', 'ressources_economie_empreinte', 'routes_vehicules', 'rp_epoques', 'rue_noeuds_serveur', 'rue_sorties_batiments', 'salaires_caisses', 'salaires_civils_declares', 'salaires_production_pays', 'salaires_religieux_declares', 'sante_parametres', 'sante_repas_categories', 'sante_sommeil_lieux', 'scandales_predefinis', 'souvenirs_emplacements', 'souvenirs_listes', 'sovarka_goulag_configuration', 'subventions_familles', 'terrains_referentiel', 'titulaires_pnj', 'tracts_pnj_catalogue', 'universite_cursus', 'universite_cursus_jalons', 'usines_rachat_config', 'vehicules_modeles', 'villes', 'villes_empreinte', 'zz_snap_cka_blob', 'zz_snap_cka_metier']::text[] AS garder, ARRAY['accueil_personnages', 'acquisitions_transactions_internes', 'actes_illegaux', 'actes_nocturnes', 'actions_tracables', 'admin_journal', 'agent_tentatives', 'agents_renseignement', 'aliments_avaries_annonces', 'ambassades_asiles', 'ambassades_audiences', 'ambassades_ouvertes', 'amendes_tresor', 'antipoison_reapprovisionnements', 'apports_matieres', 'armoires_contenus', 'assemblee_debats', 'assemblee_disciplines', 'assemblee_indemnites', 'assemblee_intentions', 'assemblee_paroles', 'assemblee_presidence_bulletins', 'assemblee_presidence_dues', 'assemblee_presidence_scrutins', 'assemblee_presidence_tirage_vu', 'assemblee_propositions', 'assemblee_protestations', 'assemblee_reports', 'assemblee_reports_suspension', 'assemblee_requetes', 'assemblee_sanctions_paliers', 'assemblee_scrutins', 'assemblee_suspensions', 'assemblee_votes', 'audience_messages', 'audience_paroles', 'avocats_barreau', 'batailles', 'batailles_engagements', 'batailles_groupes', 'batailles_rounds', 'batiments_fermes', 'biens_saisis_helvetia', 'bne_annonces', 'bnr_refinancements_helvetia', 'caisses_collectives_operations', 'caisses_fret', 'caisses_mouvements_clients', 'calomnies_actes', 'camions_embarquements', 'camions_ordres', 'candidatures', 'candidatures_militaires', 'carrieres_acquises', 'cellules_renseignement', 'championnat', 'championnat_tentatives', 'chantier_commandes_recus', 'chantier_requetes', 'chat_piece', 'chat_signaux', 'chronique_nationale', 'climat_effets_personnages', 'climat_points_eau_puisages', 'clinique_nuitees', 'commandes_militaires', 'commerce_contrats', 'commerce_decors', 'commerce_decors_sources', 'commerce_passes', 'compagnies_militaires', 'compromis_historique', 'comptes_bancaires', 'conferences_jours', 'conferences_presse', 'conferences_presse_echanges', 'confiscations_douanieres', 'contacts_militaires', 'contacts_organisations', 'contenu_caisses_fret', 'contre_espionnage_tentatives', 'contributions_piete', 'corruptions_presse', 'crim_affaires', 'crim_evenements', 'crim_jetons_masque', 'crim_traces_achat', 'cron_journal', 'cycles_electoraux', 'decorations_militaires', 'defenses_demandes', 'demandes_grace', 'demandes_manifestation', 'demandes_mariage', 'demandes_naturalisation', 'detentions', 'documents_officiels', 'dons_en_attente', 'dons_requetes', 'dossiers_auditions', 'dossiers_judiciaires_actes', 'dossiers_urbanisme', 'elections_tracts_pnj', 'engagements_militaires', 'entrainements_football', 'entrepot_journal', 'entrepot_transits', 'entrepots_reversements', 'equipements_installes', 'escort_evenements_commerciaux', 'etat_civil_deces', 'etat_civil_naissances', 'etats_urgence', 'evenements_globaux', 'exportations_recues', 'fiche_hausses_observees', 'fiche_inventaire_observe', 'fiscalite_journal', 'fonds_credits_uniques', 'fonds_debits', 'fonds_en_transit', 'football_primes_versees', 'forum_posts', 'forum_topics', 'fraudes_electorales', 'fuites_journalistiques', 'garde_republicaine_effectifs', 'garde_republicaine_renfort', 'greves_generales', 'guerres', 'guide_etat', 'guide_messages', 'guide_musee_dialogues', 'guide_reponses', 'heros_travail_clotures', 'heros_travail_points', 'heros_travail_records', 'historique_deplacements', 'hotel_nuitees', 'ia_appels_jour', 'impacts_indices_attente', 'incidents_client', 'indices_diplomatiques', 'indices_diplomatiques_journal', 'interviews_jodie', 'inventaire_actions_recus', 'inventaire_ecarts_observes', 'inventaire_livraisons_recues', 'investissements', 'invitations_diner', 'jardins_ouvriers_reserve', 'jardins_ouvriers_travail', 'jauges_actions_recus', 'jauges_objectifs_bascule', 'jauges_objectifs_etats', 'journal_articles_en_attente', 'journal_editions', 'journal_ventes_lectures', 'journaux_redacteurs', 'jugements', 'justice_indemnites', 'lectures_chat', 'locations_actives', 'locations_archives', 'locations_recus', 'logements_attributions_historique', 'logements_demandes', 'logements_loyers_historique', 'logements_sociaux_historiques', 'logements_sociaux_internes', 'mails', 'mails_envois_systeme', 'mandats_maires_archives', 'mariages', 'medicaments_pnj_passes', 'messages_chat', 'militaire_detections', 'militaire_terminal_requetes', 'militants_recrutes', 'mutineries', 'mutineries_membres', 'navigation_requetes', 'nominations_en_attente', 'nominations_militaires', 'nominations_poste_attente', 'notifications_chat', 'objets_abandonnes', 'objets_recus', 'objets_trouves_jours', 'obligations_helvetia', 'oeuvres', 'offres', 'ordres_couts_ecarts', 'ordres_couts_inconnus', 'pa_credits_uniques', 'paris_sportifs', 'permis_depots_recus', 'permis_transactions_internes', 'personnage_evenements', 'personnages', 'personnages_donnees', 'personnages_maladies', 'personnages_qualifications', 'personnages_secrets', 'personnages_signaux', 'personnages_supprimes', 'petites_annonces', 'placements_bancaires', 'plaintes_en_cours', 'pnj_ced_achats_recus', 'pnj_employes_metier', 'pnj_evenements', 'pnj_force_publique_metier', 'pnj_militants_metier', 'pnj_referents_pedagogie', 'pnj_social_escort_choisi', 'pnj_social_relations', 'pnj_soldats_metier', 'pnj_transitions', 'poissonniere_ventes', 'police_action_receipts', 'police_combat_rounds', 'police_detection_attempts', 'police_interceptions', 'ports_balance_jours', 'ports_journal', 'premium_pub_externe_vues', 'presences', 'presidence_memoire', 'presidents_clubs', 'presse_membres', 'prets', 'prets_bancaires', 'prets_ecritures_internes', 'prets_nationaux_demandes', 'prisonniers_qhs', 'production_recoltes_jour', 'productions_references', 'propositions_diplomatiques', 'publicites_joueurs', 'publicites_joueurs_vues', 'publicites_premium_presse', 'publicites_premium_sources', 'purges_residus_bancs', 'quetes_actives', 'rapports_cellules', 'rapports_renseignement', 'recettes_municipales', 'recoltes_journalieres', 'reconciliation_fantomes', 'registre_ventes_armes', 'regularisations_fiche', 'renseignements_connus', 'repartitions_versements', 'reservations_salle_reception', 'retraits_materiel_militaire', 'rumeurs_actives', 'salaires_civils_verses', 'salaires_religieux_verses', 'salles_signaux', 'salon_coupes', 'salons_chat', 'salons_membres', 'sante_sommeils', 'scandales_presse', 'scandales_tentatives', 'scandales_tirages', 'services_militaires', 'signalements_police', 'soldes_militaires', 'souvenirs_accueil', 'sovarka_bons_etat', 'sovarka_conscription', 'sovarka_demandes', 'sovarka_ecoutes_rapports', 'sovarka_ecoutes_vols', 'sovarka_entrepots_passes', 'sovarka_foret_actes', 'sovarka_foret_rencontres', 'sovarka_maisons_actes', 'sovarka_maisons_demandes', 'sovarka_maisons_ragots', 'sovarka_musee_billets', 'sovarka_production_passes', 'ssm_rendezvous', 'subventions_entreprises_traces', 'subventions_municipales', 'successions', 'temoins_citations', 'terrain_acquisitions_recus', 'terrain_actions_recus', 'terrain_negociations_recus', 'terrain_negociations_refus', 'terrain_visites_actives', 'terrains_historique_ventes', 'testaments', 'tournees', 'transferts_clubs', 'tribune_articles_etouffes', 'universite_inscriptions', 'universite_jalons_accomplis', 'ventes_snapshots', 'virements_automatiques', 'visuels_moderation', 'visuels_versions', 'vols_en_attente', 'votes_confiance', 'votes_confiance_bulletins', 'votes_electoraux']::text[] AS vider, ARRAY['assemblee_sieges', 'batiments_etat', 'budgets_clubs', 'budgets_municipaux', 'budgets_nationaux', 'caisses_batiments', 'catalogue_correspondance_legacy', 'catalogue_familles', 'catalogue_generique_type', 'catalogue_generiques', 'catalogue_types', 'catalogue_variantes', 'dotations_amorcage_caisses', 'drogues_stocks_dealers', 'enigme_tresor_tsars', 'entrepots_par_ville', 'entreprises', 'kolkhoze_caisse', 'lois_assemblee', 'marche_krasnov_stock', 'medicaments_stocks', 'militaire_armes_bonus', 'murs_loyers', 'murs_titres', 'niveaux_prison', 'objets_modeles', 'organisations', 'pnj_membres', 'pnj_possessions', 'ports_commerce', 'ports_productions', 'ports_stock', 'postes_attribues', 'recettes_commerce', 'rp_transitions', 'sovarka_locaux', 'sovarka_productions_villes', 'structures_medicales', 'terrain_actions_regles', 'terrains_etat']::text[] AS reinitialiser, ARRAY['blocus_ordres_batiments', 'climat_evenements']::text[] AS a_verifier;

DO $controle$
DECLARE l record; v_inconnues text; v_n bigint; t text; v_vides text[] := '{}';
BEGIN
  SELECT * INTO l FROM rz_listes;
  IF cardinality(l.a_verifier) > 0 THEN
    RAISE EXCEPTION 'REMISE À ZÉRO REFUSÉE : tables encore « à vérifier » : %', array_to_string(l.a_verifier, ', ');
  END IF;
  IF cardinality(l.reinitialiser) > 0 AND current_setting('human_gambit.remise_reinitialisations', true) IS DISTINCT FROM 'faites' THEN
    RAISE EXCEPTION 'REMISE À ZÉRO REFUSÉE : tables à réinitialiser non déclarées traitées : %', array_to_string(l.reinitialiser, ', ');
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
DO $vider$
DECLARE l record; v_existantes text[];
BEGIN
  SELECT * INTO l FROM rz_listes;
  SELECT array_agg(format('public.%I', c.relname) ORDER BY c.relname) INTO v_existantes
    FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'p') AND c.relname::text = ANY (l.vider);
  IF v_existantes IS NOT NULL THEN
    EXECUTE 'TRUNCATE ' || array_to_string(v_existantes, ', ') || ' RESTART IDENTITY';
  END IF;
END $vider$;

-- 4. Offre ponctuelle des testeurs de la bêta (décision de Fred du 25/11/2026 au soir). --------------------------------
INSERT INTO public.premium_droits (user_id, produit, cible, source, note)
SELECT b.user_id, o.produit, NULL, 'offre_lancement', 'Merci d''avoir testé la bêta'
  FROM public.lancement_comptes_beta b
 CROSS JOIN (VALUES ('personnalisation_local'), ('credit_publicite_presse'), ('credit_publicite_rue')) o(produit)
 WHERE b.offre_accordee_le IS NULL;
UPDATE public.lancement_comptes_beta SET offre_accordee_le = now() WHERE offre_accordee_le IS NULL;

COMMIT;
