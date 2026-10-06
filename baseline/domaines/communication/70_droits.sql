-- GRANT sur tables, colonnes et fonctions
-- ============================================================================
-- BASELINE Human Gambit -- domaine communication -- phase 70 : droits
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- DROITS SUR LES FUNCTIONS
GRANT EXECUTE ON FUNCTION public.chat_est_membre_salon(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_est_membre_salon(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.chat_est_membre_salon(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_participe(text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_participe(text,boolean) TO postgres;
GRANT EXECUTE ON FUNCTION public.chat_participe(text,boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.forum_verrou_compte_rendu_journee() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.forum_verrou_compte_rendu_journee() TO postgres;
GRANT EXECUTE ON FUNCTION public.forum_verrou_compte_rendu_journee() TO service_role;
GRANT EXECUTE ON FUNCTION public.forum_verrou_local_territorial() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.forum_verrou_local_territorial() TO postgres;
GRANT EXECUTE ON FUNCTION public.forum_verrou_local_territorial() TO service_role;
GRANT EXECUTE ON FUNCTION public.forum_verrou_message_ligue() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.forum_verrou_message_ligue() TO postgres;
GRANT EXECUTE ON FUNCTION public.forum_verrou_message_ligue() TO service_role;
GRANT EXECUTE ON FUNCTION public.forum_verrou_programme_officiel() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.forum_verrou_programme_officiel() TO postgres;
GRANT EXECUTE ON FUNCTION public.forum_verrou_programme_officiel() TO service_role;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_conjoint(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_conjoint(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_conjoint(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_fret(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_fret(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_fret(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_titulaire(text,text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_titulaire(text,text[]) TO postgres;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_titulaire(text,text[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_autorise(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_autorise(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_autorise(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_autorise_strict(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_autorise_strict(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_autorise_strict(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_organisation(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_organisation(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_organisation(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_systeme(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_systeme(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_systeme(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.mail_systeme_envoyer(text,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mail_systeme_envoyer(text,text,text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.mail_systeme_envoyer(text,text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.mails_journaliser_envoi_systeme() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.mails_journaliser_envoi_systeme() TO postgres;
GRANT EXECUTE ON FUNCTION public.mails_journaliser_envoi_systeme() TO service_role;

-- DROITS SUR LES SEQUENCES
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.mails_envois_systeme_id_seq TO postgres;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.mails_envois_systeme_id_seq TO service_role;

-- DROITS SUR LES TABLES
GRANT SELECT ON TABLE public.chat_piece TO anon;
GRANT INSERT, SELECT ON TABLE public.chat_piece TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.chat_piece TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.chat_piece TO service_role;
GRANT SELECT ON TABLE public.forum_posts TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.forum_posts TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.forum_posts TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.forum_posts TO service_role;
GRANT SELECT ON TABLE public.forum_topics TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.forum_topics TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.forum_topics TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.forum_topics TO service_role;
GRANT SELECT ON TABLE public.lectures_chat TO anon;
GRANT INSERT, SELECT, UPDATE ON TABLE public.lectures_chat TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.lectures_chat TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.lectures_chat TO service_role;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.mails TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mails TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mails TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mails_envois_systeme TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mails_envois_systeme TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mails_expediteurs_systeme TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mails_expediteurs_systeme TO service_role;
GRANT SELECT ON TABLE public.messages_chat TO anon;
GRANT INSERT, SELECT ON TABLE public.messages_chat TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.messages_chat TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.messages_chat TO service_role;
GRANT SELECT ON TABLE public.salons_chat TO anon;
GRANT INSERT, SELECT ON TABLE public.salons_chat TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.salons_chat TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.salons_chat TO service_role;
GRANT SELECT ON TABLE public.salons_membres TO anon;
GRANT DELETE, INSERT, SELECT ON TABLE public.salons_membres TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.salons_membres TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.salons_membres TO service_role;
