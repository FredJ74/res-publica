-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 11 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   actions_tracables_pkey  (contrainte actions_tracables_pkey)
--   demandes_grace_pkey  (contrainte demandes_grace_pkey)
--   detentions_pkey  (contrainte detentions_pkey)
--   impacts_indices_attente_id_unique  (contrainte impacts_indices_attente_id_unique)
--   impacts_indices_attente_pkey  (contrainte impacts_indices_attente_pkey)
--   jugements_pkey  (contrainte jugements_pkey)
--   niveaux_prison_pkey  (contrainte niveaux_prison_pkey)
--   plaintes_en_cours_pkey  (contrainte plaintes_en_cours_pkey)
--   prisonniers_qhs_pkey  (contrainte prisonniers_qhs_pkey)
--   rumeurs_actives_pkey  (contrainte rumeurs_actives_pkey)
--   vols_en_attente_pkey  (contrainte vols_en_attente_pkey)

-- Index autonomes :
CREATE INDEX idx_actions_tracables_pays ON public.actions_tracables USING btree (country, city);
CREATE INDEX jugements_accuse_actifs ON public.jugements USING btree (accuse) WHERE (executee = false);
