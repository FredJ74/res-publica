-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine finances publiques -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER budgets_armurerie_verrou BEFORE UPDATE ON budgets_nationaux FOR EACH ROW EXECUTE FUNCTION budgets_armurerie_verrou();
CREATE TRIGGER budgets_virement_caserne_verrou BEFORE UPDATE ON budgets_nationaux FOR EACH ROW EXECUTE FUNCTION budgets_virement_caserne_verrou();
CREATE TRIGGER trg_budget_national_epingler BEFORE UPDATE ON budgets_nationaux FOR EACH ROW EXECUTE FUNCTION budget_national_epingler();
