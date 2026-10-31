-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine presse -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.calomnies_actes ADD CONSTRAINT calomnies_actes_pkey PRIMARY KEY (id);
ALTER TABLE public.chronique_nationale ADD CONSTRAINT chronique_nationale_pkey PRIMARY KEY (id);
ALTER TABLE public.corruptions_presse ADD CONSTRAINT corruptions_presse_pkey PRIMARY KEY (id);
ALTER TABLE public.fuites_journalistiques ADD CONSTRAINT fuites_journalistiques_pkey PRIMARY KEY (id);
ALTER TABLE public.groupes_presse ADD CONSTRAINT groupes_presse_pkey PRIMARY KEY (id);
ALTER TABLE public.interviews_jodie ADD CONSTRAINT interviews_jodie_pkey PRIMARY KEY (id);
ALTER TABLE public.journal_articles_en_attente ADD CONSTRAINT journal_articles_en_attente_pkey PRIMARY KEY (id);
ALTER TABLE public.journal_editions ADD CONSTRAINT journal_editions_pkey PRIMARY KEY (id);
ALTER TABLE public.journal_ventes_lectures ADD CONSTRAINT journal_ventes_lectures_pkey PRIMARY KEY (titulaire, vente);
ALTER TABLE public.journaux ADD CONSTRAINT journaux_pkey PRIMARY KEY (id);
ALTER TABLE public.journaux_redacteurs ADD CONSTRAINT journaux_redacteurs_pkey PRIMARY KEY (journal_id, personnage);
ALTER TABLE public.petites_annonces ADD CONSTRAINT petites_annonces_pkey PRIMARY KEY (id);
ALTER TABLE public.presse_membres ADD CONSTRAINT presse_membres_pkey PRIMARY KEY (groupe_id, personnage);
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT publicites_premium_presse_pkey PRIMARY KEY (id);
ALTER TABLE public.publicites_premium_sources ADD CONSTRAINT publicites_premium_sources_pkey PRIMARY KEY (id);
ALTER TABLE public.scandales_predefinis ADD CONSTRAINT scandales_predefinis_pkey PRIMARY KEY (id);
ALTER TABLE public.scandales_presse ADD CONSTRAINT scandales_presse_pkey PRIMARY KEY (id);
ALTER TABLE public.scandales_tentatives ADD CONSTRAINT scandales_tentatives_pkey PRIMARY KEY (auteur, jour_paris);
ALTER TABLE public.scandales_tirages ADD CONSTRAINT scandales_tirages_pkey PRIMARY KEY (pays, jour);
ALTER TABLE public.tracts_pnj_catalogue ADD CONSTRAINT tracts_pnj_catalogue_pkey PRIMARY KEY (pays, ville, building_id, room_id, nom);
ALTER TABLE public.tribune_articles_etouffes ADD CONSTRAINT tribune_articles_etouffes_pkey PRIMARY KEY (id);

