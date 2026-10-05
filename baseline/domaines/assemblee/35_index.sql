-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine assemblee -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 11 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   assemblee_catalogue_illegal_pkey  (contrainte assemblee_catalogue_illegal_pkey)
--   assemblee_categories_interdiction_pkey  (contrainte assemblee_categories_interdiction_pkey)
--   assemblee_indemnites_pkey  (contrainte assemblee_indemnites_pkey)
--   assemblee_intentions_pkey  (contrainte assemblee_intentions_pkey)
--   assemblee_propositions_pkey  (contrainte assemblee_propositions_pkey)
--   assemblee_requetes_pkey  (contrainte assemblee_requetes_pkey)
--   assemblee_sanctions_paliers_pkey  (contrainte assemblee_sanctions_paliers_pkey)
--   assemblee_scrutins_pkey  (contrainte assemblee_scrutins_pkey)
--   assemblee_sieges_pkey  (contrainte assemblee_sieges_pkey)
--   assemblee_sieges_pnj_id_key  (contrainte assemblee_sieges_pnj_id_key)
--   assemblee_votes_pkey  (contrainte assemblee_votes_pkey)

-- Index autonomes :
CREATE INDEX assemblee_propositions_a_appliquer_idx ON public.assemblee_propositions USING btree (country, adoptee_ts) WHERE ((statut = 'adoptee'::text) AND (appliquee_ts IS NULL) AND (type = ANY (ARRAY['mecanique'::text, 'abrogation'::text])));
CREATE INDEX assemblee_sanctions_paliers_prop_idx ON public.assemblee_sanctions_paliers USING btree (proposition_id, palier);
CREATE INDEX idx_assemblee_indemnites_perso ON public.assemblee_indemnites USING btree (personnage, jour);
CREATE INDEX idx_assemblee_intentions_prop ON public.assemblee_intentions USING btree (proposition_id, session_num);
CREATE INDEX idx_assemblee_prop_cloture ON public.assemblee_propositions USING btree (statut, cloture_ts) WHERE (statut = 'session'::text);
CREATE INDEX idx_assemblee_prop_interdictions_actives ON public.assemblee_propositions USING btree (country, categorie) WHERE ((type = 'mecanique'::text) AND (statut = 'adoptee'::text));
CREATE INDEX idx_assemblee_prop_statut ON public.assemblee_propositions USING btree (country, statut);
CREATE INDEX idx_assemblee_requetes_perso ON public.assemblee_requetes USING btree (personnage, cree_ts);
CREATE INDEX idx_assemblee_scrutins_prop ON public.assemblee_scrutins USING btree (proposition_id);
CREATE INDEX idx_assemblee_sieges_pays_ville ON public.assemblee_sieges USING btree (country, city, rang);
CREATE INDEX idx_assemblee_votes_prop ON public.assemblee_votes USING btree (proposition_id, session_num);
