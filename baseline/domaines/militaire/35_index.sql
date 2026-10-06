-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine militaire -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 26 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   armureries_dotations_pkey  (contrainte armureries_dotations_pkey)
--   batailles_engagements_pkey  (contrainte batailles_engagements_pkey)
--   batailles_groupes_pkey  (contrainte batailles_groupes_pkey)
--   batailles_pkey  (contrainte batailles_pkey)
--   batailles_rounds_pkey  (contrainte batailles_rounds_pkey)
--   camions_destinations_pkey  (contrainte camions_destinations_pkey)
--   camions_embarquements_pkey  (contrainte camions_embarquements_pkey)
--   camions_militaires_pkey  (contrainte camions_militaires_pkey)
--   camions_ordres_pkey  (contrainte camions_ordres_pkey)
--   candidatures_militaires_pkey  (contrainte candidatures_militaires_pkey)
--   commandes_militaires_pkey  (contrainte commandes_militaires_pkey)
--   compagnies_militaires_pkey  (contrainte compagnies_militaires_pkey)
--   contacts_militaires_pkey  (contrainte contacts_militaires_pkey)
--   decorations_militaires_pkey  (contrainte decorations_militaires_pkey)
--   engagements_militaires_pkey  (contrainte engagements_militaires_pkey)
--   guerres_pkey  (contrainte guerres_pkey)
--   militaire_armes_bonus_pkey  (contrainte militaire_armes_bonus_pkey)
--   militaire_detections_pkey  (contrainte militaire_detections_pkey)
--   militaire_terminal_requetes_pkey  (contrainte militaire_terminal_requetes_pkey)
--   mutineries_membres_pkey  (contrainte mutineries_membres_pkey)
--   mutineries_pkey  (contrainte mutineries_pkey)
--   nominations_militaires_pkey  (contrainte nominations_militaires_pkey)
--   recettes_militaires_pkey  (contrainte recettes_militaires_pkey)
--   retraits_materiel_militaire_pkey  (contrainte retraits_materiel_militaire_pkey)
--   services_militaires_pkey  (contrainte services_militaires_pkey)
--   soldes_militaires_pkey  (contrainte soldes_militaires_pkey)

-- Index autonomes :
CREATE INDEX batailles_engagements_bataille_idx ON public.batailles_engagements USING btree (bataille_id);
CREATE INDEX batailles_engagements_personnage_idx ON public.batailles_engagements USING btree (personnage) WHERE (personnage IS NOT NULL);
CREATE UNIQUE INDEX batailles_engagements_unicite_pj_idx ON public.batailles_engagements USING btree (bataille_id, personnage) WHERE (personnage IS NOT NULL);
CREATE UNIQUE INDEX batailles_engagements_unicite_pnj_idx ON public.batailles_engagements USING btree (bataille_id, compagnie_id, section_id, matricule) WHERE (matricule IS NOT NULL);
CREATE INDEX batailles_groupes_bataille_idx ON public.batailles_groupes USING btree (bataille_id) WHERE (sorti_round IS NULL);
CREATE INDEX batailles_pays_idx ON public.batailles USING btree (pays, debut_ts DESC);
CREATE UNIQUE INDEX batailles_rounds_unicite_idx ON public.batailles_rounds USING btree (bataille_id, numero, camp);
CREATE UNIQUE INDEX batailles_zone_en_cours_idx ON public.batailles USING btree (pays, ville, batiment, piece) WHERE (statut = 'en_cours'::text);
CREATE INDEX camions_militaires_position_idx ON public.camions_militaires USING btree (pays, ville, building_id, room_id);
CREATE INDEX camions_ordres_camion_idx ON public.camions_ordres USING btree (camion_id, cree_le DESC);
CREATE INDEX candidatures_militaires_actives ON public.candidatures_militaires USING btree (pays, grade_vise) WHERE (statut = 'active'::text);
CREATE UNIQUE INDEX candidatures_militaires_une_vivante_par_grade ON public.candidatures_militaires USING btree (candidat, grade_vise) WHERE (statut = ANY (ARRAY['active'::text, 'acceptee'::text]));
CREATE INDEX commandes_militaires_fifo ON public.commandes_militaires USING btree (pays, statut, created_at);
CREATE INDEX contacts_militaires_ouverts_idx ON public.contacts_militaires USING btree (etabli_le DESC) WHERE (consomme_le IS NULL);
CREATE INDEX decorations_militaires_decore_idx ON public.decorations_militaires USING btree (decore, decerne_le DESC);
CREATE UNIQUE INDEX decorations_militaires_unicite_idx ON public.decorations_militaires USING btree (decore, decerne_par, intitule);
CREATE UNIQUE INDEX mutineries_membres_un_seul_camp ON public.mutineries_membres USING btree (personnage);
CREATE INDEX retraits_materiel_militaire_pays ON public.retraits_materiel_militaire USING btree (pays, created_at DESC);
CREATE INDEX services_militaires_perso ON public.services_militaires USING btree (personnage, grade);
CREATE UNIQUE INDEX services_militaires_une_periode_ouverte ON public.services_militaires USING btree (personnage, grade) WHERE (fin_ts IS NULL);
CREATE INDEX soldes_militaires_impayees ON public.soldes_militaires USING btree (pays, personnage) WHERE (verse < du);
CREATE INDEX soldes_militaires_perso ON public.soldes_militaires USING btree (personnage);
