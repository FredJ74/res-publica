-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine personnage et presence -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.ambassades_asiles ADD CONSTRAINT ambassades_asiles_pkey PRIMARY KEY (id);
ALTER TABLE public.ambassades_audiences ADD CONSTRAINT ambassades_audiences_pkey PRIMARY KEY (id);
ALTER TABLE public.contacts_organisations ADD CONSTRAINT contacts_organisations_pkey PRIMARY KEY (joueur, passeur, type_organisation);
ALTER TABLE public.contacts_organisations_passeurs ADD CONSTRAINT contacts_organisations_passeurs_pkey PRIMARY KEY (passeur, type_organisation);
ALTER TABLE public.demandes_mariage ADD CONSTRAINT demandes_mariage_pkey PRIMARY KEY (id);
ALTER TABLE public.demandes_naturalisation ADD CONSTRAINT demandes_naturalisation_pkey PRIMARY KEY (id);
ALTER TABLE public.dons_en_attente ADD CONSTRAINT dons_en_attente_pkey PRIMARY KEY (id);
ALTER TABLE public.dons_requetes ADD CONSTRAINT dons_requetes_pkey PRIMARY KEY (requete);
ALTER TABLE public.escort_evenements_commerciaux ADD CONSTRAINT escort_evenements_commerciaux_pkey PRIMARY KEY (id);
ALTER TABLE public.escorts_agences ADD CONSTRAINT escorts_agences_pkey PRIMARY KEY (pays);
ALTER TABLE public.escorts_catalogue ADD CONSTRAINT escorts_catalogue_pkey PRIMARY KEY (escort_id);
ALTER TABLE public.etat_civil_deces ADD CONSTRAINT etat_civil_deces_pkey PRIMARY KEY (id);
ALTER TABLE public.etat_civil_naissances ADD CONSTRAINT etat_civil_naissances_pkey PRIMARY KEY (id);
ALTER TABLE public.fiche_hausses_observees ADD CONSTRAINT fiche_hausses_observees_pkey PRIMARY KEY (id);
ALTER TABLE public.fiche_inventaire_observe ADD CONSTRAINT fiche_inventaire_observe_pkey PRIMARY KEY (id);
ALTER TABLE public.historique_deplacements ADD CONSTRAINT historique_deplacements_pkey PRIMARY KEY (id);
ALTER TABLE public.indices_diplomatiques ADD CONSTRAINT indices_diplomatiques_pkey PRIMARY KEY (pays);
ALTER TABLE public.indices_diplomatiques_journal ADD CONSTRAINT indices_diplomatiques_journal_pkey PRIMARY KEY (id);
ALTER TABLE public.invitations_diner ADD CONSTRAINT invitations_diner_pkey PRIMARY KEY (id);
ALTER TABLE public.mariages ADD CONSTRAINT mariages_pkey PRIMARY KEY (id);
ALTER TABLE public.objets_abandonnes ADD CONSTRAINT objets_abandonnes_pkey PRIMARY KEY (id);
ALTER TABLE public.objets_recus ADD CONSTRAINT objets_recus_pkey PRIMARY KEY (id);
ALTER TABLE public.organisations ADD CONSTRAINT organisations_pkey PRIMARY KEY (id);
ALTER TABLE public.personnages_donnees ADD CONSTRAINT personnages_pkey PRIMARY KEY (id);
ALTER TABLE public.personnages_qualifications ADD CONSTRAINT personnages_qualifications_pkey PRIMARY KEY (personnage, qualification);
ALTER TABLE public.personnages_supprimes ADD CONSTRAINT personnages_supprimes_pkey PRIMARY KEY (archive_id);
ALTER TABLE public.presences ADD CONSTRAINT presences_pkey PRIMARY KEY (name);
ALTER TABLE public.qualifications ADD CONSTRAINT qualifications_pkey PRIMARY KEY (id);
ALTER TABLE public.quetes_actives ADD CONSTRAINT quetes_actives_pkey PRIMARY KEY (id);
ALTER TABLE public.reconciliation_fantomes ADD CONSTRAINT reconciliation_fantomes_pkey PRIMARY KEY (user_id);
ALTER TABLE public.regularisations_fiche ADD CONSTRAINT regularisations_fiche_pkey PRIMARY KEY (reference);
ALTER TABLE public.souvenirs_accueil ADD CONSTRAINT souvenirs_accueil_pkey PRIMARY KEY (id);
ALTER TABLE public.successions ADD CONSTRAINT successions_pkey PRIMARY KEY (id);
ALTER TABLE public.testaments ADD CONSTRAINT testaments_pkey PRIMARY KEY (id);
ALTER TABLE public.tournees ADD CONSTRAINT tournees_pkey PRIMARY KEY (id);
ALTER TABLE public.universite_cursus ADD CONSTRAINT universite_cursus_pkey PRIMARY KEY (id);
ALTER TABLE public.universite_cursus_jalons ADD CONSTRAINT universite_cursus_jalons_pkey PRIMARY KEY (id);
ALTER TABLE public.universite_inscriptions ADD CONSTRAINT universite_inscriptions_pkey PRIMARY KEY (id);
ALTER TABLE public.universite_jalons_accomplis ADD CONSTRAINT universite_jalons_accomplis_pkey PRIMARY KEY (inscription, jalon);

