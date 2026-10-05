-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine postes et institutions -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.nominations_en_attente ADD CONSTRAINT nominations_en_attente_pkey PRIMARY KEY (id);
ALTER TABLE public.nominations_poste_attente ADD CONSTRAINT nominations_poste_attente_pkey PRIMARY KEY (id);
ALTER TABLE public.postes_attribues ADD CONSTRAINT postes_attribues_pkey PRIMARY KEY (id);
ALTER TABLE public.postes_electifs_regles ADD CONSTRAINT postes_electifs_regles_pkey PRIMARY KEY (poste_id);
ALTER TABLE public.postes_nommes_regles ADD CONSTRAINT postes_nommes_regles_pkey PRIMARY KEY (poste_id);
ALTER TABLE public.postes_nommes_regles_empreinte ADD CONSTRAINT postes_nommes_regles_empreinte_pkey PRIMARY KEY (seul);
ALTER TABLE public.titulaires_pnj ADD CONSTRAINT titulaires_pnj_pkey PRIMARY KEY (id);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.postes_nommes_regles ADD CONSTRAINT postes_nommes_regles_scope_check CHECK ((scope = ANY (ARRAY['pays'::text, 'ville'::text])));
ALTER TABLE public.postes_nommes_regles_empreinte ADD CONSTRAINT postes_nommes_regles_empreinte_seul_check CHECK (seul);
