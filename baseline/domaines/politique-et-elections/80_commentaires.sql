-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine politique et elections -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON COLUMN public.elections_tracts_pnj.canal IS 'tract | prospectus | conference | jean_lou -- origine de la voix, pour l''audit uniquement.';
