-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261025201502.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025201502.
-- ============================================================================
-- LES TROIS REFERENTES EMPLOI DU BUREAU NATIONAL DE L'EMPLOI (decision de Fred, 25/10/2026)
-- ============================================================================
-- Une secretaire differente dans chaque agence, referente emploi : Nathalie Boulot (Luthecia),
-- Edwige Leroux (Port-Sainte-Marie), Petra Vaillepas (Montrouge). Leurs fiches vivent dans
-- api/_pnj-referents.js ; cette migration les DECLARE dans pnj_referents, la liste fermee qui
-- autorise la memoire pedagogique (sans quoi elles recommenceraient a zero a chaque
-- conversation, comme les secretaires ministeriels avant le 11 octobre). Un domaine unique
-- chacune, comme les trois clubs de football. Idempotente. Aucun acte de joueur.
-- ============================================================================
INSERT INTO public.pnj_referents (referent_id, pays, domaine) VALUES
  ('nathalie_boulot', 'republic', 'emploi — Bureau National de l''Emploi de Luthecia'),
  ('edwige_leroux',   'republic', 'emploi — Bureau National de l''Emploi de Port-Sainte-Marie'),
  ('petra_vaillepas', 'republic', 'emploi — Bureau National de l''Emploi de Montrouge')
ON CONFLICT DO NOTHING;
