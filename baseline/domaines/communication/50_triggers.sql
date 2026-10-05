-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine communication -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER trg_forum_verrou_message_ligue BEFORE INSERT ON forum_posts FOR EACH ROW EXECUTE FUNCTION forum_verrou_message_ligue();
CREATE TRIGGER trg_forum_local_territorial BEFORE INSERT ON forum_topics FOR EACH ROW EXECUTE FUNCTION forum_verrou_local_territorial();
CREATE TRIGGER trg_forum_verrou_compte_rendu BEFORE INSERT ON forum_topics FOR EACH ROW EXECUTE FUNCTION forum_verrou_compte_rendu_journee();
CREATE TRIGGER trg_forum_verrou_programme BEFORE INSERT ON forum_topics FOR EACH ROW EXECUTE FUNCTION forum_verrou_programme_officiel();
CREATE TRIGGER trg_mails_journaliser_envoi_systeme BEFORE INSERT ON mails FOR EACH ROW EXECUTE FUNCTION mails_journaliser_envoi_systeme();
