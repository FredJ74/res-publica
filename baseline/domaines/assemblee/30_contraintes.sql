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
ALTER TABLE public.assemblee_debats ADD CONSTRAINT assemblee_debats_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_disciplines ADD CONSTRAINT assemblee_disciplines_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_indemnites ADD CONSTRAINT assemblee_indemnites_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_intentions ADD CONSTRAINT assemblee_intentions_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_paroles ADD CONSTRAINT assemblee_paroles_pkey PRIMARY KEY (pays, depute);
ALTER TABLE public.assemblee_presidence_bulletins ADD CONSTRAINT assemblee_presidence_bulletins_pkey PRIMARY KEY (scrutin_id, votant);
ALTER TABLE public.assemblee_presidence_dues ADD CONSTRAINT assemblee_presidence_dues_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_presidence_scrutins ADD CONSTRAINT assemblee_presidence_scrutins_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_presidence_tirage_vu ADD CONSTRAINT assemblee_presidence_tirage_vu_pkey PRIMARY KEY (scrutin_id, personnage);
ALTER TABLE public.assemblee_propositions ADD CONSTRAINT assemblee_propositions_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_protestations ADD CONSTRAINT assemblee_protestations_pkey PRIMARY KEY (pays, depute);
ALTER TABLE public.assemblee_reports ADD CONSTRAINT assemblee_reports_pkey PRIMARY KEY (proposition_id);
ALTER TABLE public.assemblee_requetes ADD CONSTRAINT assemblee_requetes_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_sanctions_paliers ADD CONSTRAINT assemblee_sanctions_paliers_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_scrutins ADD CONSTRAINT assemblee_scrutins_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_sieges ADD CONSTRAINT assemblee_sieges_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_suspensions ADD CONSTRAINT assemblee_suspensions_pkey PRIMARY KEY (id);
ALTER TABLE public.assemblee_votes ADD CONSTRAINT assemblee_votes_pkey PRIMARY KEY (id);

-- CONTRAINTES D'UNICITE
ALTER TABLE public.assemblee_sieges ADD CONSTRAINT assemblee_sieges_pnj_id_key UNIQUE (pnj_id);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.assemblee_disciplines ADD CONSTRAINT discipline_forme_coherente CHECK ((((genre = 'rappel'::text) AND (amende = 0) AND (rappel_id IS NULL) AND (caisse_creditee IS NULL)) OR ((genre = 'sanction'::text) AND (amende > 0) AND (rappel_id IS NOT NULL) AND (caisse_creditee IS NOT NULL))));
ALTER TABLE public.assemblee_disciplines ADD CONSTRAINT discipline_genre_connu CHECK ((genre = ANY (ARRAY['rappel'::text, 'sanction'::text])));
ALTER TABLE public.assemblee_disciplines ADD CONSTRAINT discipline_motif_non_vide CHECK ((btrim(motif) <> ''::text));
ALTER TABLE public.assemblee_intentions ADD CONSTRAINT assemblee_intention_valide CHECK ((intention = ANY (ARRAY['POUR'::text, 'CONTRE'::text])));
ALTER TABLE public.assemblee_paroles ADD CONSTRAINT parole_donnee_a_une_date CHECK (((a_la_parole AND (donnee_le IS NOT NULL)) OR ((NOT a_la_parole) AND (donnee_le IS NULL))));
ALTER TABLE public.assemblee_presidence_dues ADD CONSTRAINT presidence_due_cause_connue CHECK ((cause = ANY (ARRAY['renouvellement'::text, 'deux_boycotts'::text])));
ALTER TABLE public.assemblee_presidence_dues ADD CONSTRAINT presidence_due_honoree_coherente CHECK ((((honore_le IS NULL) AND (scrutin_id IS NULL)) OR ((honore_le IS NOT NULL) AND (scrutin_id IS NOT NULL))));
ALTER TABLE public.assemblee_presidence_scrutins ADD CONSTRAINT presidence_cause_connue CHECK ((cause = ANY (ARRAY['renouvellement'::text, 'deux_boycotts'::text])));
ALTER TABLE public.assemblee_presidence_scrutins ADD CONSTRAINT presidence_clos_coherent CHECK ((((statut = 'ouvert'::text) AND (elu IS NULL) AND (clos_le IS NULL) AND (decompte IS NULL)) OR ((statut = 'clos'::text) AND (elu IS NOT NULL) AND (clos_le IS NOT NULL) AND (decompte IS NOT NULL))));
ALTER TABLE public.assemblee_presidence_scrutins ADD CONSTRAINT presidence_statut_connu CHECK ((statut = ANY (ARRAY['ouvert'::text, 'clos'::text])));
ALTER TABLE public.assemblee_propositions ADD CONSTRAINT assemblee_prop_abrogation_coherente CHECK ((((type = 'abrogation'::text) AND (loi_cible_id IS NOT NULL)) OR ((type <> 'abrogation'::text) AND (loi_cible_id IS NULL))));
ALTER TABLE public.assemblee_propositions ADD CONSTRAINT assemblee_prop_categorie_coherente CHECK ((((type = 'mecanique'::text) AND (categorie IS NOT NULL)) OR ((type <> 'mecanique'::text) AND (categorie IS NULL))));
ALTER TABLE public.assemblee_propositions ADD CONSTRAINT assemblee_prop_statut_valide CHECK ((statut = ANY (ARRAY['debat'::text, 'session'::text, 'adoptee'::text, 'rejetee'::text, 'renvoyee'::text, 'retiree'::text, 'abrogee'::text])));
ALTER TABLE public.assemblee_propositions ADD CONSTRAINT assemblee_prop_type_valide CHECK ((type = ANY (ARRAY['rp'::text, 'mecanique'::text, 'abrogation'::text])));
ALTER TABLE public.assemblee_protestations ADD CONSTRAINT protestation_motif_si_qualifie CHECK (((qualifie AND (motif_qualifiant IS NOT NULL)) OR ((NOT qualifie) AND (motif_qualifiant IS NULL))));
ALTER TABLE public.assemblee_reports ADD CONSTRAINT report_repousse_vraiment CHECK ((nouvelle_cloture > ancienne_cloture));
ALTER TABLE public.assemblee_sanctions_paliers ADD CONSTRAINT assemblee_sanctions_paliers_palier_check CHECK ((palier >= 1));
ALTER TABLE public.assemblee_scrutins ADD CONSTRAINT assemblee_scrutin_resultat_valide CHECK ((resultat = ANY (ARRAY['ADOPTEE'::text, 'REJETEE'::text, 'RENVOYEE'::text])));
ALTER TABLE public.assemblee_suspensions ADD CONSTRAINT suspension_cause_connue CHECK ((cause = ANY (ARRAY['boycott'::text, 'presidence'::text])));
ALTER TABLE public.assemblee_votes ADD CONSTRAINT assemblee_vote_valide CHECK ((choix = ANY (ARRAY['POUR'::text, 'CONTRE'::text, 'ABSTENTION'::text])));

