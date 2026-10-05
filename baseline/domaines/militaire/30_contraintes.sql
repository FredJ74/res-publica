-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine militaire -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.armureries_dotations ADD CONSTRAINT armureries_dotations_pkey PRIMARY KEY (pays);
ALTER TABLE public.batailles ADD CONSTRAINT batailles_pkey PRIMARY KEY (id);
ALTER TABLE public.batailles_engagements ADD CONSTRAINT batailles_engagements_pkey PRIMARY KEY (id);
ALTER TABLE public.batailles_groupes ADD CONSTRAINT batailles_groupes_pkey PRIMARY KEY (bataille_id, groupe_id);
ALTER TABLE public.batailles_rounds ADD CONSTRAINT batailles_rounds_pkey PRIMARY KEY (id);
ALTER TABLE public.camions_destinations ADD CONSTRAINT camions_destinations_pkey PRIMARY KEY (pays, cle);
ALTER TABLE public.camions_embarquements ADD CONSTRAINT camions_embarquements_pkey PRIMARY KEY (camion_id, personnage);
ALTER TABLE public.camions_militaires ADD CONSTRAINT camions_militaires_pkey PRIMARY KEY (id);
ALTER TABLE public.camions_ordres ADD CONSTRAINT camions_ordres_pkey PRIMARY KEY (requete);
ALTER TABLE public.candidatures_militaires ADD CONSTRAINT candidatures_militaires_pkey PRIMARY KEY (id);
ALTER TABLE public.commandes_militaires ADD CONSTRAINT commandes_militaires_pkey PRIMARY KEY (id);
ALTER TABLE public.compagnies_militaires ADD CONSTRAINT compagnies_militaires_pkey PRIMARY KEY (id);
ALTER TABLE public.contacts_militaires ADD CONSTRAINT contacts_militaires_pkey PRIMARY KEY (id);
ALTER TABLE public.decorations_militaires ADD CONSTRAINT decorations_militaires_pkey PRIMARY KEY (id);
ALTER TABLE public.engagements_militaires ADD CONSTRAINT engagements_militaires_pkey PRIMARY KEY (id);
ALTER TABLE public.guerres ADD CONSTRAINT guerres_pkey PRIMARY KEY (id);
ALTER TABLE public.militaire_armes_bonus ADD CONSTRAINT militaire_armes_bonus_pkey PRIMARY KEY (cle);
ALTER TABLE public.militaire_detections ADD CONSTRAINT militaire_detections_pkey PRIMARY KEY (id);
ALTER TABLE public.militaire_terminal_requetes ADD CONSTRAINT militaire_terminal_requetes_pkey PRIMARY KEY (requete);
ALTER TABLE public.mutineries ADD CONSTRAINT mutineries_pkey PRIMARY KEY (camp);
ALTER TABLE public.mutineries_membres ADD CONSTRAINT mutineries_membres_pkey PRIMARY KEY (camp, personnage);
ALTER TABLE public.nominations_militaires ADD CONSTRAINT nominations_militaires_pkey PRIMARY KEY (id);
ALTER TABLE public.retraits_materiel_militaire ADD CONSTRAINT retraits_materiel_militaire_pkey PRIMARY KEY (id);
ALTER TABLE public.services_militaires ADD CONSTRAINT services_militaires_pkey PRIMARY KEY (id);
ALTER TABLE public.soldes_militaires ADD CONSTRAINT soldes_militaires_pkey PRIMARY KEY (id);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.batailles ADD CONSTRAINT batailles_statut_valide CHECK ((statut = ANY (ARRAY['en_cours'::text, 'terminee'::text])));
ALTER TABLE public.batailles_engagements ADD CONSTRAINT batailles_engagements_identite CHECK ((((personnage IS NOT NULL) AND (matricule IS NULL)) OR ((personnage IS NULL) AND (matricule IS NOT NULL))));
ALTER TABLE public.batailles_groupes ADD CONSTRAINT batailles_groupes_decision_check CHECK ((decision = ANY (ARRAY['tenir'::text, 'replier'::text])));
ALTER TABLE public.camions_militaires ADD CONSTRAINT camions_militaires_capacite_check CHECK ((capacite > 0));
ALTER TABLE public.camions_militaires ADD CONSTRAINT camions_militaires_statut_check CHECK ((statut = ANY (ARRAY['actif'::text, 'hors_service'::text])));
ALTER TABLE public.candidatures_militaires ADD CONSTRAINT candidatures_militaires_grade_vise_check CHECK ((grade_vise = ANY (ARRAY['capitaine'::text, 'lieutenant'::text, 'soldat'::text])));
ALTER TABLE public.candidatures_militaires ADD CONSTRAINT candidatures_militaires_statut_check CHECK ((statut = ANY (ARRAY['active'::text, 'acceptee'::text, 'finalisee'::text, 'retiree'::text, 'annulee'::text, 'expiree'::text])));
ALTER TABLE public.commandes_militaires ADD CONSTRAINT commandes_militaires_quantite_demandee_check CHECK ((quantite_demandee > 0));
ALTER TABLE public.commandes_militaires ADD CONSTRAINT commandes_militaires_quantite_produite_check CHECK ((quantite_produite >= 0));
ALTER TABLE public.commandes_militaires ADD CONSTRAINT commandes_militaires_reliquat CHECK ((quantite_produite <= quantite_demandee));
ALTER TABLE public.commandes_militaires ADD CONSTRAINT commandes_militaires_statut CHECK ((statut = ANY (ARRAY['en_cours'::text, 'terminee'::text, 'annulee'::text])));
ALTER TABLE public.decorations_militaires ADD CONSTRAINT decorations_militaires_niveau_check CHECK ((niveau = ANY (ARRAY['compagnie'::text, 'armee'::text, 'etat'::text])));
ALTER TABLE public.militaire_armes_bonus ADD CONSTRAINT militaire_armes_bonus_mode_check CHECK ((mode = ANY (ARRAY['feu'::text, 'cac'::text])));
ALTER TABLE public.nominations_militaires ADD CONSTRAINT nominations_militaires_grade_check CHECK ((grade = ANY (ARRAY['capitaine'::text, 'lieutenant'::text])));
ALTER TABLE public.retraits_materiel_militaire ADD CONSTRAINT retraits_materiel_militaire_quantite_check CHECK ((quantite > 0));

-- CLES ETRANGERES
ALTER TABLE public.batailles_engagements ADD CONSTRAINT batailles_engagements_bataille_id_fkey FOREIGN KEY (bataille_id) REFERENCES batailles(id) ON DELETE CASCADE;
ALTER TABLE public.batailles_rounds ADD CONSTRAINT batailles_rounds_bataille_id_fkey FOREIGN KEY (bataille_id) REFERENCES batailles(id) ON DELETE CASCADE;
ALTER TABLE public.contacts_militaires ADD CONSTRAINT contacts_militaires_bataille_id_fkey FOREIGN KEY (bataille_id) REFERENCES batailles(id);
ALTER TABLE public.mutineries_membres ADD CONSTRAINT mutineries_membres_camp_fkey FOREIGN KEY (camp) REFERENCES mutineries(camp) ON DELETE CASCADE;
