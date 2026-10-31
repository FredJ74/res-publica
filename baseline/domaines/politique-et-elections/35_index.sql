-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine politique et elections -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 23 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   candidatures_pkey  (contrainte candidatures_pkey)
--   communications_salles_pkey  (contrainte communications_salles_pkey)
--   conferences_jours_pkey  (contrainte conferences_jours_pkey)
--   conferences_presse_echanges_pkey  (contrainte conferences_presse_echanges_pkey)
--   conferences_presse_pkey  (contrainte conferences_presse_pkey)
--   cycles_electoraux_pkey  (contrainte cycles_electoraux_pkey)
--   demandes_manifestation_pkey  (contrainte demandes_manifestation_pkey)
--   elections_tracts_pnj_cycle_id_tour_pnj_cle_key  (contrainte elections_tracts_pnj_cycle_id_tour_pnj_cle_key)
--   elections_tracts_pnj_pkey  (contrainte elections_tracts_pnj_pkey)
--   fraudes_electorales_pkey  (contrainte fraudes_electorales_pkey)
--   greves_generales_pkey  (contrainte greves_generales_pkey)
--   indices_villes_pkey  (contrainte indices_villes_pkey)
--   mandats_maires_archives_pkey  (contrainte mandats_maires_archives_pkey)
--   militants_recrutes_pkey  (contrainte militants_recrutes_pkey)
--   presidence_memoire_ordres_pkey  (contrainte presidence_memoire_ordres_pkey)
--   presidence_memoire_pkey  (contrainte presidence_memoire_pkey)
--   presidence_memoire_sources_absentes_pkey  (contrainte presidence_memoire_sources_absentes_pkey)
--   presidence_memoire_sources_pkey  (contrainte presidence_memoire_sources_pkey)
--   rp_epoques_pkey  (contrainte rp_epoques_pkey)
--   rp_transitions_pkey  (contrainte rp_transitions_pkey)
--   votes_confiance_bulletins_pkey  (contrainte votes_confiance_bulletins_pkey)
--   votes_confiance_pkey  (contrainte votes_confiance_pkey)
--   votes_electoraux_pkey  (contrainte votes_electoraux_pkey)

-- Index autonomes :
CREATE INDEX candidatures_par_scrutin ON public.candidatures USING btree (country, poste_id, city, cle_scrutin);
CREATE INDEX conference_par_pays_et_date ON public.conferences_presse USING btree (pays, ouverte_le DESC);
CREATE UNIQUE INDEX conference_une_seule_ouverte_par_auteur ON public.conferences_presse USING btree (pays, auteur) WHERE (statut = 'ouverte'::text);
CREATE INDEX elections_tracts_pnj_cycle_tour ON public.elections_tracts_pnj USING btree (cycle_id, tour);
CREATE INDEX fraudes_electorales_scrutin_idx ON public.fraudes_electorales USING btree (country, poste_id, city, cycle_debut, type);
CREATE INDEX idx_greves_generales_country_statut ON public.greves_generales USING btree (country, statut);
CREATE INDEX mandats_maires_archives_ville_idx ON public.mandats_maires_archives USING btree (country, city, debut_ts DESC);
CREATE INDEX presidence_memoire_par_mandat ON public.presidence_memoire USING btree (pays, president, mandat_depuis, le);
CREATE INDEX votes_confiance_country_statut_idx ON public.votes_confiance USING btree (country, statut);
CREATE INDEX votes_confiance_statut_idx ON public.votes_confiance USING btree (statut);
CREATE INDEX votes_electoraux_par_tour ON public.votes_electoraux USING btree (country, poste_id, city, tour);
