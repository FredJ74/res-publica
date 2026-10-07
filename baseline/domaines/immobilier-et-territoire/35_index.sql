-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine immobilier et territoire -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 12 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   batiments_etat_pkey  (contrainte batiments_etat_pkey)
--   batiments_fermes_pkey  (contrainte batiments_fermes_pkey)
--   dossiers_urbanisme_pkey  (contrainte dossiers_urbanisme_pkey)
--   locations_actives_pkey  (contrainte locations_actives_pkey)
--   locations_archives_pkey  (contrainte locations_archives_pkey)
--   logements_attributions_historique_pkey  (contrainte logements_attributions_historique_pkey)
--   logements_demandes_pkey  (contrainte logements_demandes_pkey)
--   reservations_salle_reception_pkey  (contrainte reservations_salle_reception_pkey)
--   terrains_etat_pkey  (contrainte terrains_etat_pkey)
--   terrains_historique_ventes_pkey  (contrainte terrains_historique_ventes_pkey)
--   villes_empreinte_pkey  (contrainte villes_empreinte_pkey)
--   villes_pkey  (contrainte villes_pkey)

-- Index autonomes :
CREATE INDEX dossiers_urbanisme_commune_idx ON public.dossiers_urbanisme USING btree (country, city, created_at);
CREATE INDEX dossiers_urbanisme_numero_idx ON public.dossiers_urbanisme USING btree (numero_dossier);
CREATE INDEX dossiers_urbanisme_terrain_idx ON public.dossiers_urbanisme USING btree (country, building_id);
CREATE INDEX idx_batiments_etat_lookup ON public.batiments_etat USING btree (country, city, building_id);
CREATE INDEX idx_batiments_fermes_pays_ville ON public.batiments_fermes USING btree (pays, ville);
CREATE INDEX locations_archives_bail_idx ON public.locations_archives USING btree (bail_id);
CREATE INDEX locations_archives_fonds_idx ON public.locations_archives USING btree (fonds_id);
CREATE INDEX locations_archives_lieu_idx ON public.locations_archives USING btree (country, city, building_id);
CREATE INDEX locations_archives_titulaire_idx ON public.locations_archives USING btree (locataire);
