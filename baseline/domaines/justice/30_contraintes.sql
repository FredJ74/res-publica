-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.actions_tracables ADD CONSTRAINT actions_tracables_pkey PRIMARY KEY (id);
ALTER TABLE public.demandes_grace ADD CONSTRAINT demandes_grace_pkey PRIMARY KEY (id);
ALTER TABLE public.detentions ADD CONSTRAINT detentions_pkey PRIMARY KEY (id);
ALTER TABLE public.dossiers_judiciaires_actes ADD CONSTRAINT dossiers_judiciaires_actes_pkey PRIMARY KEY (id);
ALTER TABLE public.dossiers_judiciaires_actes_types ADD CONSTRAINT dossiers_judiciaires_actes_types_pkey PRIMARY KEY (type);
ALTER TABLE public.impacts_indices_attente ADD CONSTRAINT impacts_indices_attente_pkey PRIMARY KEY (id);
ALTER TABLE public.infractions ADD CONSTRAINT infractions_pkey PRIMARY KEY (id);
ALTER TABLE public.infractions_alias ADD CONSTRAINT infractions_alias_pkey PRIMARY KEY (alias);
ALTER TABLE public.infractions_categories ADD CONSTRAINT infractions_categories_pkey PRIMARY KEY (id);
ALTER TABLE public.infractions_empreinte ADD CONSTRAINT infractions_empreinte_pkey PRIMARY KEY (seul);
ALTER TABLE public.jugements ADD CONSTRAINT jugements_pkey PRIMARY KEY (id);
ALTER TABLE public.niveaux_prison ADD CONSTRAINT niveaux_prison_pkey PRIMARY KEY (id);
ALTER TABLE public.plaintes_en_cours ADD CONSTRAINT plaintes_en_cours_pkey PRIMARY KEY (id);
ALTER TABLE public.prisonniers_qhs ADD CONSTRAINT prisonniers_qhs_pkey PRIMARY KEY (id);
ALTER TABLE public.rumeurs_actives ADD CONSTRAINT rumeurs_actives_pkey PRIMARY KEY (id);
ALTER TABLE public.vols_en_attente ADD CONSTRAINT vols_en_attente_pkey PRIMARY KEY (id);

-- CONTRAINTES D'UNICITE
ALTER TABLE public.dossiers_judiciaires_actes ADD CONSTRAINT dossiers_actes_un_rang_par_affaire UNIQUE (affaire, rang);
ALTER TABLE public.impacts_indices_attente ADD CONSTRAINT impacts_indices_attente_id_unique UNIQUE (id);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.dossiers_judiciaires_actes ADD CONSTRAINT dossiers_judiciaires_actes_rang_check CHECK ((rang >= 1));
ALTER TABLE public.dossiers_judiciaires_actes_types ADD CONSTRAINT dossiers_judiciaires_actes_types_pose_par_check CHECK ((pose_par = ANY (ARRAY['plaignant'::text, 'police'::text, 'parquet'::text, 'juge'::text, 'serveur'::text])));
ALTER TABLE public.infractions ADD CONSTRAINT infractions_amende_reference_check CHECK ((amende_reference >= 0));
ALTER TABLE public.infractions ADD CONSTRAINT infractions_detect_rate_check CHECK (((detect_rate IS NULL) OR ((detect_rate >= 0) AND (detect_rate <= 100))));
ALTER TABLE public.infractions ADD CONSTRAINT infractions_jours_reference_check CHECK ((jours_reference >= 1));
ALTER TABLE public.infractions_alias ADD CONSTRAINT infractions_alias_pas_sur_soi CHECK ((alias <> canonique));
ALTER TABLE public.infractions_categories ADD CONSTRAINT infractions_categories_amende_reference_check CHECK ((amende_reference >= 0));
ALTER TABLE public.infractions_categories ADD CONSTRAINT infractions_categories_jours_reference_check CHECK ((jours_reference >= 1));
ALTER TABLE public.infractions_empreinte ADD CONSTRAINT infractions_empreinte_seul_check CHECK (seul);

-- CLES ETRANGERES
ALTER TABLE public.dossiers_judiciaires_actes ADD CONSTRAINT dossiers_judiciaires_actes_qualif_apres_fkey FOREIGN KEY (qualif_apres) REFERENCES infractions(id);
ALTER TABLE public.dossiers_judiciaires_actes ADD CONSTRAINT dossiers_judiciaires_actes_qualif_avant_fkey FOREIGN KEY (qualif_avant) REFERENCES infractions(id);
ALTER TABLE public.dossiers_judiciaires_actes ADD CONSTRAINT dossiers_judiciaires_actes_type_fkey FOREIGN KEY (type) REFERENCES dossiers_judiciaires_actes_types(type);
ALTER TABLE public.infractions ADD CONSTRAINT infractions_categorie_fkey FOREIGN KEY (categorie) REFERENCES infractions_categories(id);
ALTER TABLE public.infractions_alias ADD CONSTRAINT infractions_alias_canonique_fkey FOREIGN KEY (canonique) REFERENCES infractions(id);
