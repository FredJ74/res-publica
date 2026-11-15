-- KRASNOV : KOUZMA ET PRASKOVIA, REFERENTS ET PNJ SOCIAUX (decision de Fred du 15/11/2026,
-- GAME-DESIGN-KRASNOV-KOUZMA-PRASKOVIA.md). Kouzma Lapchine : referent religion ET PNJ social.
-- Praskovia Pakhomova : referente kolkhoze ET PNJ social. Deux memoires distinctes, deux tables existantes :
--   * pnj_referents (liste fermee qui autorise la memoire pedagogique) ;
--   * pnj_social_jalons_regles (un PNJ sans regle de jalon n'est pas social). Comme pour Jodie, la regle est
--     inatteignable : relation, rencontres et conversations comptees, sans interpellation automatique (leur
--     histoire ne doit pas etre devoilee d'office).
-- Aucune donnee de joueur touchee. Idempotente.
BEGIN;
INSERT INTO public.pnj_referents (referent_id, domaine, pays)
SELECT x.id, x.domaine, 'soviet' FROM (VALUES
  ('kouzma_lapchine', 'religion — Eglise de la Sainte-Moisson-Commune (Tractorisme), dons a l''Eglise — Krasnov'),
  ('praskovia_pakhomova', 'kolkhoze — Kolkhoze S. M. Kirov de Krasnov, travaux et caisse commune')) AS x(id, domaine)
 WHERE NOT EXISTS (SELECT 1 FROM public.pnj_referents r WHERE r.referent_id = x.id);
INSERT INTO public.pnj_social_jalons_regles (pnj_id, jalon, min_rencontres, max_conversations, rang)
SELECT x.id, x.jalon, 2147483647, NULL, 999 FROM (VALUES
  ('kouzma_lapchine', 'kouzma_sans_interpellation_automatique'),
  ('praskovia_pakhomova', 'praskovia_sans_interpellation_automatique')) AS x(id, jalon)
 WHERE NOT EXISTS (SELECT 1 FROM public.pnj_social_jalons_regles g WHERE g.pnj_id = x.id AND g.jalon = x.jalon);
DO $$ BEGIN
  IF (SELECT count(*) FROM public.pnj_referents WHERE referent_id IN ('kouzma_lapchine', 'praskovia_pakhomova')) <> 2
     OR (SELECT count(DISTINCT pnj_id) FROM public.pnj_social_jalons_regles WHERE pnj_id IN ('kouzma_lapchine', 'praskovia_pakhomova')) <> 2 THEN
    RAISE EXCEPTION 'krasnov_kouzma_praskovia_roles : controle structurel en echec';
  END IF;
END $$;
COMMIT;
