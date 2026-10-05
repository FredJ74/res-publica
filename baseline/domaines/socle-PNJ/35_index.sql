-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle PNJ -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 22 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   pnj_axes_autorite_pkey  (contrainte pnj_axes_autorite_pkey)
--   pnj_candidats_catalogue_pkey  (contrainte pnj_candidats_catalogue_pkey)
--   pnj_employes_metier_pkey  (contrainte pnj_employes_metier_pkey)
--   pnj_employeurs_pkey  (contrainte pnj_employeurs_pkey)
--   pnj_evenements_pkey  (contrainte pnj_evenements_pkey)
--   pnj_familles_classes_pkey  (contrainte pnj_familles_classes_pkey)
--   pnj_fonctions_pkey  (contrainte pnj_fonctions_pkey)
--   pnj_force_publique_metier_pkey  (contrainte pnj_force_publique_metier_pkey)
--   pnj_institutions_pkey  (contrainte pnj_institutions_pkey)
--   pnj_membres_pkey  (contrainte pnj_membres_pkey)
--   pnj_metiers_profils_pkey  (contrainte pnj_metiers_profils_pkey)
--   pnj_militants_metier_pkey  (contrainte pnj_militants_metier_pkey)
--   pnj_mouvement_individuel_pkey  (contrainte pnj_mouvement_individuel_pkey)
--   pnj_possessions_pkey  (contrainte pnj_possessions_pkey)
--   pnj_referents_pedagogie_pkey  (contrainte pnj_referents_pedagogie_pkey)
--   pnj_referents_pkey  (contrainte pnj_referents_pkey)
--   pnj_referents_sujets_connus_pkey  (contrainte pnj_referents_sujets_connus_pkey)
--   pnj_social_escort_choisi_pkey  (contrainte pnj_social_escort_choisi_pkey)
--   pnj_social_jalons_regles_pkey  (contrainte pnj_social_jalons_regles_pkey)
--   pnj_social_relations_pkey  (contrainte pnj_social_relations_pkey)
--   pnj_soldats_metier_pkey  (contrainte pnj_soldats_metier_pkey)
--   pnj_transitions_pkey  (contrainte pnj_transitions_pkey)

-- Index autonomes :
CREATE INDEX idx_pnj_candidats_employeur ON public.pnj_candidats_catalogue USING btree (employeur_id, metier, rang, nom);
CREATE INDEX idx_pnj_evt_pj ON public.pnj_evenements USING btree (proprietaire_pj, lu_le) WHERE (proprietaire_pj IS NOT NULL);
CREATE INDEX idx_pnj_famille ON public.pnj_membres USING btree (famille, pays) WHERE (statut = 'actif'::text);
CREATE UNIQUE INDEX idx_pnj_fp_matricule ON public.pnj_force_publique_metier USING btree (matricule);
CREATE INDEX idx_pnj_leader_pj ON public.pnj_membres USING btree (leader_pj) WHERE (leader_pj IS NOT NULL);
CREATE INDEX idx_pnj_leader_pnj ON public.pnj_membres USING btree (leader_pnj_id) WHERE (leader_pnj_id IS NOT NULL);
CREATE INDEX idx_pnj_militants_orga ON public.pnj_militants_metier USING btree (organisation_id);
CREATE INDEX idx_pnj_position ON public.pnj_membres USING btree (pays, ville, building_id, room_id) WHERE (statut = 'actif'::text);
CREATE INDEX idx_pnj_possessions_pnj ON public.pnj_possessions USING btree (pnj_id);
CREATE INDEX idx_pnj_prop_institution ON public.pnj_membres USING btree (pays, proprietaire_institution, proprietaire_perimetre) WHERE (proprietaire_institution IS NOT NULL);
CREATE INDEX idx_pnj_prop_pj ON public.pnj_membres USING btree (proprietaire_pj) WHERE (proprietaire_pj IS NOT NULL);
CREATE INDEX idx_pnj_soldats_compagnie ON public.pnj_soldats_metier USING btree (compagnie_id, section_id);
CREATE UNIQUE INDEX idx_pnj_soldats_matricule ON public.pnj_soldats_metier USING btree (matricule);
CREATE INDEX pnj_referents_par_empire ON public.pnj_referents USING btree (pays);
