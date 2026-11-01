-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine immobilier et territoire -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.acquisitions_transactions_internes ADD CONSTRAINT acquisitions_transactions_internes_pkey PRIMARY KEY (transaction_id, acteur);
ALTER TABLE public.batiments_etat ADD CONSTRAINT batiments_etat_pkey PRIMARY KEY (id);
ALTER TABLE public.batiments_fermes ADD CONSTRAINT batiments_fermes_pkey PRIMARY KEY (id);
ALTER TABLE public.bne_annonces ADD CONSTRAINT bne_annonces_pkey PRIMARY KEY (id);
ALTER TABLE public.dossiers_urbanisme ADD CONSTRAINT dossiers_urbanisme_pkey PRIMARY KEY (id);
ALTER TABLE public.locations_actives ADD CONSTRAINT locations_actives_pkey PRIMARY KEY (id);
ALTER TABLE public.locations_archives ADD CONSTRAINT locations_archives_pkey PRIMARY KEY (id);
ALTER TABLE public.locations_recus ADD CONSTRAINT locations_recus_pkey PRIMARY KEY (acteur, requete);
ALTER TABLE public.locaux_loyers_referentiel ADD CONSTRAINT locaux_loyers_referentiel_pkey PRIMARY KEY (batiment, piece, ville);
ALTER TABLE public.logements_attributions_historique ADD CONSTRAINT logements_attributions_historique_pkey PRIMARY KEY (id);
ALTER TABLE public.logements_demandes ADD CONSTRAINT logements_demandes_pkey PRIMARY KEY (id);
ALTER TABLE public.logements_loyers_historique ADD CONSTRAINT logements_loyers_historique_pkey PRIMARY KEY (id);
ALTER TABLE public.logements_sociaux_historiques ADD CONSTRAINT logements_sociaux_historiques_pkey PRIMARY KEY (pays, batiment, piece);
ALTER TABLE public.logements_sociaux_internes ADD CONSTRAINT logements_sociaux_internes_pkey PRIMARY KEY (transaction_id, bail_id);
ALTER TABLE public.permis_depots_recus ADD CONSTRAINT permis_depots_recus_pkey PRIMARY KEY (acteur, requete);
ALTER TABLE public.permis_transactions_internes ADD CONSTRAINT permis_transactions_internes_pkey PRIMARY KEY (transaction_id);
ALTER TABLE public.reservations_salle_reception ADD CONSTRAINT reservations_salle_reception_pkey PRIMARY KEY (id);
ALTER TABLE public.terrain_acquisitions_recus ADD CONSTRAINT terrain_acquisitions_recus_pkey PRIMARY KEY (acteur, requete);
ALTER TABLE public.terrain_actions_recus ADD CONSTRAINT terrain_actions_recus_pkey PRIMARY KEY (acteur, requete);
ALTER TABLE public.terrain_actions_regles ADD CONSTRAINT terrain_actions_regles_pkey PRIMARY KEY (id);
ALTER TABLE public.terrain_negociations_recus ADD CONSTRAINT terrain_negociations_recus_pkey PRIMARY KEY (acteur, requete);
ALTER TABLE public.terrain_negociations_refus ADD CONSTRAINT terrain_negociations_refus_pkey PRIMARY KEY (acteur, terrain, occupation);
ALTER TABLE public.terrain_visites_actives ADD CONSTRAINT terrain_visites_actives_pkey PRIMARY KEY (personnage_id, terrain_id);
ALTER TABLE public.terrains_etat ADD CONSTRAINT terrains_etat_pkey PRIMARY KEY (id);
ALTER TABLE public.terrains_historique_ventes ADD CONSTRAINT terrains_historique_ventes_pkey PRIMARY KEY (id);
ALTER TABLE public.terrains_referentiel ADD CONSTRAINT terrains_referentiel_pkey PRIMARY KEY (pays, ville, batiment);
ALTER TABLE public.villes ADD CONSTRAINT villes_pkey PRIMARY KEY (pays, ville);
ALTER TABLE public.villes_empreinte ADD CONSTRAINT villes_empreinte_pkey PRIMARY KEY (seul);

-- CONTRAINTES D'UNICITE
ALTER TABLE public.permis_depots_recus ADD CONSTRAINT permis_depots_recus_archive_key UNIQUE (archive);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.bne_annonces ADD CONSTRAINT bne_annonces_descriptif_check CHECK (((char_length(descriptif) >= 1) AND (char_length(descriptif) <= 600)));
ALTER TABLE public.bne_annonces ADD CONSTRAINT bne_annonces_intitule_check CHECK (((char_length(intitule) >= 1) AND (char_length(intitule) <= 80)));
ALTER TABLE public.bne_annonces ADD CONSTRAINT bne_annonces_salaire_check CHECK (((char_length(salaire) >= 1) AND (char_length(salaire) <= 60)));
ALTER TABLE public.bne_annonces ADD CONSTRAINT bne_annonces_statut_check CHECK ((statut = ANY (ARRAY['active'::text, 'retiree'::text])));
ALTER TABLE public.locations_actives ADD CONSTRAINT locations_actives_salle_reunion_non_louable CHECK ((id !~~ '%:universite:salle_reunion:%'::text));
ALTER TABLE public.locaux_loyers_referentiel ADD CONSTRAINT locaux_loyers_referentiel_prix_check CHECK ((prix >= 0));
ALTER TABLE public.logements_demandes ADD CONSTRAINT logements_demandes_statut_check CHECK ((statut = ANY (ARRAY['en_attente'::text, 'attribuee'::text, 'annulee'::text])));
ALTER TABLE public.logements_sociaux_historiques ADD CONSTRAINT logements_sociaux_historiques_loyer_check CHECK ((loyer >= 1));
ALTER TABLE public.terrain_actions_regles ADD CONSTRAINT terrain_actions_regles_id_check CHECK (id);
ALTER TABLE public.terrain_negociations_recus ADD CONSTRAINT terrain_negociations_recus_montant_check CHECK ((montant > 0));
ALTER TABLE public.terrain_negociations_refus ADD CONSTRAINT terrain_negociations_refus_montant_check CHECK ((montant > 0));
ALTER TABLE public.terrains_referentiel ADD CONSTRAINT terrains_referentiel_prix_achat_check CHECK (((prix_achat IS NULL) OR ((prix_achat >= (0)::numeric) AND (prix_achat = trunc(prix_achat)))));
ALTER TABLE public.terrains_referentiel ADD CONSTRAINT terrains_referentiel_surface_check CHECK (((surface IS NULL) OR (surface > (0)::numeric)));
ALTER TABLE public.villes_empreinte ADD CONSTRAINT villes_empreinte_seul_check CHECK (seul);

-- CLES ETRANGERES
ALTER TABLE public.terrain_visites_actives ADD CONSTRAINT terrain_visites_actives_personnage_id_fkey FOREIGN KEY (personnage_id) REFERENCES personnages_donnees(id) ON DELETE CASCADE;
ALTER TABLE public.terrain_visites_actives ADD CONSTRAINT terrain_visites_actives_terrain_id_fkey FOREIGN KEY (terrain_id) REFERENCES terrains_etat(id);
