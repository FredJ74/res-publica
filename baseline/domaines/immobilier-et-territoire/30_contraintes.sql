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
ALTER TABLE public.batiments_etat ADD CONSTRAINT batiments_etat_pkey PRIMARY KEY (id);
ALTER TABLE public.batiments_fermes ADD CONSTRAINT batiments_fermes_pkey PRIMARY KEY (id);
ALTER TABLE public.dossiers_urbanisme ADD CONSTRAINT dossiers_urbanisme_pkey PRIMARY KEY (id);
ALTER TABLE public.locations_actives ADD CONSTRAINT locations_actives_pkey PRIMARY KEY (id);
ALTER TABLE public.locations_archives ADD CONSTRAINT locations_archives_pkey PRIMARY KEY (id);
ALTER TABLE public.logements_attributions_historique ADD CONSTRAINT logements_attributions_historique_pkey PRIMARY KEY (id);
ALTER TABLE public.logements_demandes ADD CONSTRAINT logements_demandes_pkey PRIMARY KEY (id);
ALTER TABLE public.reservations_salle_reception ADD CONSTRAINT reservations_salle_reception_pkey PRIMARY KEY (id);
ALTER TABLE public.terrains_etat ADD CONSTRAINT terrains_etat_pkey PRIMARY KEY (id);
ALTER TABLE public.terrains_historique_ventes ADD CONSTRAINT terrains_historique_ventes_pkey PRIMARY KEY (id);
ALTER TABLE public.villes ADD CONSTRAINT villes_pkey PRIMARY KEY (pays, ville);
ALTER TABLE public.villes_empreinte ADD CONSTRAINT villes_empreinte_pkey PRIMARY KEY (seul);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.logements_demandes ADD CONSTRAINT logements_demandes_statut_check CHECK ((statut = ANY (ARRAY['en_attente'::text, 'attribuee'::text, 'annulee'::text])));
ALTER TABLE public.villes_empreinte ADD CONSTRAINT villes_empreinte_seul_check CHECK (seul);
