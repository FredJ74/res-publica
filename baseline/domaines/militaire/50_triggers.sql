-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine militaire -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER trg_pnj_garde_dissolution_compagnie BEFORE DELETE ON compagnies_militaires FOR EACH ROW EXECUTE FUNCTION pnj_garde_dissolution_compagnie();
CREATE TRIGGER trg_pnj_miroir_compagnie AFTER INSERT OR UPDATE ON compagnies_militaires FOR EACH ROW EXECUTE FUNCTION pnj_miroir_compagnie_trg();
