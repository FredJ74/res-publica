-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine communication -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction doit passer par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.chat_piece ADD CONSTRAINT chat_piece_pkey PRIMARY KEY (id);
ALTER TABLE public.forum_posts ADD CONSTRAINT forum_posts_pkey PRIMARY KEY (id);
ALTER TABLE public.forum_topics ADD CONSTRAINT forum_topics_pkey PRIMARY KEY (id);
ALTER TABLE public.lectures_chat ADD CONSTRAINT lectures_chat_pkey PRIMARY KEY (id);
ALTER TABLE public.mails ADD CONSTRAINT mails_pkey PRIMARY KEY (id);
ALTER TABLE public.mails_envois_systeme ADD CONSTRAINT mails_envois_systeme_pkey PRIMARY KEY (id);
ALTER TABLE public.mails_expediteurs_systeme ADD CONSTRAINT mails_expediteurs_systeme_pkey PRIMARY KEY (expediteur);
ALTER TABLE public.messages_chat ADD CONSTRAINT messages_chat_pkey PRIMARY KEY (id);
ALTER TABLE public.salons_chat ADD CONSTRAINT salons_chat_pkey PRIMARY KEY (id);
ALTER TABLE public.salons_membres ADD CONSTRAINT salons_membres_pkey PRIMARY KEY (id);

-- CLES ETRANGERES
ALTER TABLE public.forum_posts ADD CONSTRAINT forum_posts_topic_id_fkey FOREIGN KEY (topic_id) REFERENCES forum_topics(id) ON DELETE CASCADE;
