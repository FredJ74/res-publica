-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON COLUMN public.detentions.provenance IS 'NULL = detention d''un PJ (comportement historique). Sinon, systeme PNJ proprietaire de l''etat de la cible, ex. agent_renseignement.';
