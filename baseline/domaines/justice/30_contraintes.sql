-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.actions_tracables ADD CONSTRAINT actions_tracables_pkey PRIMARY KEY (id);
ALTER TABLE public.audience_messages ADD CONSTRAINT audience_messages_pkey PRIMARY KEY (rang);
ALTER TABLE public.audience_paroles ADD CONSTRAINT audience_paroles_pk PRIMARY KEY (affaire, personne);
ALTER TABLE public.avocats_barreau ADD CONSTRAINT avocats_barreau_pk PRIMARY KEY (nom);
ALTER TABLE public.defenses_demandes ADD CONSTRAINT defenses_demandes_pk PRIMARY KEY (rang);
ALTER TABLE public.demandes_grace ADD CONSTRAINT demandes_grace_pkey PRIMARY KEY (id);
ALTER TABLE public.detentions ADD CONSTRAINT detentions_pkey PRIMARY KEY (id);
ALTER TABLE public.documents_officiels ADD CONSTRAINT documents_officiels_pkey PRIMARY KEY (id);
ALTER TABLE public.dossiers_auditions ADD CONSTRAINT dossiers_auditions_pkey PRIMARY KEY (id);
ALTER TABLE public.dossiers_judiciaires_actes ADD CONSTRAINT dossiers_judiciaires_actes_pkey PRIMARY KEY (id);
ALTER TABLE public.dossiers_judiciaires_actes_types ADD CONSTRAINT dossiers_judiciaires_actes_types_pkey PRIMARY KEY (type);
ALTER TABLE public.greffes_tribunaux ADD CONSTRAINT greffes_tribunaux_pkey PRIMARY KEY (pays, ville);
ALTER TABLE public.impacts_indices_attente ADD CONSTRAINT impacts_indices_attente_pkey PRIMARY KEY (id);
ALTER TABLE public.infractions ADD CONSTRAINT infractions_pkey PRIMARY KEY (id);
ALTER TABLE public.infractions_alias ADD CONSTRAINT infractions_alias_pkey PRIMARY KEY (alias);
ALTER TABLE public.infractions_categories ADD CONSTRAINT infractions_categories_pkey PRIMARY KEY (id);
ALTER TABLE public.infractions_empreinte ADD CONSTRAINT infractions_empreinte_pkey PRIMARY KEY (seul);
ALTER TABLE public.jugements ADD CONSTRAINT jugements_pkey PRIMARY KEY (id);
ALTER TABLE public.justice_avocats_commis ADD CONSTRAINT justice_avocats_commis_pk PRIMARY KEY (pays, ville);
ALTER TABLE public.justice_faits_publics ADD CONSTRAINT justice_faits_publics_pkey PRIMARY KEY (type_acte);
ALTER TABLE public.justice_indemnites ADD CONSTRAINT justice_indemnites_pkey PRIMARY KEY (id);
ALTER TABLE public.niveaux_prison ADD CONSTRAINT niveaux_prison_pkey PRIMARY KEY (id);
ALTER TABLE public.plaintes_en_cours ADD CONSTRAINT plaintes_en_cours_pkey PRIMARY KEY (id);
ALTER TABLE public.prisonniers_qhs ADD CONSTRAINT prisonniers_qhs_pkey PRIMARY KEY (id);
ALTER TABLE public.rumeurs_actives ADD CONSTRAINT rumeurs_actives_pkey PRIMARY KEY (id);
ALTER TABLE public.signalements_police ADD CONSTRAINT signalements_police_pkey PRIMARY KEY (id);
ALTER TABLE public.temoins_citations ADD CONSTRAINT temoins_citations_pk PRIMARY KEY (rang);
ALTER TABLE public.vols_en_attente ADD CONSTRAINT vols_en_attente_pkey PRIMARY KEY (id);

