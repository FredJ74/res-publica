-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine personnage et presence -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER trg_personnages_vue_inserer INSTEAD OF INSERT ON personnages FOR EACH ROW EXECUTE FUNCTION personnages_vue_inserer();
CREATE TRIGGER trg_personnages_vue_modifier INSTEAD OF UPDATE ON personnages FOR EACH ROW EXECUTE FUNCTION personnages_vue_modifier();
CREATE TRIGGER trg_personnages_vue_supprimer INSTEAD OF DELETE ON personnages FOR EACH ROW EXECUTE FUNCTION personnages_vue_supprimer();
CREATE TRIGGER trg_personnage_pays_declare BEFORE INSERT OR UPDATE OF country ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnage_pays_declare();
CREATE TRIGGER trg_personnages_archiver_suppression BEFORE DELETE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_archiver_suppression();
CREATE TRIGGER trg_personnages_attester_poste BEFORE INSERT OR UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_attester_poste();
CREATE TRIGGER trg_personnages_borner_jour BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_borner_jour();
CREATE TRIGGER trg_personnages_fusionner_pop BEFORE INSERT OR UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_fusionner_pop();
CREATE TRIGGER trg_personnages_lien_militaire_rompu AFTER UPDATE OF poste ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_lien_militaire_rompu();
CREATE TRIGGER trg_personnages_lien_militaire_supprime BEFORE DELETE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_lien_militaire_supprime();
CREATE TRIGGER trg_personnages_lier_proprietaire BEFORE INSERT OR UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_lier_proprietaire();
CREATE TRIGGER trg_personnages_observer_inventaire BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_observer_inventaire();
CREATE TRIGGER trg_personnages_poste_perdu AFTER UPDATE OF poste ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_poste_perdu();
CREATE TRIGGER trg_personnages_preserver_judiciaire BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_preserver_judiciaire();
