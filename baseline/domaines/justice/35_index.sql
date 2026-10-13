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

-- 32 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   actions_tracables_pkey  (contrainte actions_tracables_pkey)
--   audience_messages_pkey  (contrainte audience_messages_pkey)
--   audience_paroles_pk  (contrainte audience_paroles_pk)
--   avocats_barreau_pk  (contrainte avocats_barreau_pk)
--   defenses_demandes_pk  (contrainte defenses_demandes_pk)
--   demandes_grace_pkey  (contrainte demandes_grace_pkey)
--   detentions_pkey  (contrainte detentions_pkey)
--   documents_officiels_pkey  (contrainte documents_officiels_pkey)
--   dossiers_actes_un_rang_par_affaire  (contrainte dossiers_actes_un_rang_par_affaire)
--   dossiers_auditions_pkey  (contrainte dossiers_auditions_pkey)
--   dossiers_auditions_un_pv_par_affaire_et_personne  (contrainte dossiers_auditions_un_pv_par_affaire_et_personne)
--   dossiers_judiciaires_actes_pkey  (contrainte dossiers_judiciaires_actes_pkey)
--   dossiers_judiciaires_actes_types_pkey  (contrainte dossiers_judiciaires_actes_types_pkey)
--   greffes_tribunaux_pkey  (contrainte greffes_tribunaux_pkey)
--   impacts_indices_attente_id_unique  (contrainte impacts_indices_attente_id_unique)
--   impacts_indices_attente_pkey  (contrainte impacts_indices_attente_pkey)
--   infractions_alias_pkey  (contrainte infractions_alias_pkey)
--   infractions_categories_pkey  (contrainte infractions_categories_pkey)
--   infractions_empreinte_pkey  (contrainte infractions_empreinte_pkey)
--   infractions_pkey  (contrainte infractions_pkey)
--   jugements_pkey  (contrainte jugements_pkey)
--   justice_avocats_commis_pk  (contrainte justice_avocats_commis_pk)
--   justice_faits_publics_pkey  (contrainte justice_faits_publics_pkey)
--   justice_indemnites_pkey  (contrainte justice_indemnites_pkey)
--   niveaux_prison_pkey  (contrainte niveaux_prison_pkey)
--   plaintes_en_cours_pkey  (contrainte plaintes_en_cours_pkey)
--   prisonniers_qhs_pkey  (contrainte prisonniers_qhs_pkey)
--   rumeurs_actives_pkey  (contrainte rumeurs_actives_pkey)
--   signalements_police_pkey  (contrainte signalements_police_pkey)
--   temoins_citations_pk  (contrainte temoins_citations_pk)
--   temoins_citations_une_par_affaire  (contrainte temoins_citations_une_par_affaire)
--   vols_en_attente_pkey  (contrainte vols_en_attente_pkey)

-- Index autonomes :
CREATE INDEX audience_messages_par_affaire ON public.audience_messages USING btree (affaire, rang);
CREATE UNIQUE INDEX defenses_un_avocat_retenu_par_affaire ON public.defenses_demandes USING btree (affaire) WHERE (etat = 'acceptee'::text);
CREATE UNIQUE INDEX defenses_une_demande_vivante_par_couple ON public.defenses_demandes USING btree (affaire, avocat) WHERE (etat = 'en_attente'::text);
CREATE INDEX documents_officiels_porteur_idx ON public.documents_officiels USING btree (porteur);
CREATE INDEX dossiers_actes_par_affaire ON public.dossiers_judiciaires_actes USING btree (affaire, rang);
CREATE INDEX dossiers_auditions_par_personne ON public.dossiers_auditions USING btree (personne, affaire);
CREATE INDEX idx_actions_tracables_pays ON public.actions_tracables USING btree (country, city);
CREATE INDEX jugements_accuse_actifs ON public.jugements USING btree (accuse) WHERE (executee = false);
CREATE INDEX justice_indemnites_file_fifo ON public.justice_indemnites USING btree (pays, etat, rang);
CREATE INDEX signalements_police_par_signaleur ON public.signalements_police USING btree (signaleur, pose_le DESC);
CREATE UNIQUE INDEX signalements_police_un_vivant_par_cible ON public.signalements_police USING btree (pays, cible) WHERE (resolu_le IS NULL);
