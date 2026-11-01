-- Declencheurs
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 50 : triggers
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TRIGGER trg_audience_messages_append_only BEFORE DELETE OR UPDATE ON audience_messages FOR EACH ROW EXECUTE FUNCTION audience_messages_append_only();
CREATE TRIGGER trg_dossiers_auditions_append_only BEFORE DELETE OR UPDATE ON dossiers_auditions FOR EACH ROW EXECUTE FUNCTION dossiers_auditions_append_only();
CREATE TRIGGER trg_dossiers_actes_append_only BEFORE DELETE OR UPDATE ON dossiers_judiciaires_actes FOR EACH ROW EXECUTE FUNCTION dossiers_actes_append_only();
CREATE TRIGGER trg_dossiers_actes_chronique AFTER INSERT ON dossiers_judiciaires_actes FOR EACH ROW EXECUTE FUNCTION dossiers_actes_publier_au_journal();
CREATE TRIGGER amende_jugement_enregistrer AFTER INSERT ON jugements FOR EACH ROW EXECUTE FUNCTION amende_jugement_enregistrer();
CREATE TRIGGER trg_plaintes_epingler_verdict BEFORE UPDATE ON plaintes_en_cours FOR EACH ROW EXECUTE FUNCTION plaintes_epingler_verdict();
CREATE TRIGGER trg_plaintes_temoins_sur_cloture AFTER UPDATE OF data ON plaintes_en_cours FOR EACH ROW EXECUTE FUNCTION plaintes_temoins_sur_cloture();
