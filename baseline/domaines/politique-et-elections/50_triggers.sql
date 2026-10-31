-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine politique et elections -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER candidatures_unicite_scrutin_actif BEFORE INSERT ON candidatures FOR EACH ROW EXECUTE FUNCTION candidatures_unicite_scrutin_actif();
CREATE TRIGGER trg_candidatures_cloture BEFORE INSERT ON candidatures FOR EACH ROW EXECUTE FUNCTION candidatures_cloture();
CREATE TRIGGER trg_cycles_electoraux_dimanche BEFORE INSERT OR UPDATE OF data ON cycles_electoraux FOR EACH ROW EXECUTE FUNCTION cycles_electoraux_dimanche();
CREATE TRIGGER indices_villes_piete_du_registre BEFORE INSERT OR UPDATE ON indices_villes FOR EACH ROW EXECUTE FUNCTION indices_villes_piete_du_registre();
