-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine sport -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER trg_championnat_verrou_calendrier BEFORE UPDATE ON championnat FOR EACH ROW EXECUTE FUNCTION championnat_verrou_calendrier();
