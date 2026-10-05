-- GRANT sur tables, colonnes et fonctions
-- ============================================================================
-- BASELINE Human Gambit -- domaine postes et institutions -- phase 70 : droits
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- DROITS SUR LES TABLES
GRANT MAINTAIN, SELECT ON TABLE public.nominations_en_attente TO anon;
GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER ON TABLE public.nominations_en_attente TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.nominations_en_attente TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.nominations_en_attente TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.nominations_poste_attente TO anon;
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.nominations_poste_attente TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.nominations_poste_attente TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.nominations_poste_attente TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.postes_attribues TO anon;
GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER ON TABLE public.postes_attribues TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.postes_attribues TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.postes_attribues TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.postes_electifs_regles TO anon;
GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER ON TABLE public.postes_electifs_regles TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.postes_electifs_regles TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.postes_electifs_regles TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.postes_nommes_regles TO anon;
GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER ON TABLE public.postes_nommes_regles TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.postes_nommes_regles TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.postes_nommes_regles TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.postes_nommes_regles_empreinte TO anon;
GRANT MAINTAIN, SELECT ON TABLE public.postes_nommes_regles_empreinte TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.postes_nommes_regles_empreinte TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.postes_nommes_regles_empreinte TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.titulaires_pnj TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.titulaires_pnj TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.titulaires_pnj TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.titulaires_pnj TO service_role;
