-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine presse -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER trg_journal_edition_rattacher BEFORE INSERT ON journal_editions FOR EACH ROW EXECUTE FUNCTION journal_edition_rattacher_au_titre();
CREATE TRIGGER trg_presse_delegations_purger_depart AFTER DELETE ON presse_membres FOR EACH ROW EXECUTE FUNCTION presse_delegations_purger();
CREATE TRIGGER trg_presse_delegations_purger_grade AFTER UPDATE OF grade ON presse_membres FOR EACH ROW EXECUTE FUNCTION presse_delegations_purger();
CREATE TRIGGER trg_presse_succession AFTER DELETE ON presse_membres FOR EACH ROW EXECUTE FUNCTION presse_succession_apres_depart();
