-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine economie -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 43 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   apports_matieres_pkey  (contrainte apports_matieres_pkey)
--   caisses_fret_pkey  (contrainte caisses_fret_pkey)
--   catalogue_correspondance_legacy_motif_valeur_key  (contrainte catalogue_correspondance_legacy_motif_valeur_key)
--   catalogue_correspondance_legacy_pkey  (contrainte catalogue_correspondance_legacy_pkey)
--   catalogue_familles_pkey  (contrainte catalogue_familles_pkey)
--   catalogue_generique_type_pkey  (contrainte catalogue_generique_type_pkey)
--   catalogue_generiques_pkey  (contrainte catalogue_generiques_pkey)
--   catalogue_types_pkey  (contrainte catalogue_types_pkey)
--   catalogue_variantes_generique_id_cle_key  (contrainte catalogue_variantes_generique_id_cle_key)
--   catalogue_variantes_pkey  (contrainte catalogue_variantes_pkey)
--   chaines_production_usine_pkey  (contrainte chaines_production_usine_pkey)
--   chantiers_besoins_jour_pkey  (contrainte chantiers_besoins_jour_pkey)
--   chantiers_paliers_pkey  (contrainte chantiers_paliers_pkey)
--   commerces_dotations_pkey  (contrainte commerces_dotations_pkey)
--   commerces_types_pkey  (contrainte commerces_types_pkey)
--   confiscations_douanieres_pkey  (contrainte confiscations_douanieres_pkey)
--   contenu_caisses_fret_pkey  (contrainte contenu_caisses_fret_pkey)
--   directeurs_usine_pkey  (contrainte directeurs_usine_pkey)
--   entrepot_journal_pkey  (contrainte entrepot_journal_pkey)
--   entrepot_transits_pkey  (contrainte entrepot_transits_pkey)
--   entrepots_par_ville_pkey  (contrainte entrepots_par_ville_pkey)
--   entrepots_reversements_pkey  (contrainte entrepots_reversements_pkey)
--   entreprises_constantes_pkey  (contrainte entreprises_constantes_pkey)
--   entreprises_pkey  (contrainte entreprises_pkey)
--   entreprises_prix_rachat_pkey  (contrainte entreprises_prix_rachat_pkey)
--   imprimeries_declarees_pkey  (contrainte imprimeries_declarees_pkey)
--   investissements_pkey  (contrainte investissements_pkey)
--   oeuvres_pkey  (contrainte oeuvres_pkey)
--   offres_pkey  (contrainte offres_pkey)
--   ordres_couts_ecarts_pkey  (contrainte ordres_couts_ecarts_pkey)
--   ordres_couts_empreinte_pkey  (contrainte ordres_couts_empreinte_pkey)
--   ordres_couts_inconnus_pkey  (contrainte ordres_couts_inconnus_pkey)
--   ordres_couts_pkey  (contrainte ordres_couts_pkey)
--   productions_references_pkey  (contrainte productions_references_pkey)
--   produits_manufactures_pkey  (contrainte produits_manufactures_pkey)
--   recettes_commerce_pkey  (contrainte recettes_commerce_pkey)
--   recettes_production_pkey  (contrainte recettes_production_pkey)
--   ressources_economie_empreinte_pkey  (contrainte ressources_economie_empreinte_pkey)
--   ressources_economie_pkey  (contrainte ressources_economie_pkey)
--   structures_medicales_pkey  (contrainte structures_medicales_pkey)
--   usines_rachat_config_pkey  (contrainte usines_rachat_config_pkey)
--   ventes_snapshots_pkey  (contrainte ventes_snapshots_pkey)
--   ventes_snapshots_requete_key  (contrainte ventes_snapshots_requete_key)

-- Index autonomes :
CREATE INDEX apports_matieres_fonds_idx ON public.apports_matieres USING btree (fonds_id, cree_le DESC);
CREATE INDEX idx_caisses_fret_destinataire ON public.caisses_fret USING btree (destinataire);
CREATE INDEX idx_caisses_fret_pays_destination ON public.caisses_fret USING btree (pays_destination);
CREATE INDEX idx_caisses_fret_statut ON public.caisses_fret USING btree (statut);
CREATE INDEX idx_confiscations_lieu ON public.confiscations_douanieres USING btree (pays, ville, building_id, cree_le DESC);
CREATE INDEX idx_confiscations_personne ON public.confiscations_douanieres USING btree (personne, cree_le DESC);
CREATE INDEX idx_contenu_caisses_fret_caisse ON public.contenu_caisses_fret USING btree (caisse_id);
CREATE INDEX idx_contenu_caisses_fret_deposant ON public.contenu_caisses_fret USING btree (deposant);
CREATE INDEX idx_corresp_legacy_generique ON public.catalogue_correspondance_legacy USING btree (generique_id);
CREATE INDEX idx_journal_entrepot ON public.entrepot_journal USING btree (entrepot_id, horodatage DESC);
CREATE INDEX idx_productions_references_fonds ON public.productions_references USING btree (fonds_id, reference_id);
CREATE INDEX idx_transits_arrivee ON public.entrepot_transits USING btree (arrivee_le);
CREATE INDEX idx_transits_destination ON public.entrepot_transits USING btree (destination_id, ressource);
CREATE INDEX idx_ventes_snapshots_acheteur ON public.ventes_snapshots USING btree (acheteur, vendu_le DESC);
CREATE INDEX idx_ventes_snapshots_fonds ON public.ventes_snapshots USING btree (fonds_id, vendu_le DESC);
CREATE INDEX oeuvres_auteur_idx ON public.oeuvres USING btree (auteur);
CREATE INDEX oeuvres_type_idx ON public.oeuvres USING btree (type);
CREATE INDEX offres_destinataire_idx ON public.offres USING btree (destinataire, statut);
CREATE INDEX offres_emetteur_idx ON public.offres USING btree (emetteur, statut);
CREATE UNIQUE INDEX recettes_commerce_forme_unique ON public.recettes_commerce USING btree (generique_id, label_forme) WHERE (label_forme IS NOT NULL);
