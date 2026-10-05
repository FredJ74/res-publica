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
ALTER TABLE public.journaux ADD CONSTRAINT journaux_pkey PRIMARY KEY (id);
ALTER TABLE public.journaux_redacteurs ADD CONSTRAINT journaux_redacteurs_pkey PRIMARY KEY (journal_id, personnage);
ALTER TABLE public.petites_annonces ADD CONSTRAINT petites_annonces_pkey PRIMARY KEY (id);
ALTER TABLE public.presse_membres ADD CONSTRAINT presse_membres_pkey PRIMARY KEY (groupe_id, personnage);
ALTER TABLE public.scandales_presse ADD CONSTRAINT scandales_presse_pkey PRIMARY KEY (id);
ALTER TABLE public.scandales_tentatives ADD CONSTRAINT scandales_tentatives_pkey PRIMARY KEY (auteur, jour_paris);
ALTER TABLE public.tribune_articles_etouffes ADD CONSTRAINT tribune_articles_etouffes_pkey PRIMARY KEY (id);

-- CONTRAINTES D'UNICITE
ALTER TABLE public.corruptions_presse ADD CONSTRAINT corruptions_presse_affaire_ref_corrupteur_key UNIQUE (affaire_ref, corrupteur);
ALTER TABLE public.fuites_journalistiques ADD CONSTRAINT fuites_journalistiques_trace_cle_key UNIQUE (trace_cle);
ALTER TABLE public.groupes_presse ADD CONSTRAINT groupes_presse_id_pays_unique UNIQUE (id, pays);
ALTER TABLE public.journal_editions ADD CONSTRAINT journal_editions_journal_date_unique UNIQUE (journal_id, date_edition);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.calomnies_actes ADD CONSTRAINT calomnies_actes_resultat_check CHECK ((resultat = ANY (ARRAY['reussite'::text, 'echec'::text, 'echec_critique'::text])));
ALTER TABLE public.corruptions_presse ADD CONSTRAINT corruptions_presse_affaire_type_check CHECK ((affaire_type = ANY (ARRAY['jugements'::text, 'detentions'::text])));
ALTER TABLE public.corruptions_presse ADD CONSTRAINT corruptions_presse_option_check CHECK ((option = ANY (ARRAY['etouffer'::text, 'favorable'::text])));
ALTER TABLE public.fuites_journalistiques ADD CONSTRAINT fuites_journalistiques_source_check CHECK ((source = ANY (ARRAY['historique_crimes'::text, 'actions_tracables'::text])));
ALTER TABLE public.journal_articles_en_attente ADD CONSTRAINT journal_articles_en_attente_statut_check CHECK ((statut = ANY (ARRAY['attente'::text, 'integre'::text, 'expire'::text])));
ALTER TABLE public.journal_editions ADD CONSTRAINT journal_editions_statut_check CHECK ((statut = ANY (ARRAY['en_cours'::text, 'publiee'::text, 'echec'::text])));
ALTER TABLE public.presse_membres ADD CONSTRAINT presse_membres_grade_check CHECK ((grade = ANY (ARRAY['correspondant'::text, 'journaliste'::text, 'redacteur_chef'::text, 'directeur'::text])));

-- CLES ETRANGERES
ALTER TABLE public.journal_editions ADD CONSTRAINT journal_editions_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES journaux(id) ON DELETE RESTRICT;
ALTER TABLE public.journaux ADD CONSTRAINT journaux_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES personnages_donnees(name) ON UPDATE CASCADE ON DELETE SET NULL;
ALTER TABLE public.journaux ADD CONSTRAINT journaux_groupe_pays_fk FOREIGN KEY (groupe_id, pays) REFERENCES groupes_presse(id, pays) ON DELETE RESTRICT;
ALTER TABLE public.journaux_redacteurs ADD CONSTRAINT journaux_redacteurs_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES journaux(id) ON DELETE CASCADE;
ALTER TABLE public.journaux_redacteurs ADD CONSTRAINT journaux_redacteurs_personnage_fkey FOREIGN KEY (personnage) REFERENCES personnages_donnees(name) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE public.presse_membres ADD CONSTRAINT presse_membres_groupe_id_fkey FOREIGN KEY (groupe_id) REFERENCES groupes_presse(id) ON DELETE CASCADE;
ALTER TABLE public.presse_membres ADD CONSTRAINT presse_membres_personnage_fkey FOREIGN KEY (personnage) REFERENCES personnages_donnees(name) ON UPDATE CASCADE ON DELETE CASCADE;
