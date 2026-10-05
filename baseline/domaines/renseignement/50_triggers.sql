-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine renseignement -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER trg_renseignement_mission_raccorder BEFORE INSERT ON agents_renseignement FOR EACH ROW EXECUTE FUNCTION renseignement_mission_raccorder();
