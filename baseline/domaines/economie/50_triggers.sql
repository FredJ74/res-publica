-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine economie -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER trg_assemblee_fret_vente_legale BEFORE UPDATE OF statut ON caisses_fret FOR EACH ROW EXECUTE FUNCTION assemblee_fret_vente_legale();
CREATE TRIGGER trg_ventes_snapshots_append_only BEFORE DELETE OR UPDATE ON ventes_snapshots FOR EACH ROW EXECUTE FUNCTION ventes_snapshots_append_only();
