-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine personnage et presence -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 30 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   contacts_organisations_passeurs_pkey  (contrainte contacts_organisations_passeurs_pkey)
--   contacts_organisations_pkey  (contrainte contacts_organisations_pkey)
--   demandes_mariage_pkey  (contrainte demandes_mariage_pkey)
--   demandes_naturalisation_pkey  (contrainte demandes_naturalisation_pkey)
--   dons_en_attente_pkey  (contrainte dons_en_attente_pkey)
--   dons_requetes_pkey  (contrainte dons_requetes_pkey)
--   escort_evenements_commerciaux_pkey  (contrainte escort_evenements_commerciaux_pkey)
--   escorts_agences_pkey  (contrainte escorts_agences_pkey)
--   escorts_catalogue_pays_nom_key  (contrainte escorts_catalogue_pays_nom_key)
--   escorts_catalogue_pkey  (contrainte escorts_catalogue_pkey)
--   etat_civil_deces_pkey  (contrainte etat_civil_deces_pkey)
--   etat_civil_naissances_pkey  (contrainte etat_civil_naissances_pkey)
--   fiche_hausses_observees_pkey  (contrainte fiche_hausses_observees_pkey)
--   fiche_inventaire_observe_pkey  (contrainte fiche_inventaire_observe_pkey)
--   historique_deplacements_pkey  (contrainte historique_deplacements_pkey)
--   invitations_diner_pkey  (contrainte invitations_diner_pkey)
--   mariages_pkey  (contrainte mariages_pkey)
--   objets_abandonnes_pkey  (contrainte objets_abandonnes_pkey)
--   objets_recus_pkey  (contrainte objets_recus_pkey)
--   organisations_pkey  (contrainte organisations_pkey)
--   personnages_name_key  (contrainte personnages_name_key)
--   personnages_pkey  (contrainte personnages_pkey)
--   personnages_supprimes_pkey  (contrainte personnages_supprimes_pkey)
--   presences_pkey  (contrainte presences_pkey)
--   quetes_actives_pkey  (contrainte quetes_actives_pkey)
--   reconciliation_fantomes_pkey  (contrainte reconciliation_fantomes_pkey)
--   souvenirs_accueil_pkey  (contrainte souvenirs_accueil_pkey)
--   successions_pkey  (contrainte successions_pkey)
--   testaments_pkey  (contrainte testaments_pkey)
--   tournees_pkey  (contrainte tournees_pkey)

-- Index autonomes :
CREATE INDEX escorts_catalogue_ecran ON public.escorts_catalogue USING btree (pays, genre, actif, rang);
CREATE INDEX fiche_hausses_observees_colonne_idx ON public.fiche_hausses_observees USING btree (colonne, vu_le DESC);
CREATE INDEX idx_deplacements_lieu ON public.historique_deplacements USING btree (country, city, building_id, created_at DESC);
CREATE INDEX idx_deplacements_personne ON public.historique_deplacements USING btree (name, created_at DESC);
CREATE INDEX idx_escort_evenements_client_escort_expiration ON public.escort_evenements_commerciaux USING btree (client, escort, jour_expiration);
CREATE INDEX idx_escort_evenements_escort_expiration ON public.escort_evenements_commerciaux USING btree (escort, jour_expiration);
CREATE INDEX idx_objets_recus_destinataire ON public.objets_recus USING btree (destinataire);
CREATE INDEX idx_personnages_supprimes_nom ON public.personnages_supprimes USING btree (nom, supprime_le DESC);
CREATE INDEX idx_presences_room ON public.presences USING btree (country, city, building_id, room_id);
CREATE INDEX idx_successions_conjoint ON public.successions USING btree (conjoint);
CREATE INDEX idx_successions_country_statut ON public.successions USING btree (country, statut);
CREATE INDEX idx_successions_defunt ON public.successions USING btree (defunt);
CREATE UNIQUE INDEX idx_successions_defunt_en_attente ON public.successions USING btree (defunt) WHERE (statut = 'en_attente'::text);
CREATE INDEX idx_testaments_testateur ON public.testaments USING btree (testateur);
CREATE INDEX personnages_requisition_idx ON public.personnages_donnees USING btree (((requisition ->> 'statut'::text))) WHERE (requisition IS NOT NULL);
CREATE UNIQUE INDEX personnages_user_id_unique ON public.personnages_donnees USING btree (user_id) WHERE (user_id IS NOT NULL);
