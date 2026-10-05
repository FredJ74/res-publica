-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine sport -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 9 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   championnat_pkey  (contrainte championnat_pkey)
--   championnat_tentatives_pkey  (contrainte championnat_tentatives_pkey)
--   clubs_football_pkey  (contrainte clubs_football_pkey)
--   clubs_sportifs_regles_pkey  (contrainte clubs_sportifs_regles_pkey)
--   entrainements_football_pkey  (contrainte entrainements_football_pkey)
--   football_primes_versees_pkey  (contrainte football_primes_versees_pkey)
--   paris_sportifs_pkey  (contrainte paris_sportifs_pkey)
--   presidents_clubs_pkey  (contrainte presidents_clubs_pkey)
--   transferts_clubs_pkey  (contrainte transferts_clubs_pkey)

-- Index autonomes :
CREATE INDEX entrainements_football_perso_jour ON public.entrainements_football USING btree (personnage, jour);
