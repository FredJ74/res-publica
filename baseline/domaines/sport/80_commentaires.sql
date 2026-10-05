-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine sport -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON TABLE public.championnat_tentatives IS 'Journal des tentatives de resolution du championnat (chantier du 16 septembre 2026). Ecrit par le declencheur championnat_verrou_calendrier, invisible aux clients. Ne declenche aucun match.';
COMMENT ON TABLE public.entrainements_football IS 'Journal des entrainements de football reellement effectues. Une ligne = un entrainement. La limite de 2 par jour de jeu se calcule a la lecture, jamais stockee.';
COMMENT ON TABLE public.football_primes_versees IS 'Registre des primes de match versees (chantier du 16 septembre 2026). La cle primaire porte l''idempotence. Invisible aux clients.';
