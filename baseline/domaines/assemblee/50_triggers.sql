-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine assemblee -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER trg_assemblee_proposition_immuable BEFORE UPDATE ON assemblee_propositions FOR EACH ROW EXECUTE FUNCTION assemblee_proposition_immuable();
