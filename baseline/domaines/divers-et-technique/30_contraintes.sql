-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine divers et technique -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.ambassades_ouvertes ADD CONSTRAINT ambassades_ouvertes_pkey PRIMARY KEY (id);
ALTER TABLE public.cron_journal ADD CONSTRAINT cron_journal_pkey PRIMARY KEY (id);
ALTER TABLE public.etats_urgence ADD CONSTRAINT etats_urgence_pkey PRIMARY KEY (country);
ALTER TABLE public.evenements_globaux ADD CONSTRAINT evenements_globaux_pkey PRIMARY KEY (id);
ALTER TABLE public.propositions_diplomatiques ADD CONSTRAINT propositions_diplomatiques_pkey PRIMARY KEY (id);
ALTER TABLE public.registre_ventes_armes ADD CONSTRAINT registre_ventes_armes_pkey PRIMARY KEY (id);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.cron_journal ADD CONSTRAINT cron_journal_statut_check CHECK ((statut = ANY (ARRAY['demarree'::text, 'ok'::text, 'echec'::text, 'ignoree'::text])));
