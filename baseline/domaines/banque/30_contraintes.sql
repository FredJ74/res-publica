-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine banque -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.biens_saisis_helvetia ADD CONSTRAINT biens_saisis_helvetia_pkey PRIMARY KEY (id);
ALTER TABLE public.bnr_refinancements_helvetia ADD CONSTRAINT bnr_refinancements_helvetia_pkey PRIMARY KEY (id);
ALTER TABLE public.compromis_historique ADD CONSTRAINT compromis_historique_pkey PRIMARY KEY (id);
ALTER TABLE public.comptes_bancaires ADD CONSTRAINT comptes_bancaires_pkey PRIMARY KEY (id);
ALTER TABLE public.obligations_helvetia ADD CONSTRAINT obligations_helvetia_pkey PRIMARY KEY (id);
ALTER TABLE public.placements_bancaires ADD CONSTRAINT placements_bancaires_pkey PRIMARY KEY (id);
ALTER TABLE public.prets ADD CONSTRAINT prets_pkey PRIMARY KEY (id);
ALTER TABLE public.prets_bancaires ADD CONSTRAINT prets_bancaires_pkey PRIMARY KEY (id);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.comptes_bancaires ADD CONSTRAINT comptes_bancaires_banque_check CHECK ((banque = ANY (ARRAY['nationale'::text, 'helvetia'::text])));
ALTER TABLE public.comptes_bancaires ADD CONSTRAINT comptes_bancaires_pays_check CHECK ((pays <> ''::text));
ALTER TABLE public.comptes_bancaires ADD CONSTRAINT comptes_bancaires_personnage_check CHECK ((personnage <> ''::text));
ALTER TABLE public.comptes_bancaires ADD CONSTRAINT comptes_bancaires_solde_check CHECK ((solde >= (0)::numeric));
ALTER TABLE public.placements_bancaires ADD CONSTRAINT placement_actif_non_vide CHECK (((statut <> 'actif'::text) OR (montant > (0)::numeric)));
ALTER TABLE public.placements_bancaires ADD CONSTRAINT placement_national_visible_check CHECK (((NOT ((banque = 'nationale'::text) AND (type = 'terme'::text))) OR (visible_fiscalement = true)));
ALTER TABLE public.placements_bancaires ADD CONSTRAINT placements_bancaires_banque_check CHECK ((banque = ANY (ARRAY['nationale'::text, 'helvetia'::text])));
ALTER TABLE public.placements_bancaires ADD CONSTRAINT placements_bancaires_montant_check CHECK ((montant >= (0)::numeric));
ALTER TABLE public.placements_bancaires ADD CONSTRAINT placements_bancaires_pays_check CHECK ((pays <> ''::text));
ALTER TABLE public.placements_bancaires ADD CONSTRAINT placements_bancaires_personnage_check CHECK ((personnage <> ''::text));
ALTER TABLE public.placements_bancaires ADD CONSTRAINT placements_bancaires_statut_check CHECK ((statut = ANY (ARRAY['actif'::text, 'retire'::text, 'resolu'::text])));
ALTER TABLE public.placements_bancaires ADD CONSTRAINT placements_bancaires_type_check CHECK ((type = ANY (ARRAY['terme'::text, 'declare'::text, 'offshore'::text])));
ALTER TABLE public.placements_bancaires ADD CONSTRAINT placements_montant_final_check CHECK (((montant_final IS NULL) OR (montant_final >= (0)::numeric)));
