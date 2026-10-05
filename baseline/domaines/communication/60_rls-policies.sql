-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine communication -- phase 60 : rls-policies
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction doit passer par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- Activation de la RLS. Une table dont la RLS est active SANS policy est
-- fermee a tout role soumis a la RLS : c'est un etat VOULU, pas un oubli.

ALTER TABLE public.chat_piece ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lectures_chat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mails ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mails_envois_systeme ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mails_expediteurs_systeme ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages_chat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salons_chat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salons_membres ENABLE ROW LEVEL SECURITY;


-- chat_piece
CREATE POLICY allow_all_chat_piece ON public.chat_piece FOR ALL TO PUBLIC
  USING (true)
  WITH CHECK (true);

-- forum_posts
CREATE POLICY forum_posts_creation ON public.forum_posts FOR INSERT TO authenticated
  WITH CHECK (author = mon_personnage() OR author_real = mon_personnage());
CREATE POLICY forum_posts_lecture ON public.forum_posts FOR SELECT TO PUBLIC
  USING (true);
CREATE POLICY forum_posts_maj_auteur ON public.forum_posts FOR UPDATE TO authenticated
  USING (author = mon_personnage() OR author_real = mon_personnage())
  WITH CHECK (author = mon_personnage() OR author_real = mon_personnage());
CREATE POLICY forum_posts_suppression_auteur ON public.forum_posts FOR DELETE TO authenticated
  USING (author = mon_personnage() OR author_real = mon_personnage());

-- forum_topics
CREATE POLICY forum_topics_creation ON public.forum_topics FOR INSERT TO authenticated
  WITH CHECK (author = mon_personnage() OR author_real = mon_personnage());
CREATE POLICY forum_topics_lecture ON public.forum_topics FOR SELECT TO PUBLIC
  USING (true);
CREATE POLICY forum_topics_maj_auteur ON public.forum_topics FOR UPDATE TO authenticated
  USING (author = mon_personnage() OR author_real = mon_personnage())
  WITH CHECK (author = mon_personnage() OR author_real = mon_personnage());
CREATE POLICY forum_topics_suppression_auteur ON public.forum_topics FOR DELETE TO authenticated
  USING (author = mon_personnage() OR author_real = mon_personnage());

-- lectures_chat
CREATE POLICY lectures_chat_majour ON public.lectures_chat FOR UPDATE TO authenticated
  USING (membre = mon_personnage())
  WITH CHECK (membre = mon_personnage());
CREATE POLICY lectures_chat_poser ON public.lectures_chat FOR INSERT TO authenticated
  WITH CHECK (membre = mon_personnage());
CREATE POLICY lectures_chat_sienne ON public.lectures_chat FOR SELECT TO authenticated
  USING (membre = mon_personnage());

-- mails
CREATE POLICY mails_envoi ON public.mails FOR INSERT TO authenticated
  WITH CHECK (from_player = mon_personnage() OR from_real = mon_personnage() OR mail_expediteur_organisation(from_player) OR mail_expediteur_autorise(from_player, to_player));
CREATE POLICY mails_lecture_partie ON public.mails FOR SELECT TO authenticated
  USING (to_player = mon_personnage() OR from_player = mon_personnage() OR from_real = mon_personnage());
CREATE POLICY mails_maj_partie ON public.mails FOR UPDATE TO authenticated
  USING (to_player = mon_personnage() OR from_player = mon_personnage())
  WITH CHECK (to_player = mon_personnage() OR from_player = mon_personnage());
CREATE POLICY mails_suppression_partie ON public.mails FOR DELETE TO authenticated
  USING (to_player = mon_personnage() OR from_player = mon_personnage());

-- messages_chat
CREATE POLICY messages_chat_envoi ON public.messages_chat FOR INSERT TO authenticated
  WITH CHECK (auteur = mon_personnage() AND chat_participe(conversation_id, salon));
CREATE POLICY messages_chat_lecture_partie ON public.messages_chat FOR SELECT TO authenticated
  USING (chat_participe(conversation_id, salon));

-- salons_chat
CREATE POLICY salons_chat_creation ON public.salons_chat FOR INSERT TO authenticated
  WITH CHECK (createur = mon_personnage());
CREATE POLICY salons_chat_lecture_membre ON public.salons_chat FOR SELECT TO authenticated
  USING (chat_est_membre_salon(id) OR createur = mon_personnage());

-- salons_membres
CREATE POLICY salons_membres_lecture ON public.salons_membres FOR SELECT TO authenticated
  USING (membre = mon_personnage() OR chat_est_membre_salon(salon_id));
CREATE POLICY salons_membres_quitter ON public.salons_membres FOR DELETE TO authenticated
  USING (membre = mon_personnage());
CREATE POLICY salons_membres_rejoindre ON public.salons_membres FOR INSERT TO authenticated
  WITH CHECK (membre = mon_personnage());
