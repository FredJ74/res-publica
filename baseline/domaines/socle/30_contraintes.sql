-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.inventaire_actions_recus ADD CONSTRAINT inventaire_actions_recus_pkey PRIMARY KEY (acteur, requete);
ALTER TABLE public.inventaire_ecarts_observes ADD CONSTRAINT inventaire_ecarts_observes_pkey PRIMARY KEY (id);
ALTER TABLE public.inventaire_livraisons_recues ADD CONSTRAINT inventaire_livraisons_recues_pkey PRIMARY KEY (jeton);
ALTER TABLE public.objets_achetables ADD CONSTRAINT objets_achetables_pkey PRIMARY KEY (ordre, modele);
ALTER TABLE public.objets_modeles ADD CONSTRAINT objets_modeles_pkey PRIMARY KEY (id);
ALTER TABLE public.objets_trouves_jours ADD CONSTRAINT objets_trouves_jours_pkey PRIMARY KEY (acteur, jour);
ALTER TABLE public.ordres_generiques ADD CONSTRAINT ordres_generiques_pkey PRIMARY KEY (fn);
ALTER TABLE public.rue_noeuds_serveur ADD CONSTRAINT rue_noeuds_serveur_pkey PRIMARY KEY (country, city, noeud);
ALTER TABLE public.rue_sorties_batiments ADD CONSTRAINT rue_sorties_batiments_pkey PRIMARY KEY (country, city, noeud, building);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.ordres_generiques ADD CONSTRAINT ordres_generiques_taux_reussite_check CHECK (((taux_reussite >= 1) AND (taux_reussite <= 100)));

-- CLES ETRANGERES
ALTER TABLE public.objets_achetables ADD CONSTRAINT objets_achetables_modele_fkey FOREIGN KEY (modele) REFERENCES objets_modeles(id);
