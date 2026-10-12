-- Index autonomes
-- ============================================================================
-- BASELINE Human Gambit -- domaine divers et technique -- phase 35 : index
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- 18 index sont portes par une contrainte et NE SONT PAS recrees ici.
--   actes_nocturnes_mecanismes_pkey  (contrainte actes_nocturnes_mecanismes_pkey)
--   actes_nocturnes_pkey  (contrainte actes_nocturnes_pkey)
--   admin_actions_tribunal_pk  (contrainte admin_actions_tribunal_pk)
--   admin_journal_pk  (contrainte admin_journal_pk)
--   administrateurs_invitations_pk  (contrainte administrateurs_invitations_pk)
--   administrateurs_pk  (contrainte administrateurs_pk)
--   ambassades_ouvertes_pkey  (contrainte ambassades_ouvertes_pkey)
--   carrieres_acquises_pkey  (contrainte carrieres_acquises_pkey)
--   carrieres_pkey  (contrainte carrieres_pkey)
--   cron_journal_pkey  (contrainte cron_journal_pkey)
--   etats_urgence_pkey  (contrainte etats_urgence_pkey)
--   evenements_globaux_pkey  (contrainte evenements_globaux_pkey)
--   habilitations_carrieres_pkey  (contrainte habilitations_carrieres_pkey)
--   habilitations_pkey  (contrainte habilitations_pkey)
--   habilitations_postes_pkey  (contrainte habilitations_postes_pkey)
--   propositions_diplomatiques_pkey  (contrainte propositions_diplomatiques_pkey)
--   purges_residus_bancs_pkey  (contrainte purges_residus_bancs_pkey)
--   registre_ventes_armes_pkey  (contrainte registre_ventes_armes_pkey)

-- Index autonomes :
CREATE INDEX cron_journal_jour_idx ON public.cron_journal USING btree (jour DESC);
CREATE INDEX cron_journal_statut_idx ON public.cron_journal USING btree (statut) WHERE (statut <> 'ok'::text);
CREATE INDEX idx_evenements_country ON public.evenements_globaux USING btree (country);
CREATE INDEX idx_evenements_created ON public.evenements_globaux USING btree (created_at DESC);
CREATE INDEX idx_registre_ventes_armes_jour ON public.registre_ventes_armes USING btree (jour);
CREATE INDEX idx_registre_ventes_armes_pays ON public.registre_ventes_armes USING btree (pays);