-- CONTRAINTES D'UNICITE
ALTER TABLE public.escorts_catalogue ADD CONSTRAINT escorts_catalogue_pays_nom_key UNIQUE (pays, nom);
ALTER TABLE public.personnages_donnees ADD CONSTRAINT personnages_name_key UNIQUE (name);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.ambassades_asiles ADD CONSTRAINT ambassades_asiles_check CHECK (((statut = 'demandee'::text) OR (decide_le IS NOT NULL)));
ALTER TABLE public.ambassades_asiles ADD CONSTRAINT ambassades_asiles_empire_check CHECK ((empire = ANY (ARRAY['khalija'::text, 'soviet'::text, 'narco'::text])));
ALTER TABLE public.ambassades_asiles ADD CONSTRAINT ambassades_asiles_statut_check CHECK ((statut = ANY (ARRAY['demandee'::text, 'accorde'::text, 'refuse'::text])));
ALTER TABLE public.ambassades_audiences ADD CONSTRAINT ambassades_audiences_check CHECK (((ambassadeur_pj IS NOT NULL) OR (accord_prevu_le IS NOT NULL)));
ALTER TABLE public.ambassades_audiences ADD CONSTRAINT ambassades_audiences_check1 CHECK (((statut = 'demandee'::text) OR ((accordee_le IS NOT NULL) AND (expire_le IS NOT NULL))));
ALTER TABLE public.ambassades_audiences ADD CONSTRAINT ambassades_audiences_empire_check CHECK ((empire = ANY (ARRAY['khalija'::text, 'soviet'::text, 'narco'::text])));
ALTER TABLE public.ambassades_audiences ADD CONSTRAINT ambassades_audiences_statut_check CHECK ((statut = ANY (ARRAY['demandee'::text, 'accordee'::text, 'expiree'::text])));
ALTER TABLE public.escort_evenements_commerciaux ADD CONSTRAINT escort_evenements_commerciaux_type_evenement_check CHECK ((type_evenement = ANY (ARRAY['embauche'::text, 'prestation'::text])));
ALTER TABLE public.escorts_catalogue ADD CONSTRAINT escorts_catalogue_genre_check CHECK ((genre = ANY (ARRAY['F'::text, 'H'::text])));
ALTER TABLE public.indices_diplomatiques ADD CONSTRAINT indices_diplomatiques_pays_check CHECK ((pays = ANY (ARRAY['republic'::text, 'narco'::text, 'soviet'::text, 'khalija'::text])));
ALTER TABLE public.indices_diplomatiques ADD CONSTRAINT indices_diplomatiques_valeur_check CHECK (((valeur >= 0) AND (valeur <= 100)));
ALTER TABLE public.personnages_qualifications ADD CONSTRAINT personnages_qualifications_source_check CHECK ((source = ANY (ARRAY['creation'::text, 'autre'::text])));
ALTER TABLE public.successions ADD CONSTRAINT successions_statut_check CHECK ((statut = ANY (ARRAY['en_attente'::text, 'resolue'::text])));
ALTER TABLE public.testaments ADD CONSTRAINT testaments_statut_check CHECK ((statut = ANY (ARRAY['actif'::text, 'remplace'::text, 'revoque'::text, 'execute'::text])));
ALTER TABLE public.tournees ADD CONSTRAINT tournees_statut_check CHECK ((statut = ANY (ARRAY['en_attente'::text, 'en_resolution'::text, 'resolue'::text, 'expiree'::text, 'annulee'::text])));
ALTER TABLE public.universite_cursus ADD CONSTRAINT universite_cursus_cout_fr_check CHECK ((cout_fr >= 0));
ALTER TABLE public.universite_cursus ADD CONSTRAINT universite_cursus_cout_pa_check CHECK ((cout_pa >= 0));
ALTER TABLE public.universite_cursus ADD CONSTRAINT universite_cursus_semaines_theoriques_check CHECK ((semaines_theoriques > 0));
ALTER TABLE public.universite_cursus_jalons ADD CONSTRAINT universite_cursus_jalons_genre_check CHECK ((genre = ANY (ARRAY['universite'::text, 'terrain'::text])));
ALTER TABLE public.universite_cursus_jalons ADD CONSTRAINT universite_cursus_jalons_rang_check CHECK ((rang >= 1));
ALTER TABLE public.universite_cursus_jalons ADD CONSTRAINT universite_jalon_terrain_porte_un_lieu CHECK (((genre <> 'terrain'::text) OR (batiment IS NOT NULL)));
ALTER TABLE public.universite_inscriptions ADD CONSTRAINT universite_clos_coherent CHECK ((((statut = 'en_cours'::text) AND (clos_le IS NULL)) OR ((statut <> 'en_cours'::text) AND (clos_le IS NOT NULL))));
ALTER TABLE public.universite_inscriptions ADD CONSTRAINT universite_inscriptions_semaines_theoriques_check CHECK ((semaines_theoriques > 0));
ALTER TABLE public.universite_inscriptions ADD CONSTRAINT universite_inscriptions_statut_check CHECK ((statut = ANY (ARRAY['en_cours'::text, 'diplome'::text, 'abandonne'::text, 'expire'::text])));
ALTER TABLE public.universite_inscriptions ADD CONSTRAINT universite_limite_apres_fin_theorique CHECK ((limite_le > fin_theorique_le));

