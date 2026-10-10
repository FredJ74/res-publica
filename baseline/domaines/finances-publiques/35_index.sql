-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine finances publiques -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 29 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   budgets_clubs_pkey  (contrainte budgets_clubs_pkey)
--   budgets_municipaux_pkey  (contrainte budgets_municipaux_pkey)
--   budgets_nationaux_pkey  (contrainte budgets_nationaux_pkey)
--   caisses_autorites_pkey  (contrainte caisses_autorites_pkey)
--   caisses_batiments_pkey  (contrainte caisses_batiments_pkey)
--   caisses_mouvements_clients_pkey  (contrainte caisses_mouvements_clients_pkey)
--   contributions_piete_pkey  (contrainte contributions_piete_pkey)
--   directions_etablissements_pkey  (contrainte directions_etablissements_pkey)
--   dotations_amorcage_caisses_pkey  (contrainte dotations_amorcage_caisses_pkey)
--   fiscalite_journal_pkey  (contrainte fiscalite_journal_pkey)
--   fonds_credits_sources_pkey  (contrainte fonds_credits_sources_pkey)
--   fonds_credits_uniques_pkey  (contrainte fonds_credits_uniques_pkey)
--   fonds_credits_uniques_ref  (contrainte fonds_credits_uniques_ref)
--   fonds_debits_pkey  (contrainte fonds_debits_pkey)
--   pa_bonus_differes_empreinte_pkey  (contrainte pa_bonus_differes_empreinte_pkey)
--   pa_bonus_differes_pkey  (contrainte pa_bonus_differes_pkey)
--   pa_bonus_hotel_pkey  (contrainte pa_bonus_hotel_pkey)
--   pa_credits_sources_pkey  (contrainte pa_credits_sources_pkey)
--   pa_credits_uniques_pkey  (contrainte pa_credits_uniques_pkey)
--   recettes_municipales_pkey  (contrainte recettes_municipales_pkey)
--   repartitions_budgetaires_pkey  (contrainte repartitions_budgetaires_pkey)
--   repartitions_versements_pkey  (contrainte repartitions_versements_pkey)
--   salaires_caisses_pkey  (contrainte salaires_caisses_pkey)
--   salaires_civils_declares_pkey  (contrainte salaires_civils_declares_pkey)
--   salaires_civils_verses_pkey  (contrainte salaires_civils_verses_pkey)
--   salaires_religieux_declares_pkey  (contrainte salaires_religieux_declares_pkey)
--   salaires_religieux_verses_pkey  (contrainte salaires_religieux_verses_pkey)
--   subventions_familles_pkey  (contrainte subventions_familles_pkey)
--   subventions_municipales_pkey  (contrainte subventions_municipales_pkey)

-- Index autonomes :
CREATE UNIQUE INDEX budget_national_champs_regles_cle ON public.budget_national_champs_regles USING btree (champ, COALESCE(sous_champ, ''::text));
CREATE INDEX caisses_mouvements_clients_idx ON public.caisses_mouvements_clients USING btree (caisse, vu_le DESC);
CREATE UNIQUE INDEX fiscalite_journal_idempotence ON public.fiscalite_journal USING btree (personnage, type, jour);
CREATE INDEX fonds_debits_acteur_idx ON public.fonds_debits USING btree (acteur, debite_le DESC);
CREATE INDEX idx_contributions_piete_auteur ON public.contributions_piete USING btree (pays, auteur, created_at);
CREATE INDEX subventions_enveloppe_en_attente ON public.subventions_municipales USING btree (pays, ville) WHERE (statut = 'proposee'::text);
CREATE UNIQUE INDEX subventions_une_proposition_identique_en_attente ON public.subventions_municipales USING btree (pays, ville, famille, beneficiaire, montant, jour) WHERE (statut = 'proposee'::text);
