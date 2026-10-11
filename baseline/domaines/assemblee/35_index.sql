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

-- 22 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   assemblee_catalogue_illegal_pkey  (contrainte assemblee_catalogue_illegal_pkey)
--   assemblee_categories_interdiction_pkey  (contrainte assemblee_categories_interdiction_pkey)
--   assemblee_debats_pkey  (contrainte assemblee_debats_pkey)
--   assemblee_disciplines_pkey  (contrainte assemblee_disciplines_pkey)
--   assemblee_indemnites_pkey  (contrainte assemblee_indemnites_pkey)
--   assemblee_intentions_pkey  (contrainte assemblee_intentions_pkey)
--   assemblee_paroles_pkey  (contrainte assemblee_paroles_pkey)
--   assemblee_presidence_bulletins_pkey  (contrainte assemblee_presidence_bulletins_pkey)
--   assemblee_presidence_dues_pkey  (contrainte assemblee_presidence_dues_pkey)
--   assemblee_presidence_scrutins_pkey  (contrainte assemblee_presidence_scrutins_pkey)
--   assemblee_presidence_tirage_vu_pkey  (contrainte assemblee_presidence_tirage_vu_pkey)
--   assemblee_propositions_pkey  (contrainte assemblee_propositions_pkey)
--   assemblee_protestations_pkey  (contrainte assemblee_protestations_pkey)
--   assemblee_reports_pkey  (contrainte assemblee_reports_pkey)
--   assemblee_reports_suspension_pkey  (contrainte assemblee_reports_suspension_pkey)
--   assemblee_requetes_pkey  (contrainte assemblee_requetes_pkey)
--   assemblee_sanctions_paliers_pkey  (contrainte assemblee_sanctions_paliers_pkey)
--   assemblee_scrutins_pkey  (contrainte assemblee_scrutins_pkey)
--   assemblee_sieges_pkey  (contrainte assemblee_sieges_pkey)
--   assemblee_sieges_pnj_id_key  (contrainte assemblee_sieges_pnj_id_key)
--   assemblee_suspensions_pkey  (contrainte assemblee_suspensions_pkey)
--   assemblee_votes_pkey  (contrainte assemblee_votes_pkey)

-- Index autonomes :
CREATE INDEX assemblee_debats_par_pays ON public.assemblee_debats USING btree (pays, dit_le DESC);
CREATE UNIQUE INDEX assemblee_debats_une_requete ON public.assemblee_debats USING btree (requete) WHERE (requete IS NOT NULL);
CREATE INDEX assemblee_disciplines_par_cible ON public.assemblee_disciplines USING btree (pays, cible, fait_le DESC);
CREATE UNIQUE INDEX assemblee_disciplines_une_requete ON public.assemblee_disciplines USING btree (requete) WHERE (requete IS NOT NULL);
CREATE UNIQUE INDEX assemblee_presidence_un_seul_ouvert ON public.assemblee_presidence_scrutins USING btree (pays) WHERE (statut = 'ouvert'::text);
CREATE UNIQUE INDEX assemblee_presidence_une_requete ON public.assemblee_presidence_bulletins USING btree (requete) WHERE (requete IS NOT NULL);
CREATE UNIQUE INDEX assemblee_presidence_une_seule_due ON public.assemblee_presidence_dues USING btree (pays) WHERE (honore_le IS NULL);
CREATE INDEX assemblee_propositions_a_appliquer_idx ON public.assemblee_propositions USING btree (country, adoptee_ts) WHERE ((statut = 'adoptee'::text) AND (appliquee_ts IS NULL) AND (type = ANY (ARRAY['mecanique'::text, 'abrogation'::text])));
CREATE INDEX assemblee_reports_suspension_par_texte ON public.assemblee_reports_suspension USING btree (pays, proposition_id);
CREATE UNIQUE INDEX assemblee_reports_une_requete ON public.assemblee_reports USING btree (requete) WHERE (requete IS NOT NULL);
CREATE INDEX assemblee_sanctions_paliers_prop_idx ON public.assemblee_sanctions_paliers USING btree (proposition_id, palier);
CREATE UNIQUE INDEX assemblee_suspensions_une_reprise ON public.assemblee_suspensions USING btree (reprise_requete) WHERE (reprise_requete IS NOT NULL);
CREATE UNIQUE INDEX assemblee_suspensions_une_requete ON public.assemblee_suspensions USING btree (requete) WHERE (requete IS NOT NULL);
CREATE UNIQUE INDEX assemblee_un_rappel_une_sanction ON public.assemblee_disciplines USING btree (rappel_id) WHERE (rappel_id IS NOT NULL);
CREATE UNIQUE INDEX assemblee_un_renvoi_par_session_suspendue ON public.assemblee_reports_suspension USING btree (suspension_id, proposition_id, session_annulee);
CREATE UNIQUE INDEX assemblee_un_seul_boycott_ouvert ON public.assemblee_suspensions USING btree (pays) WHERE ((cause = 'boycott'::text) AND (close_le IS NULL));
CREATE UNIQUE INDEX assemblee_un_seul_orateur ON public.assemblee_paroles USING btree (pays) WHERE a_la_parole;
CREATE UNIQUE INDEX assemblee_une_seule_suspension_presidence ON public.assemblee_suspensions USING btree (pays) WHERE ((cause = 'presidence'::text) AND (close_le IS NULL));
CREATE INDEX idx_assemblee_indemnites_perso ON public.assemblee_indemnites USING btree (personnage, jour);
CREATE INDEX idx_assemblee_intentions_prop ON public.assemblee_intentions USING btree (proposition_id, session_num);
CREATE INDEX idx_assemblee_prop_cloture ON public.assemblee_propositions USING btree (statut, cloture_ts) WHERE (statut = 'session'::text);
CREATE INDEX idx_assemblee_prop_interdictions_actives ON public.assemblee_propositions USING btree (country, categorie) WHERE ((type = 'mecanique'::text) AND (statut = 'adoptee'::text));
CREATE INDEX idx_assemblee_prop_statut ON public.assemblee_propositions USING btree (country, statut);
CREATE INDEX idx_assemblee_requetes_perso ON public.assemblee_requetes USING btree (personnage, cree_ts);
CREATE INDEX idx_assemblee_scrutins_prop ON public.assemblee_scrutins USING btree (proposition_id);
CREATE INDEX idx_assemblee_sieges_pays_ville ON public.assemblee_sieges USING btree (country, city, rang);
CREATE INDEX idx_assemblee_votes_prop ON public.assemblee_votes USING btree (proposition_id, session_num);
