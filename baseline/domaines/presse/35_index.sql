-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine presse -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 19 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   calomnies_actes_pkey  (contrainte calomnies_actes_pkey)
--   chronique_nationale_pkey  (contrainte chronique_nationale_pkey)
--   corruptions_presse_affaire_ref_corrupteur_key  (contrainte corruptions_presse_affaire_ref_corrupteur_key)
--   corruptions_presse_pkey  (contrainte corruptions_presse_pkey)
--   fuites_journalistiques_pkey  (contrainte fuites_journalistiques_pkey)
--   fuites_journalistiques_trace_cle_key  (contrainte fuites_journalistiques_trace_cle_key)
--   groupes_presse_id_pays_unique  (contrainte groupes_presse_id_pays_unique)
--   groupes_presse_pkey  (contrainte groupes_presse_pkey)
--   interviews_jodie_pkey  (contrainte interviews_jodie_pkey)
--   journal_articles_en_attente_pkey  (contrainte journal_articles_en_attente_pkey)
--   journal_editions_journal_date_unique  (contrainte journal_editions_journal_date_unique)
--   journal_editions_pkey  (contrainte journal_editions_pkey)
--   journaux_pkey  (contrainte journaux_pkey)
--   journaux_redacteurs_pkey  (contrainte journaux_redacteurs_pkey)
--   petites_annonces_pkey  (contrainte petites_annonces_pkey)
--   presse_membres_pkey  (contrainte presse_membres_pkey)
--   scandales_presse_pkey  (contrainte scandales_presse_pkey)
--   scandales_tentatives_pkey  (contrainte scandales_tentatives_pkey)
--   tribune_articles_etouffes_pkey  (contrainte tribune_articles_etouffes_pkey)

-- Index autonomes :
CREATE INDEX calomnies_actes_cible ON public.calomnies_actes USING btree (cible, cree_le DESC);
CREATE UNIQUE INDEX calomnies_actes_verrou ON public.calomnies_actes USING btree (pnj_cle, cible, jour_paris) WHERE (resultat = 'reussite'::text);
CREATE INDEX corruptions_presse_affaire ON public.corruptions_presse USING btree (affaire_ref) WHERE reussite;
CREATE INDEX fuites_journalistiques_cible ON public.fuites_journalistiques USING btree (cible, cree_le DESC);
CREATE INDEX idx_journal_articles_en_attente_country ON public.journal_articles_en_attente USING btree (country) WHERE (integree_le IS NULL);
CREATE INDEX interviews_jodie_personnage_idx ON public.interviews_jodie USING btree (personnage, created_at DESC);
CREATE INDEX journal_editions_par_journal ON public.journal_editions USING btree (journal_id, date_edition);
CREATE INDEX journaux_par_groupe ON public.journaux USING btree (groupe_id);
CREATE INDEX journaux_redacteurs_par_personnage ON public.journaux_redacteurs USING btree (personnage);
CREATE UNIQUE INDEX journaux_slug_par_pays ON public.journaux USING btree (pays, slug);
CREATE UNIQUE INDEX journaux_un_garanti_par_pays ON public.journaux USING btree (pays) WHERE garanti_automatique;
CREATE INDEX petites_annonces_country_statut_idx ON public.petites_annonces USING btree (country, statut, expire_at);
CREATE INDEX presse_membres_par_personnage ON public.presse_membres USING btree (personnage);
CREATE UNIQUE INDEX presse_membres_un_seul_directeur ON public.presse_membres USING btree (groupe_id) WHERE (grade = 'directeur'::text);
CREATE INDEX scandales_presse_auteur ON public.scandales_presse USING btree (auteur, cree_le DESC);
CREATE INDEX scandales_presse_cible ON public.scandales_presse USING btree (cible, cree_le DESC);
