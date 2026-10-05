-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine communication -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 10 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   chat_piece_pkey  (contrainte chat_piece_pkey)
--   forum_posts_pkey  (contrainte forum_posts_pkey)
--   forum_topics_pkey  (contrainte forum_topics_pkey)
--   lectures_chat_pkey  (contrainte lectures_chat_pkey)
--   mails_envois_systeme_pkey  (contrainte mails_envois_systeme_pkey)
--   mails_expediteurs_systeme_pkey  (contrainte mails_expediteurs_systeme_pkey)
--   mails_pkey  (contrainte mails_pkey)
--   messages_chat_pkey  (contrainte messages_chat_pkey)
--   salons_chat_pkey  (contrainte salons_chat_pkey)
--   salons_membres_pkey  (contrainte salons_membres_pkey)

-- Index autonomes :
CREATE INDEX idx_chat_piece_lieu ON public.chat_piece USING btree (country, city, building_id, room_id, created_at);
