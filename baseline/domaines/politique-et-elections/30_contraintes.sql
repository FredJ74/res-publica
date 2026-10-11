-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine politique et elections -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.candidatures ADD CONSTRAINT candidatures_pkey PRIMARY KEY (id);
ALTER TABLE public.communications_salles ADD CONSTRAINT communications_salles_pkey PRIMARY KEY (building_id, room_id);
ALTER TABLE public.conferences_presse ADD CONSTRAINT conferences_presse_pkey PRIMARY KEY (id);
ALTER TABLE public.conferences_presse_echanges ADD CONSTRAINT conferences_presse_echanges_pkey PRIMARY KEY (conference_id, rang);
ALTER TABLE public.cycles_electoraux ADD CONSTRAINT cycles_electoraux_pkey PRIMARY KEY (id);
ALTER TABLE public.demandes_manifestation ADD CONSTRAINT demandes_manifestation_pkey PRIMARY KEY (id);
ALTER TABLE public.elections_tracts_pnj ADD CONSTRAINT elections_tracts_pnj_pkey PRIMARY KEY (id);
ALTER TABLE public.fraudes_electorales ADD CONSTRAINT fraudes_electorales_pkey PRIMARY KEY (id);
ALTER TABLE public.greves_generales ADD CONSTRAINT greves_generales_pkey PRIMARY KEY (id);
ALTER TABLE public.indices_villes ADD CONSTRAINT indices_villes_pkey PRIMARY KEY (id);
ALTER TABLE public.mandats_maires_archives ADD CONSTRAINT mandats_maires_archives_pkey PRIMARY KEY (id);
ALTER TABLE public.militants_recrutes ADD CONSTRAINT militants_recrutes_pkey PRIMARY KEY (id);
ALTER TABLE public.presidence_memoire ADD CONSTRAINT presidence_memoire_pkey PRIMARY KEY (id);
ALTER TABLE public.presidence_memoire_ordres ADD CONSTRAINT presidence_memoire_ordres_pkey PRIMARY KEY (fn, pa, cost);
ALTER TABLE public.presidence_memoire_sources ADD CONSTRAINT presidence_memoire_sources_pkey PRIMARY KEY (source);
ALTER TABLE public.presidence_memoire_sources_absentes ADD CONSTRAINT presidence_memoire_sources_absentes_pkey PRIMARY KEY (sujet);
ALTER TABLE public.rp_epoques ADD CONSTRAINT rp_epoques_pkey PRIMARY KEY (pays);
ALTER TABLE public.rp_transitions ADD CONSTRAINT rp_transitions_pkey PRIMARY KEY (cle);
ALTER TABLE public.votes_confiance ADD CONSTRAINT votes_confiance_pkey PRIMARY KEY (id);
ALTER TABLE public.votes_confiance_bulletins ADD CONSTRAINT votes_confiance_bulletins_pkey PRIMARY KEY (id);
ALTER TABLE public.votes_electoraux ADD CONSTRAINT votes_electoraux_pkey PRIMARY KEY (id);

-- CONTRAINTES D'UNICITE
ALTER TABLE public.elections_tracts_pnj ADD CONSTRAINT elections_tracts_pnj_cycle_id_tour_pnj_cle_key UNIQUE (cycle_id, tour, pnj_cle);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.communications_salles ADD CONSTRAINT communications_ordres_non_vides CHECK ((array_length(ordres, 1) >= 1));
ALTER TABLE public.communications_salles ADD CONSTRAINT communications_postes_non_vides CHECK ((array_length(postes, 1) >= 1));
ALTER TABLE public.conferences_presse ADD CONSTRAINT conference_close_a_une_date CHECK ((((statut = 'ouverte'::text) AND (close_le IS NULL)) OR ((statut <> 'ouverte'::text) AND (close_le IS NOT NULL))));
ALTER TABLE public.conferences_presse ADD CONSTRAINT conference_statut_connu CHECK ((statut = ANY (ARRAY['ouverte'::text, 'terminee'::text, 'interrompue'::text])));
ALTER TABLE public.conferences_presse_echanges ADD CONSTRAINT echange_rang_borne CHECK (((rang >= 1) AND (rang <= 5)));
ALTER TABLE public.conferences_presse_echanges ADD CONSTRAINT echange_refus_sans_reponse CHECK ((NOT (refus AND (reponse IS NOT NULL))));
ALTER TABLE public.conferences_presse_echanges ADD CONSTRAINT echange_repondu_a_une_date CHECK ((((reponse IS NULL) AND (NOT refus) AND (repondu_le IS NULL)) OR (((reponse IS NOT NULL) OR refus) AND (repondu_le IS NOT NULL))));
ALTER TABLE public.elections_tracts_pnj ADD CONSTRAINT elections_tracts_pnj_effet_check CHECK ((effet = ANY (ARRAY[1, 0, '-1'::integer])));
ALTER TABLE public.elections_tracts_pnj ADD CONSTRAINT elections_tracts_pnj_sens_check CHECK ((sens = ANY (ARRAY[1, '-1'::integer])));
ALTER TABLE public.fraudes_electorales ADD CONSTRAINT fraudes_electorales_etat_check CHECK ((etat = ANY (ARRAY['non_revelee'::text, 'revelee'::text])));
ALTER TABLE public.fraudes_electorales ADD CONSTRAINT fraudes_electorales_type_check CHECK ((type = ANY (ARRAY['falsification_listes'::text, 'bourrage_urnes'::text, 'trucage_depouillement'::text])));
ALTER TABLE public.presidence_memoire ADD CONSTRAINT presidence_memoire_genre_connu CHECK ((genre = ANY (ARRAY['contexte'::text, 'reaction'::text])));
ALTER TABLE public.presidence_memoire_sources ADD CONSTRAINT presidence_memoire_sources_genre_connu CHECK ((genre = ANY (ARRAY['contexte'::text, 'reaction'::text])));

-- CLES ETRANGERES
ALTER TABLE public.conferences_presse_echanges ADD CONSTRAINT conferences_presse_echanges_conference_id_fkey FOREIGN KEY (conference_id) REFERENCES conferences_presse(id) ON DELETE CASCADE;
ALTER TABLE public.presidence_memoire ADD CONSTRAINT presidence_memoire_source_fkey FOREIGN KEY (source) REFERENCES presidence_memoire_sources(source);
