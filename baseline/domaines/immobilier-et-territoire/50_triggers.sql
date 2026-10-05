-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine immobilier et territoire -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER trg_pnj_miroir_douane AFTER INSERT OR UPDATE ON batiments_etat FOR EACH ROW EXECUTE FUNCTION pnj_miroir_douane_declencheur();
CREATE TRIGGER trg_pnj_miroir_police AFTER INSERT OR UPDATE ON batiments_etat FOR EACH ROW EXECUTE FUNCTION pnj_miroir_police_declencheur();
CREATE TRIGGER trg_bail_cle_coherente BEFORE INSERT OR UPDATE ON locations_actives FOR EACH ROW EXECUTE FUNCTION bail_cle_coherente();
