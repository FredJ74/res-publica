-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine politique et elections -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.candidatures ADD CONSTRAINT candidatures_pkey PRIMARY KEY (id);
ALTER TABLE public.cycles_electoraux ADD CONSTRAINT cycles_electoraux_pkey PRIMARY KEY (id);
ALTER TABLE public.demandes_manifestation ADD CONSTRAINT demandes_manifestation_pkey PRIMARY KEY (id);
ALTER TABLE public.elections_tracts_pnj ADD CONSTRAINT elections_tracts_pnj_pkey PRIMARY KEY (id);
ALTER TABLE public.fraudes_electorales ADD CONSTRAINT fraudes_electorales_pkey PRIMARY KEY (id);
ALTER TABLE public.greves_generales ADD CONSTRAINT greves_generales_pkey PRIMARY KEY (id);
ALTER TABLE public.indices_villes ADD CONSTRAINT indices_villes_pkey PRIMARY KEY (id);
ALTER TABLE public.mandats_maires_archives ADD CONSTRAINT mandats_maires_archives_pkey PRIMARY KEY (id);
ALTER TABLE public.militants_recrutes ADD CONSTRAINT militants_recrutes_pkey PRIMARY KEY (id);
ALTER TABLE public.rp_epoques ADD CONSTRAINT rp_epoques_pkey PRIMARY KEY (pays);
ALTER TABLE public.rp_transitions ADD CONSTRAINT rp_transitions_pkey PRIMARY KEY (cle);
ALTER TABLE public.votes_confiance ADD CONSTRAINT votes_confiance_pkey PRIMARY KEY (id);
ALTER TABLE public.votes_confiance_bulletins ADD CONSTRAINT votes_confiance_bulletins_pkey PRIMARY KEY (id);
ALTER TABLE public.votes_electoraux ADD CONSTRAINT votes_electoraux_pkey PRIMARY KEY (id);

-- CONTRAINTES D'UNICITE
ALTER TABLE public.elections_tracts_pnj ADD CONSTRAINT elections_tracts_pnj_cycle_id_tour_pnj_cle_key UNIQUE (cycle_id, tour, pnj_cle);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.elections_tracts_pnj ADD CONSTRAINT elections_tracts_pnj_effet_check CHECK ((effet = ANY (ARRAY[1, 0, '-1'::integer])));
ALTER TABLE public.elections_tracts_pnj ADD CONSTRAINT elections_tracts_pnj_sens_check CHECK ((sens = ANY (ARRAY[1, '-1'::integer])));
ALTER TABLE public.fraudes_electorales ADD CONSTRAINT fraudes_electorales_etat_check CHECK ((etat = ANY (ARRAY['non_revelee'::text, 'revelee'::text])));
ALTER TABLE public.fraudes_electorales ADD CONSTRAINT fraudes_electorales_type_check CHECK ((type = ANY (ARRAY['falsification_listes'::text, 'bourrage_urnes'::text, 'trucage_depouillement'::text])));
