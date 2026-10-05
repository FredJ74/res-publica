-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine banque -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON COLUMN public.prets.jour_dernier_prelevement IS 'Journee partagee ISO (YYYY-MM-DD) du dernier prelevement nocturne. Marqueur anti-rejeu du cron. NULL = jamais preleve.';
