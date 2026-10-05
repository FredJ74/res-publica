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
ALTER TABLE public.impacts_indices_attente ADD CONSTRAINT impacts_indices_attente_pkey PRIMARY KEY (id);
ALTER TABLE public.jugements ADD CONSTRAINT jugements_pkey PRIMARY KEY (id);
ALTER TABLE public.niveaux_prison ADD CONSTRAINT niveaux_prison_pkey PRIMARY KEY (id);
ALTER TABLE public.plaintes_en_cours ADD CONSTRAINT plaintes_en_cours_pkey PRIMARY KEY (id);
ALTER TABLE public.prisonniers_qhs ADD CONSTRAINT prisonniers_qhs_pkey PRIMARY KEY (id);
ALTER TABLE public.rumeurs_actives ADD CONSTRAINT rumeurs_actives_pkey PRIMARY KEY (id);
ALTER TABLE public.vols_en_attente ADD CONSTRAINT vols_en_attente_pkey PRIMARY KEY (id);

-- CONTRAINTES D'UNICITE
ALTER TABLE public.impacts_indices_attente ADD CONSTRAINT impacts_indices_attente_id_unique UNIQUE (id);
