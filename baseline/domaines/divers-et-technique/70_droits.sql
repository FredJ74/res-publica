-- GRANT sur tables, colonnes et fonctions
-- ============================================================================
-- BASELINE Human Gambit -- domaine divers et technique -- phase 70 : droits
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- DROITS SUR LES SEQUENCES
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.evenements_globaux_id_seq TO anon;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.evenements_globaux_id_seq TO authenticated;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.evenements_globaux_id_seq TO postgres;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.evenements_globaux_id_seq TO service_role;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.registre_ventes_armes_id_seq TO anon;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.registre_ventes_armes_id_seq TO authenticated;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.registre_ventes_armes_id_seq TO postgres;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.registre_ventes_armes_id_seq TO service_role;

-- DROITS SUR LES TABLES
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.ambassades_ouvertes TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.ambassades_ouvertes TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.ambassades_ouvertes TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.cron_journal TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.cron_journal TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.etats_urgence TO anon;
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.etats_urgence TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.etats_urgence TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.etats_urgence TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.evenements_globaux TO anon;
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.evenements_globaux TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.evenements_globaux TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.evenements_globaux TO service_role;
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.propositions_diplomatiques TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.propositions_diplomatiques TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.propositions_diplomatiques TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.registre_ventes_armes TO anon;
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.registre_ventes_armes TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.registre_ventes_armes TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.registre_ventes_armes TO service_role;
