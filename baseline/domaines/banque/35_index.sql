-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine banque -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 11 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   biens_saisis_helvetia_pkey  (contrainte biens_saisis_helvetia_pkey)
--   bnr_refinancements_helvetia_pkey  (contrainte bnr_refinancements_helvetia_pkey)
--   compromis_historique_pkey  (contrainte compromis_historique_pkey)
--   comptes_bancaires_pkey  (contrainte comptes_bancaires_pkey)
--   obligations_helvetia_pkey  (contrainte obligations_helvetia_pkey)
--   placements_bancaires_pkey  (contrainte placements_bancaires_pkey)
--   prets_bancaires_pkey  (contrainte prets_bancaires_pkey)
--   prets_ecritures_internes_pkey  (contrainte prets_ecritures_internes_pkey)
--   prets_nationaux_demandes_pkey  (contrainte prets_nationaux_demandes_pkey)
--   prets_pkey  (contrainte prets_pkey)
--   virements_automatiques_pkey  (contrainte virements_automatiques_pkey)

-- Index autonomes :
CREATE UNIQUE INDEX compromis_historique_un_resultat_par_bien_et_par_jour ON public.compromis_historique USING btree (country, building_id, resultat, ((timezone('Europe/Paris'::text, created_at))::date));
CREATE UNIQUE INDEX comptes_bancaires_perso_banque ON public.comptes_bancaires USING btree (personnage, banque);
CREATE INDEX comptes_bancaires_personnage ON public.comptes_bancaires USING btree (personnage);
CREATE INDEX idx_biens_saisis_helvetia_statut ON public.biens_saisis_helvetia USING btree (statut);
CREATE INDEX idx_bnr_refi_helvetia_country_statut ON public.bnr_refinancements_helvetia USING btree (country, statut);
CREATE INDEX idx_obligations_helvetia_country_statut_date ON public.obligations_helvetia USING btree (country, statut, created_at);
CREATE INDEX placements_bancaires_personnage ON public.placements_bancaires USING btree (personnage);
CREATE INDEX placements_bancaires_visibilite ON public.placements_bancaires USING btree (personnage, visible_fiscalement) WHERE (statut = 'actif'::text);
CREATE INDEX virements_automatiques_echeances ON public.virements_automatiques USING btree (prochain_le) WHERE actif;
