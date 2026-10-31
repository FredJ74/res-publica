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

CREATE TRIGGER demandes_mariage_ecran_refuser BEFORE INSERT OR DELETE OR UPDATE ON demandes_mariage FOR EACH ROW EXECUTE FUNCTION mariage_ecriture_ecran_refuser();
CREATE TRIGGER invitation_tournee_contrat_protege BEFORE INSERT OR DELETE OR UPDATE ON invitations_diner FOR EACH ROW EXECUTE FUNCTION tournee_proteger_contrat();
CREATE TRIGGER invitations_restaurant_protege BEFORE INSERT OR DELETE OR UPDATE ON invitations_diner FOR EACH ROW EXECUTE FUNCTION restaurant_diner_proteger();
CREATE TRIGGER mariages_ecran_refuser BEFORE INSERT OR DELETE OR UPDATE ON mariages FOR EACH ROW EXECUTE FUNCTION mariage_ecriture_ecran_refuser();
CREATE TRIGGER trg_organisations_politique_autorite BEFORE INSERT OR DELETE OR UPDATE ON organisations FOR EACH ROW EXECUTE FUNCTION organisations_politique_autorite();
CREATE TRIGGER trg_personnages_vue_inserer INSTEAD OF INSERT ON personnages FOR EACH ROW EXECUTE FUNCTION personnages_vue_inserer();
CREATE TRIGGER trg_personnages_vue_modifier INSTEAD OF UPDATE ON personnages FOR EACH ROW EXECUTE FUNCTION personnages_vue_modifier();
CREATE TRIGGER trg_personnages_vue_supprimer INSTEAD OF DELETE ON personnages FOR EACH ROW EXECUTE FUNCTION personnages_vue_supprimer();
CREATE TRIGGER logements_sociaux_domicile_resilier AFTER UPDATE OF domicile ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION logements_sociaux_domicile_resilier();
CREATE TRIGGER terrain_visites_deplacement AFTER UPDATE OF country, current_city, current_building ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION terrain_visites_clore_interne();
CREATE TRIGGER trg_personnage_pays_declare BEFORE INSERT OR UPDATE OF country ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnage_pays_declare();
CREATE TRIGGER trg_personnages_archiver_suppression BEFORE DELETE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_archiver_suppression();
CREATE TRIGGER trg_personnages_attester_poste BEFORE INSERT OR UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_attester_poste();
CREATE TRIGGER trg_personnages_borner_jour BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_borner_jour();
CREATE TRIGGER trg_personnages_fusionner_pop BEFORE INSERT OR UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_fusionner_pop();
CREATE TRIGGER trg_personnages_informateurs_garder BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_informateurs_garder();
CREATE TRIGGER trg_personnages_lien_militaire_rompu AFTER UPDATE OF poste ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_lien_militaire_rompu();
CREATE TRIGGER trg_personnages_lien_militaire_supprime BEFORE DELETE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_lien_militaire_supprime();
CREATE TRIGGER trg_personnages_lier_proprietaire BEFORE INSERT OR UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_lier_proprietaire();
CREATE TRIGGER trg_personnages_observer_inventaire BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_observer_inventaire();
CREATE TRIGGER trg_personnages_poste_perdu AFTER UPDATE OF poste ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_poste_perdu();
CREATE TRIGGER trg_personnages_preserver_judiciaire BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_preserver_judiciaire();
CREATE TRIGGER trg_personnages_proteger_refugie BEFORE UPDATE OF est_emprisonne ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_proteger_refugie();
CREATE TRIGGER trg_personnages_zz_convocations_garder BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_convocations_garder();
CREATE TRIGGER zzzz_hg_inventory_revision BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION inventaire_revision_garder();
CREATE TRIGGER tournee_contrat_protege BEFORE INSERT OR DELETE OR UPDATE ON tournees FOR EACH ROW EXECUTE FUNCTION tournee_proteger_contrat();
