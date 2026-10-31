-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine divers et technique -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.actes_nocturnes ADD CONSTRAINT actes_nocturnes_pkey PRIMARY KEY (pays, mecanisme, sujet, jour);
ALTER TABLE public.actes_nocturnes_mecanismes ADD CONSTRAINT actes_nocturnes_mecanismes_pkey PRIMARY KEY (mecanisme);
ALTER TABLE public.admin_actions_tribunal ADD CONSTRAINT admin_actions_tribunal_pk PRIMARY KEY (poste, action);
ALTER TABLE public.admin_journal ADD CONSTRAINT admin_journal_pk PRIMARY KEY (rang);
ALTER TABLE public.administrateurs ADD CONSTRAINT administrateurs_pk PRIMARY KEY (user_id);
ALTER TABLE public.administrateurs_invitations ADD CONSTRAINT administrateurs_invitations_pk PRIMARY KEY (email);
ALTER TABLE public.ambassades_ouvertes ADD CONSTRAINT ambassades_ouvertes_pkey PRIMARY KEY (id);
ALTER TABLE public.carrieres ADD CONSTRAINT carrieres_pkey PRIMARY KEY (id);
ALTER TABLE public.carrieres_acquises ADD CONSTRAINT carrieres_acquises_pkey PRIMARY KEY (personnage);
ALTER TABLE public.cron_journal ADD CONSTRAINT cron_journal_pkey PRIMARY KEY (id);
ALTER TABLE public.etats_urgence ADD CONSTRAINT etats_urgence_pkey PRIMARY KEY (country);
ALTER TABLE public.evenements_globaux ADD CONSTRAINT evenements_globaux_pkey PRIMARY KEY (id);
ALTER TABLE public.habilitations ADD CONSTRAINT habilitations_pkey PRIMARY KEY (id);
ALTER TABLE public.habilitations_carrieres ADD CONSTRAINT habilitations_carrieres_pkey PRIMARY KEY (habilitation, carriere);
ALTER TABLE public.habilitations_postes ADD CONSTRAINT habilitations_postes_pkey PRIMARY KEY (poste_id);
ALTER TABLE public.propositions_diplomatiques ADD CONSTRAINT propositions_diplomatiques_pkey PRIMARY KEY (id);
ALTER TABLE public.purges_residus_bancs ADD CONSTRAINT purges_residus_bancs_pkey PRIMARY KEY (id);
ALTER TABLE public.registre_ventes_armes ADD CONSTRAINT registre_ventes_armes_pkey PRIMARY KEY (id);
ALTER TABLE public.visuels_moderation ADD CONSTRAINT visuels_moderation_pkey PRIMARY KEY (id);
ALTER TABLE public.visuels_versions ADD CONSTRAINT visuels_versions_pkey PRIMARY KEY (id);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.actes_nocturnes ADD CONSTRAINT actes_nocturnes_pays_non_vide CHECK ((btrim(pays) <> ''::text));
ALTER TABLE public.actes_nocturnes ADD CONSTRAINT actes_nocturnes_sujet_non_vide CHECK ((btrim(sujet) <> ''::text));
ALTER TABLE public.actes_nocturnes_mecanismes ADD CONSTRAINT actes_nocturnes_mecanismes_slug CHECK ((mecanisme ~ '^[a-z][a-z0-9_]{2,59}$'::text));
ALTER TABLE public.admin_actions_tribunal ADD CONSTRAINT admin_actions_tribunal_poste CHECK ((poste = ANY (ARRAY['procureur'::text, 'juge'::text])));
ALTER TABLE public.administrateurs_invitations ADD CONSTRAINT administrateurs_invitations_consommation CHECK ((((consommee_le IS NULL) AND (consommee_par IS NULL)) OR ((consommee_le IS NOT NULL) AND (consommee_par IS NOT NULL))));
ALTER TABLE public.administrateurs_invitations ADD CONSTRAINT administrateurs_invitations_minuscules CHECK ((email = lower(email)));
ALTER TABLE public.carrieres_acquises ADD CONSTRAINT carrieres_acquises_source_check CHECK ((source = 'universite'::text));
ALTER TABLE public.cron_journal ADD CONSTRAINT cron_journal_statut_check CHECK ((statut = ANY (ARRAY['demarree'::text, 'ok'::text, 'echec'::text, 'ignoree'::text])));
ALTER TABLE public.visuels_versions ADD CONSTRAINT visuels_versions_type_visuel_check CHECK ((type_visuel = ANY (ARRAY['publicite'::text, 'commerce'::text])));

-- CLES ETRANGERES
ALTER TABLE public.actes_nocturnes ADD CONSTRAINT actes_nocturnes_mecanisme_fkey FOREIGN KEY (mecanisme) REFERENCES actes_nocturnes_mecanismes(mecanisme);
ALTER TABLE public.carrieres_acquises ADD CONSTRAINT carrieres_acquises_carriere_fkey FOREIGN KEY (carriere) REFERENCES carrieres(id);
ALTER TABLE public.habilitations_carrieres ADD CONSTRAINT habilitations_carrieres_carriere_fkey FOREIGN KEY (carriere) REFERENCES carrieres(id);
ALTER TABLE public.habilitations_carrieres ADD CONSTRAINT habilitations_carrieres_habilitation_fkey FOREIGN KEY (habilitation) REFERENCES habilitations(id);
ALTER TABLE public.habilitations_postes ADD CONSTRAINT habilitations_postes_habilitation_fkey FOREIGN KEY (habilitation) REFERENCES habilitations(id);
ALTER TABLE public.visuels_moderation ADD CONSTRAINT visuels_moderation_administrateur_user_id_fkey FOREIGN KEY (administrateur_user_id) REFERENCES auth.users(id);
ALTER TABLE public.visuels_versions ADD CONSTRAINT visuels_versions_auteur_user_id_fkey FOREIGN KEY (auteur_user_id) REFERENCES auth.users(id);
