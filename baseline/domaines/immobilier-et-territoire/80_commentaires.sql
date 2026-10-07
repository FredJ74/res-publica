-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine immobilier et territoire -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON FUNCTION public.ville_est_reelle(text,text) IS 'Ce couple (pays, ville) designe-t-il une VRAIE ville ? Refuse les zones hors-ville (caserne, QHS), les pseudo-villes techniques et les empires inconnus. Ne replie jamais sur Republia ni sur la capitale.';
COMMENT ON TABLE public.villes IS 'Les douze vraies villes du jeu, une ligne par couple (pays, ville). Miroir de VILLES (data.js), seme par outils/generateurs/generer_villes.py. Les zones hors-ville (caserne, QHS) en sont volontairement absentes : elles ne relevent d''aucune mairie.';
