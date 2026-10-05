-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine assemblee -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.assemblee_catalogue_illegal ADD CONSTRAINT assemblee_catalogue_illegal_pkey PRIMARY KEY (circuit, ref);
ALTER TABLE public.assemblee_categories_interdiction ADD CONSTRAINT assemblee_categories_interdiction_pkey PRIMARY KEY (categorie);
ALTER TABLE public.assemblee_indemnites ADD CONSTRAINT assemblee_indemnites_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_intentions ADD CONSTRAINT assemblee_intentions_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_propositions ADD CONSTRAINT assemblee_propositions_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_requetes ADD CONSTRAINT assemblee_requetes_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_sanctions_paliers ADD CONSTRAINT assemblee_sanctions_paliers_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_scrutins ADD CONSTRAINT assemblee_scrutins_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_sieges ADD CONSTRAINT assemblee_sieges_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_votes ADD CONSTRAINT assemblee_votes_pkey PRIMARY KEY (id);

-- CONTRAINTES D'UNICITE
ALTER TABLE public.assemblee_sieges ADD CONSTRAINT assemblee_sieges_pnj_id_key UNIQUE (pnj_id);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.assemblee_intentions ADD CONSTRAINT assemblee_intention_valide CHECK ((intention = ANY (ARRAY['POUR'::text, 'CONTRE'::text])));
ALTER TABLE public.assemblee_propositions ADD CONSTRAINT assemblee_prop_abrogation_coherente CHECK ((((type = 'abrogation'::text) AND (loi_cible_id IS NOT NULL)) OR ((type <> 'abrogation'::text) AND (loi_cible_id IS NULL))));
ALTER TABLE public.assemblee_propositions ADD CONSTRAINT assemblee_prop_categorie_coherente CHECK ((((type = 'mecanique'::text) AND (categorie IS NOT NULL)) OR ((type <> 'mecanique'::text) AND (categorie IS NULL))));
ALTER TABLE public.assemblee_propositions ADD CONSTRAINT assemblee_prop_statut_valide CHECK ((statut = ANY (ARRAY['debat'::text, 'session'::text, 'adoptee'::text, 'rejetee'::text, 'renvoyee'::text, 'retiree'::text, 'abrogee'::text])));
ALTER TABLE public.assemblee_propositions ADD CONSTRAINT assemblee_prop_type_valide CHECK ((type = ANY (ARRAY['rp'::text, 'mecanique'::text, 'abrogation'::text])));
ALTER TABLE public.assemblee_sanctions_paliers ADD CONSTRAINT assemblee_sanctions_paliers_palier_check CHECK ((palier >= 1));
ALTER TABLE public.assemblee_scrutins ADD CONSTRAINT assemblee_scrutin_resultat_valide CHECK ((resultat = ANY (ARRAY['ADOPTEE'::text, 'REJETEE'::text, 'RENVOYEE'::text])));
ALTER TABLE public.assemblee_votes ADD CONSTRAINT assemblee_vote_valide CHECK ((choix = ANY (ARRAY['POUR'::text, 'CONTRE'::text, 'ABSTENTION'::text])));

-- CLES ETRANGERES
ALTER TABLE public.assemblee_intentions ADD CONSTRAINT assemblee_intentions_proposition_id_fkey FOREIGN KEY (proposition_id) REFERENCES assemblee_propositions(id) ON DELETE CASCADE;
ALTER TABLE public.assemblee_intentions ADD CONSTRAINT assemblee_intentions_siege_id_fkey FOREIGN KEY (siege_id) REFERENCES assemblee_sieges(id);
ALTER TABLE public.assemblee_scrutins ADD CONSTRAINT assemblee_scrutins_proposition_id_fkey FOREIGN KEY (proposition_id) REFERENCES assemblee_propositions(id) ON DELETE CASCADE;
ALTER TABLE public.assemblee_votes ADD CONSTRAINT assemblee_votes_proposition_id_fkey FOREIGN KEY (proposition_id) REFERENCES assemblee_propositions(id) ON DELETE CASCADE;
