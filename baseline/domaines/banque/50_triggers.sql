-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine banque -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER pret_versionne_ecriture BEFORE INSERT OR DELETE OR UPDATE ON prets FOR EACH ROW EXECUTE FUNCTION pret_versionne_ecriture_proteger();
CREATE TRIGGER prets_ecriture_ecran_garder BEFORE INSERT OR DELETE OR UPDATE ON prets FOR EACH ROW EXECUTE FUNCTION prets_ecriture_ecran_garder();