-- CLES ETRANGERES
ALTER TABLE public.personnages_donnees ADD CONSTRAINT personnages_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.personnages_qualifications ADD CONSTRAINT personnages_qualifications_qualification_fkey FOREIGN KEY (qualification) REFERENCES qualifications(id);
ALTER TABLE public.universite_cursus ADD CONSTRAINT universite_cursus_carriere_fkey FOREIGN KEY (carriere) REFERENCES carrieres(id);
ALTER TABLE public.universite_cursus_jalons ADD CONSTRAINT universite_cursus_jalons_cursus_fkey FOREIGN KEY (cursus) REFERENCES universite_cursus(id) ON DELETE CASCADE;
ALTER TABLE public.universite_inscriptions ADD CONSTRAINT universite_inscriptions_cursus_fkey FOREIGN KEY (cursus) REFERENCES universite_cursus(id);
ALTER TABLE public.universite_jalons_accomplis ADD CONSTRAINT universite_jalons_accomplis_inscription_fkey FOREIGN KEY (inscription) REFERENCES universite_inscriptions(id) ON DELETE CASCADE;
ALTER TABLE public.universite_jalons_accomplis ADD CONSTRAINT universite_jalons_accomplis_jalon_fkey FOREIGN KEY (jalon) REFERENCES universite_cursus_jalons(id);
