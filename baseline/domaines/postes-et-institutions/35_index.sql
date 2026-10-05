-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine postes et institutions -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 7 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   nominations_en_attente_pkey  (contrainte nominations_en_attente_pkey)
--   nominations_poste_attente_pkey  (contrainte nominations_poste_attente_pkey)
--   postes_attribues_pkey  (contrainte postes_attribues_pkey)
--   postes_electifs_regles_pkey  (contrainte postes_electifs_regles_pkey)
--   postes_nommes_regles_empreinte_pkey  (contrainte postes_nommes_regles_empreinte_pkey)
--   postes_nommes_regles_pkey  (contrainte postes_nommes_regles_pkey)
--   titulaires_pnj_pkey  (contrainte titulaires_pnj_pkey)

-- Index autonomes :
CREATE INDEX postes_attribues_titulaire ON public.postes_attribues USING btree (titulaire);
