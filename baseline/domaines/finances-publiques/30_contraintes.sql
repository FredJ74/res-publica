-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine finances publiques -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.budgets_clubs ADD CONSTRAINT budgets_clubs_pkey PRIMARY KEY (id);
ALTER TABLE public.budgets_municipaux ADD CONSTRAINT budgets_municipaux_pkey PRIMARY KEY (id);
ALTER TABLE public.budgets_nationaux ADD CONSTRAINT budgets_nationaux_pkey PRIMARY KEY (id);
ALTER TABLE public.caisses_autorites ADD CONSTRAINT caisses_autorites_pkey PRIMARY KEY (motif);
ALTER TABLE public.caisses_batiments ADD CONSTRAINT caisses_batiments_pkey PRIMARY KEY (id);
ALTER TABLE public.caisses_mouvements_clients ADD CONSTRAINT caisses_mouvements_clients_pkey PRIMARY KEY (id);
ALTER TABLE public.contributions_piete ADD CONSTRAINT contributions_piete_pkey PRIMARY KEY (id);
ALTER TABLE public.dotations_amorcage_caisses ADD CONSTRAINT dotations_amorcage_caisses_pkey PRIMARY KEY (caisse_ref);
ALTER TABLE public.fiscalite_journal ADD CONSTRAINT fiscalite_journal_pkey PRIMARY KEY (id);
ALTER TABLE public.fonds_credits_sources ADD CONSTRAINT fonds_credits_sources_pkey PRIMARY KEY (source);
ALTER TABLE public.fonds_credits_uniques ADD CONSTRAINT fonds_credits_uniques_pkey PRIMARY KEY (id);
ALTER TABLE public.fonds_debits ADD CONSTRAINT fonds_debits_pkey PRIMARY KEY (id);
ALTER TABLE public.pa_bonus_differes ADD CONSTRAINT pa_bonus_differes_pkey PRIMARY KEY (source);
ALTER TABLE public.pa_bonus_differes_empreinte ADD CONSTRAINT pa_bonus_differes_empreinte_pkey PRIMARY KEY (seul);
ALTER TABLE public.pa_bonus_hotel ADD CONSTRAINT pa_bonus_hotel_pkey PRIMARY KEY (building_id);
ALTER TABLE public.pa_credits_sources ADD CONSTRAINT pa_credits_sources_pkey PRIMARY KEY (source);
ALTER TABLE public.pa_credits_uniques ADD CONSTRAINT pa_credits_uniques_pkey PRIMARY KEY (acteur, source, reference);
ALTER TABLE public.salaires_caisses ADD CONSTRAINT salaires_caisses_pkey PRIMARY KEY (poste_id);
ALTER TABLE public.salaires_civils_declares ADD CONSTRAINT salaires_civils_declares_pkey PRIMARY KEY (cle);
ALTER TABLE public.salaires_civils_verses ADD CONSTRAINT salaires_civils_verses_pkey PRIMARY KEY (id);
ALTER TABLE public.salaires_religieux_declares ADD CONSTRAINT salaires_religieux_declares_pkey PRIMARY KEY (cle);
ALTER TABLE public.salaires_religieux_verses ADD CONSTRAINT salaires_religieux_verses_pkey PRIMARY KEY (id);

-- CONTRAINTES D'UNICITE
ALTER TABLE public.fonds_credits_uniques ADD CONSTRAINT fonds_credits_uniques_ref UNIQUE (source, reference);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.fiscalite_journal ADD CONSTRAINT fiscalite_journal_assiette_check CHECK (((assiette IS NULL) OR (assiette >= (0)::numeric)));
ALTER TABLE public.fiscalite_journal ADD CONSTRAINT fiscalite_journal_montant_check CHECK ((montant >= (0)::numeric));
ALTER TABLE public.fiscalite_journal ADD CONSTRAINT fiscalite_journal_pays_check CHECK ((pays <> ''::text));
ALTER TABLE public.fiscalite_journal ADD CONSTRAINT fiscalite_journal_personnage_check CHECK ((personnage <> ''::text));
ALTER TABLE public.fiscalite_journal ADD CONSTRAINT fiscalite_journal_type_check CHECK ((type <> ''::text));
ALTER TABLE public.fonds_debits ADD CONSTRAINT fonds_debits_montant_check CHECK ((montant > (0)::numeric));
ALTER TABLE public.pa_bonus_differes ADD CONSTRAINT pa_bonus_differes_montant_check CHECK (((montant > 0) AND (montant <= 10)));
ALTER TABLE public.pa_bonus_differes_empreinte ADD CONSTRAINT pa_bonus_differes_empreinte_seul_check CHECK (seul);
ALTER TABLE public.pa_bonus_hotel ADD CONSTRAINT pa_bonus_hotel_montant_check CHECK (((montant > 0) AND (montant <= 10)));
ALTER TABLE public.pa_credits_sources ADD CONSTRAINT pa_credits_sources_montant_check CHECK (((montant IS NULL) OR ((montant > 0) AND (montant <= 10))));
ALTER TABLE public.salaires_civils_declares ADD CONSTRAINT salaires_civils_declares_categorie_check CHECK ((categorie = ANY (ARRAY['poste'::text, 'emploi'::text, 'universel'::text])));
ALTER TABLE public.salaires_civils_declares ADD CONSTRAINT salaires_civils_declares_montant_check CHECK ((montant >= 0));
ALTER TABLE public.salaires_religieux_declares ADD CONSTRAINT salaires_religieux_declares_montant_check CHECK ((montant > 0));
