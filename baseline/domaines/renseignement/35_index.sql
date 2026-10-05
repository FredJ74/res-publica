-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine renseignement -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 9 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   agent_tentatives_pkey  (contrainte agent_tentatives_pkey)
--   agents_renseignement_pkey  (contrainte agents_renseignement_pkey)
--   cellules_renseignement_pkey  (contrainte cellules_renseignement_pkey)
--   contre_espionnage_tentatives_pkey  (contrainte contre_espionnage_tentatives_pkey)
--   rapports_cellules_pkey  (contrainte rapports_cellules_pkey)
--   rapports_renseignement_pkey  (contrainte rapports_renseignement_pkey)
--   renseignement_couvertures_pkey  (contrainte renseignement_couvertures_pkey)
--   renseignement_identites_reelles_pkey  (contrainte renseignement_identites_reelles_pkey)
--   renseignements_connus_pkey  (contrainte renseignements_connus_pkey)

-- Index autonomes :
CREATE INDEX idx_agents_cellule ON public.agents_renseignement USING btree (cellule_id);
CREATE UNIQUE INDEX idx_agents_couverture_unique ON public.agents_renseignement USING btree (pays_couverture, nom_couverture) WHERE (statut = ANY (ARRAY['actif'::text, 'detenu'::text]));
CREATE INDEX idx_agents_leader ON public.agents_renseignement USING btree (leader_courant) WHERE (leader_courant IS NOT NULL);
CREATE INDEX idx_agents_position ON public.agents_renseignement USING btree (pays, ville, building_id) WHERE (statut = 'actif'::text);
CREATE UNIQUE INDEX idx_agents_role_unique ON public.agents_renseignement USING btree (cellule_id, role);
CREATE INDEX idx_cellules_actives ON public.cellules_renseignement USING btree (pays_proprietaire, echeance_le) WHERE (statut = 'active'::text);
CREATE INDEX idx_cellules_echeance ON public.cellules_renseignement USING btree (echeance_le) WHERE (statut = 'active'::text);
CREATE INDEX idx_renseignements_cible_categorie ON public.renseignements_connus USING btree (cible, categorie);
CREATE INDEX idx_renseignements_titulaire_expiration ON public.renseignements_connus USING btree (titulaire, jour_expiration);
