-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine divers et technique -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER trg_admin_journal_append_only BEFORE DELETE OR UPDATE ON admin_journal FOR EACH ROW EXECUTE FUNCTION admin_journal_append_only();
