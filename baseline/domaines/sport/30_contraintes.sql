-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine sport -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.championnat ADD CONSTRAINT championnat_pkey PRIMARY KEY (id);
ALTER TABLE public.championnat_tentatives ADD CONSTRAINT championnat_tentatives_pkey PRIMARY KEY (id);
ALTER TABLE public.clubs_football ADD CONSTRAINT clubs_football_pkey PRIMARY KEY (id);
ALTER TABLE public.clubs_sportifs_regles ADD CONSTRAINT clubs_sportifs_regles_pkey PRIMARY KEY (club_id);
ALTER TABLE public.entrainements_football ADD CONSTRAINT entrainements_football_pkey PRIMARY KEY (id);
ALTER TABLE public.football_primes_versees ADD CONSTRAINT football_primes_versees_pkey PRIMARY KEY (reference);
ALTER TABLE public.paris_sportifs ADD CONSTRAINT paris_sportifs_pkey PRIMARY KEY (id);
ALTER TABLE public.presidents_clubs ADD CONSTRAINT presidents_clubs_pkey PRIMARY KEY (id);
ALTER TABLE public.transferts_clubs ADD CONSTRAINT transferts_clubs_pkey PRIMARY KEY (id);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.entrainements_football ADD CONSTRAINT entrainements_football_stat_check CHECK ((stat = ANY (ARRAY['defense'::text, 'technique'::text, 'endurance'::text])));
