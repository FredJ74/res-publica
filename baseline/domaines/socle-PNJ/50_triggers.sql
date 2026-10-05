-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle PNJ -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER trg_pnj_garde_suppression BEFORE DELETE ON pnj_membres FOR EACH ROW EXECUTE FUNCTION pnj_garde_suppression();
CREATE TRIGGER trg_pnj_pas_de_sous_hierarchie BEFORE INSERT OR UPDATE ON pnj_membres FOR EACH ROW EXECUTE FUNCTION pnj_pas_de_sous_hierarchie();