-- CLES ETRANGERES
ALTER TABLE public.assemblee_disciplines ADD CONSTRAINT assemblee_disciplines_rappel_id_fkey FOREIGN KEY (rappel_id) REFERENCES assemblee_disciplines(id);
ALTER TABLE public.assemblee_intentions ADD CONSTRAINT assemblee_intentions_proposition_id_fkey FOREIGN KEY (proposition_id) REFERENCES assemblee_propositions(id) ON DELETE CASCADE;
ALTER TABLE public.assemblee_intentions ADD CONSTRAINT assemblee_intentions_siege_id_fkey FOREIGN KEY (siege_id) REFERENCES assemblee_sieges(id);
ALTER TABLE public.assemblee_presidence_bulletins ADD CONSTRAINT assemblee_presidence_bulletins_scrutin_id_fkey FOREIGN KEY (scrutin_id) REFERENCES assemblee_presidence_scrutins(id);
ALTER TABLE public.assemblee_presidence_dues ADD CONSTRAINT assemblee_presidence_dues_scrutin_id_fkey FOREIGN KEY (scrutin_id) REFERENCES assemblee_presidence_scrutins(id);
ALTER TABLE public.assemblee_presidence_tirage_vu ADD CONSTRAINT assemblee_presidence_tirage_vu_scrutin_id_fkey FOREIGN KEY (scrutin_id) REFERENCES assemblee_presidence_scrutins(id);
ALTER TABLE public.assemblee_protestations ADD CONSTRAINT assemblee_protestations_discipline_id_fkey FOREIGN KEY (discipline_id) REFERENCES assemblee_disciplines(id);
ALTER TABLE public.assemblee_reports ADD CONSTRAINT assemblee_reports_proposition_id_fkey FOREIGN KEY (proposition_id) REFERENCES assemblee_propositions(id);
ALTER TABLE public.assemblee_scrutins ADD CONSTRAINT assemblee_scrutins_proposition_id_fkey FOREIGN KEY (proposition_id) REFERENCES assemblee_propositions(id) ON DELETE CASCADE;
ALTER TABLE public.assemblee_votes ADD CONSTRAINT assemblee_votes_proposition_id_fkey FOREIGN KEY (proposition_id) REFERENCES assemblee_propositions(id) ON DELETE CASCADE;