-- CONTRAINTES D'UNICITE
ALTER TABLE public.dossiers_auditions ADD CONSTRAINT dossiers_auditions_un_pv_par_affaire_et_personne UNIQUE (affaire, personne);
ALTER TABLE public.dossiers_judiciaires_actes ADD CONSTRAINT dossiers_actes_un_rang_par_affaire UNIQUE (affaire, rang);
ALTER TABLE public.impacts_indices_attente ADD CONSTRAINT impacts_indices_attente_id_unique UNIQUE (id);
ALTER TABLE public.temoins_citations ADD CONSTRAINT temoins_citations_une_par_affaire UNIQUE (affaire, temoin);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.audience_messages ADD CONSTRAINT audience_messages_qualite_check CHECK ((qualite = ANY (ARRAY['juge'::text, 'procureur'::text, 'prevenu'::text, 'avocat'::text, 'temoin'::text])));
ALTER TABLE public.audience_messages ADD CONSTRAINT audience_messages_texte_borne CHECK ((length(texte) <= 4000));
ALTER TABLE public.audience_messages ADD CONSTRAINT audience_messages_texte_non_vide CHECK ((btrim(texte) <> ''::text));
ALTER TABLE public.avocats_barreau ADD CONSTRAINT avocats_barreau_tarification_bornee CHECK ((length(tarification) <= 200));
ALTER TABLE public.avocats_barreau ADD CONSTRAINT avocats_barreau_tarification_non_vide CHECK ((btrim(tarification) <> ''::text));
ALTER TABLE public.defenses_demandes ADD CONSTRAINT defenses_demandes_etat CHECK ((etat = ANY (ARRAY['en_attente'::text, 'acceptee'::text, 'refusee'::text, 'caduque'::text, 'revoquee'::text, 'abandonnee'::text])));
ALTER TABLE public.defenses_demandes ADD CONSTRAINT defenses_demandes_pas_soi_meme CHECK ((prevenu <> avocat));
ALTER TABLE public.documents_officiels ADD CONSTRAINT documents_officiels_apparence_declaree CHECK ((genre_apparent = ANY (ARRAY['casier_extrait'::text, 'dossier_copie'::text, 'domiciliation_extrait'::text])));
ALTER TABLE public.documents_officiels ADD CONSTRAINT documents_officiels_faux_est_un_faux CHECK (((genre = 'casier_faux'::text) = (authentique = false)));
ALTER TABLE public.documents_officiels ADD CONSTRAINT documents_officiels_genre_declare CHECK ((genre = ANY (ARRAY['casier_extrait'::text, 'casier_faux'::text, 'dossier_copie'::text, 'domiciliation_extrait'::text])));
ALTER TABLE public.dossiers_auditions ADD CONSTRAINT dossiers_auditions_declaration_ou_refus CHECK ((((refus IS TRUE) AND (declaration IS NULL)) OR ((refus IS FALSE) AND (declaration IS NOT NULL) AND (btrim(declaration) <> ''::text))));
ALTER TABLE public.dossiers_auditions ADD CONSTRAINT dossiers_auditions_qualite CHECK ((qualite = ANY (ARRAY['prevenu'::text, 'temoin'::text])));
ALTER TABLE public.dossiers_judiciaires_actes ADD CONSTRAINT dossiers_judiciaires_actes_rang_check CHECK ((rang >= 1));
ALTER TABLE public.dossiers_judiciaires_actes_types ADD CONSTRAINT dossiers_judiciaires_actes_types_pose_par_check CHECK ((pose_par = ANY (ARRAY['plaignant'::text, 'police'::text, 'parquet'::text, 'juge'::text, 'accuse'::text, 'avocat'::text, 'temoin'::text, 'serveur'::text])));
ALTER TABLE public.infractions ADD CONSTRAINT infractions_amende_reference_check CHECK ((amende_reference >= 0));
ALTER TABLE public.infractions ADD CONSTRAINT infractions_delit_exige_bareme_propre CHECK (((categorie <> 'delit'::text) OR bareme_propre));
ALTER TABLE public.infractions ADD CONSTRAINT infractions_detect_rate_check CHECK (((detect_rate IS NULL) OR ((detect_rate >= 0) AND (detect_rate <= 100))));
ALTER TABLE public.infractions ADD CONSTRAINT infractions_jours_reference_check CHECK ((jours_reference >= 1));
ALTER TABLE public.infractions_alias ADD CONSTRAINT infractions_alias_pas_sur_soi CHECK ((alias <> canonique));
ALTER TABLE public.infractions_categories ADD CONSTRAINT infractions_categories_amende_reference_check CHECK ((amende_reference >= 0));
ALTER TABLE public.infractions_categories ADD CONSTRAINT infractions_categories_jours_reference_check CHECK ((jours_reference >= 1));
ALTER TABLE public.infractions_empreinte ADD CONSTRAINT infractions_empreinte_seul_check CHECK (seul);
ALTER TABLE public.justice_avocats_commis ADD CONSTRAINT justice_avocats_commis_cha_plage CHECK (((cha >= 1) AND (cha <= 20)));
ALTER TABLE public.justice_indemnites ADD CONSTRAINT justice_indemnites_etat_coherent CHECK (((etat = 'reglee'::text) = (montant_paye = montant_du)));
ALTER TABLE public.justice_indemnites ADD CONSTRAINT justice_indemnites_etat_connu CHECK ((etat = ANY (ARRAY['due'::text, 'reglee'::text])));
ALTER TABLE public.justice_indemnites ADD CONSTRAINT justice_indemnites_jours_positifs CHECK ((jours_indus > 0));
ALTER TABLE public.justice_indemnites ADD CONSTRAINT justice_indemnites_montant_positif CHECK ((montant_du > 0));
ALTER TABLE public.justice_indemnites ADD CONSTRAINT justice_indemnites_paye_borne CHECK (((montant_paye >= 0) AND (montant_paye <= montant_du)));
ALTER TABLE public.justice_indemnites ADD CONSTRAINT justice_indemnites_porteur_connu CHECK ((porteur = ANY (ARRAY['min_just'::text, 'min_fin'::text])));
ALTER TABLE public.signalements_police ADD CONSTRAINT signalements_police_issue_connue CHECK (((issue IS NULL) OR (issue = ANY (ARRAY['arrestation'::text, 'cible_partie'::text, 'abandonne'::text]))));
ALTER TABLE public.signalements_police ADD CONSTRAINT signalements_police_pas_soi CHECK ((signaleur <> cible));
ALTER TABLE public.signalements_police ADD CONSTRAINT signalements_police_resolution_coherente CHECK (((resolu_le IS NULL) = (issue IS NULL)));
ALTER TABLE public.temoins_citations ADD CONSTRAINT temoins_citations_cloture CHECK ((((etat = 'close'::text) AND (issue IS NOT NULL) AND (clos_le IS NOT NULL)) OR ((etat <> 'close'::text) AND (issue IS NULL) AND (clos_le IS NULL))));
ALTER TABLE public.temoins_citations ADD CONSTRAINT temoins_citations_etat CHECK ((etat = ANY (ARRAY['convoquee'::text, 'recherche'::text, 'close'::text])));
ALTER TABLE public.temoins_citations ADD CONSTRAINT temoins_citations_issue CHECK (((issue IS NULL) OR (issue = ANY (ARRAY['deposition'::text, 'refus'::text, 'affaire_close'::text]))));
ALTER TABLE public.temoins_citations ADD CONSTRAINT temoins_citations_qualite CHECK ((cite_par_qualite = ANY (ARRAY['avocat'::text, 'parquet'::text, 'juge'::text, 'plaignant'::text])));
ALTER TABLE public.temoins_citations ADD CONSTRAINT temoins_citations_rang_convocation CHECK ((convocation_rang = ANY (ARRAY[1, 2])));

-- CLES ETRANGERES
ALTER TABLE public.dossiers_judiciaires_actes ADD CONSTRAINT dossiers_judiciaires_actes_qualif_apres_fkey FOREIGN KEY (qualif_apres) REFERENCES infractions(id);
ALTER TABLE public.dossiers_judiciaires_actes ADD CONSTRAINT dossiers_judiciaires_actes_qualif_avant_fkey FOREIGN KEY (qualif_avant) REFERENCES infractions(id);
ALTER TABLE public.dossiers_judiciaires_actes ADD CONSTRAINT dossiers_judiciaires_actes_type_fkey FOREIGN KEY (type) REFERENCES dossiers_judiciaires_actes_types(type);
ALTER TABLE public.infractions ADD CONSTRAINT infractions_categorie_fkey FOREIGN KEY (categorie) REFERENCES infractions_categories(id);
ALTER TABLE public.infractions_alias ADD CONSTRAINT infractions_alias_canonique_fkey FOREIGN KEY (canonique) REFERENCES infractions(id);
ALTER TABLE public.justice_faits_publics ADD CONSTRAINT justice_faits_publics_type_acte_fkey FOREIGN KEY (type_acte) REFERENCES dossiers_judiciaires_actes_types(type);