-- CONTRAINTES D'UNICITE
ALTER TABLE public.corruptions_presse ADD CONSTRAINT corruptions_presse_affaire_ref_corrupteur_key UNIQUE (affaire_ref, corrupteur);
ALTER TABLE public.fuites_journalistiques ADD CONSTRAINT fuites_journalistiques_trace_cle_key UNIQUE (trace_cle);
ALTER TABLE public.groupes_presse ADD CONSTRAINT groupes_presse_id_pays_unique UNIQUE (id, pays);
ALTER TABLE public.journal_editions ADD CONSTRAINT journal_editions_journal_date_unique UNIQUE (journal_id, date_edition);
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT publicites_premium_presse_paiement_reference_key UNIQUE (paiement_reference);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.calomnies_actes ADD CONSTRAINT calomnies_actes_resultat_check CHECK ((resultat = ANY (ARRAY['reussite'::text, 'echec'::text, 'echec_critique'::text])));
ALTER TABLE public.corruptions_presse ADD CONSTRAINT corruptions_presse_affaire_type_check CHECK ((affaire_type = ANY (ARRAY['jugements'::text, 'detentions'::text])));
ALTER TABLE public.corruptions_presse ADD CONSTRAINT corruptions_presse_option_check CHECK ((option = ANY (ARRAY['etouffer'::text, 'favorable'::text])));
ALTER TABLE public.fuites_journalistiques ADD CONSTRAINT fuites_journalistiques_source_check CHECK ((source = ANY (ARRAY['historique_crimes'::text, 'actions_tracables'::text])));
ALTER TABLE public.journal_articles_en_attente ADD CONSTRAINT journal_articles_en_attente_statut_check CHECK ((statut = ANY (ARRAY['attente'::text, 'integre'::text, 'expire'::text])));
ALTER TABLE public.journal_editions ADD CONSTRAINT journal_editions_statut_check CHECK ((statut = ANY (ARRAY['en_cours'::text, 'publiee'::text, 'echec'::text])));
ALTER TABLE public.presse_membres ADD CONSTRAINT presse_membres_grade_check CHECK ((grade = ANY (ARRAY['correspondant'::text, 'journaliste'::text, 'redacteur_chef'::text, 'directeur'::text])));
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT diffusion_autorisee CHECK (((premiere_parution IS NULL) OR (paiement_confirme_le IS NOT NULL) OR mode_beta_gratuit));
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT programmation_payee CHECK (((etat <> ALL (ARRAY['programmee'::text, 'terminee'::text])) OR (((paiement_confirme_le IS NOT NULL) OR mode_beta_gratuit) AND (image_path IS NOT NULL) AND (premiere_parution IS NOT NULL) AND (derniere_parution = (premiere_parution +
CASE
    WHEN (formule = 'cinq'::text) THEN 4
    ELSE 9
END)))));
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT publicites_premium_presse_check CHECK ((((formule = 'cinq'::text) AND (prix_centimes = 499)) OR ((formule = 'dix'::text) AND (prix_centimes = 799))));
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT publicites_premium_presse_etat_check CHECK ((etat = ANY (ARRAY['brouillon'::text, 'paiement_en_attente'::text, 'payee'::text, 'en_generation'::text, 'apercu'::text, 'validee'::text, 'programmee'::text, 'terminee'::text, 'annulee'::text])));
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT publicites_premium_presse_formule_check CHECK ((formule = ANY (ARRAY['cinq'::text, 'dix'::text])));
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT publicites_premium_presse_retouches_check CHECK (((retouches >= 0) AND (retouches <= 2)));
ALTER TABLE public.tracts_pnj_catalogue ADD CONSTRAINT tracts_pnj_catalogue_car_vol_check CHECK (((car_vol >= 0) AND (car_vol <= 30)));

-- CLES ETRANGERES
ALTER TABLE public.journal_editions ADD CONSTRAINT journal_editions_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES journaux(id) ON DELETE RESTRICT;
ALTER TABLE public.journal_ventes_lectures ADD CONSTRAINT journal_ventes_lectures_vente_fkey FOREIGN KEY (vente) REFERENCES ventes_snapshots(id);
ALTER TABLE public.journaux ADD CONSTRAINT journaux_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES personnages_donnees(name) ON UPDATE CASCADE ON DELETE SET NULL;
ALTER TABLE public.journaux ADD CONSTRAINT journaux_groupe_pays_fk FOREIGN KEY (groupe_id, pays) REFERENCES groupes_presse(id, pays) ON DELETE RESTRICT;
ALTER TABLE public.journaux_redacteurs ADD CONSTRAINT journaux_redacteurs_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES journaux(id) ON DELETE CASCADE;
ALTER TABLE public.journaux_redacteurs ADD CONSTRAINT journaux_redacteurs_personnage_fkey FOREIGN KEY (personnage) REFERENCES personnages_donnees(name) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE public.presse_membres ADD CONSTRAINT presse_membres_groupe_id_fkey FOREIGN KEY (groupe_id) REFERENCES groupes_presse(id) ON DELETE CASCADE;
ALTER TABLE public.presse_membres ADD CONSTRAINT presse_membres_personnage_fkey FOREIGN KEY (personnage) REFERENCES personnages_donnees(name) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT publicites_premium_presse_acheteur_user_id_fkey FOREIGN KEY (acheteur_user_id) REFERENCES auth.users(id);
ALTER TABLE public.publicites_premium_sources ADD CONSTRAINT publicites_premium_sources_proprietaire_user_id_fkey FOREIGN KEY (proprietaire_user_id) REFERENCES auth.users(id);
ALTER TABLE public.publicites_premium_sources ADD CONSTRAINT publicites_premium_sources_publicite_id_fkey FOREIGN KEY (publicite_id) REFERENCES publicites_premium_presse(id) ON DELETE CASCADE;
