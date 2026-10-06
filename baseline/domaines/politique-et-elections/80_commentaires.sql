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
COMMENT ON FUNCTION public.postes_nommes_regles_empreinte_reelle() IS 'Empreinte reelle du miroir des regles de nomination, sur les cinq colonnes et sur la valeur effective de autorite_scope (coalesce(autorite_scope, scope)), celle que lit poste_autorite_de. Pendant SQL de outils/generateurs/generer_postes_nommes.py. Chantier 4C.';
