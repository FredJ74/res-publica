-- GRANT sur tables, colonnes et fonctions
-- ============================================================================
-- BASELINE Human Gambit -- domaine politique et elections -- phase 70 : droits
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- DROITS SUR LES FUNCTIONS
GRANT EXECUTE ON FUNCTION public.candidature_poste_tirage_appliquer(text,text,text,text,text[],text) TO postgres;
GRANT EXECUTE ON FUNCTION public.candidature_poste_tirage_appliquer(text,text,text,text,text[],text) TO service_role;
GRANT EXECUTE ON FUNCTION public.candidature_publier(text,text,numeric,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.candidature_publier(text,text,numeric,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.candidature_publier(text,text,numeric,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.candidatures_cloture() TO postgres;
GRANT EXECUTE ON FUNCTION public.candidatures_cloture() TO service_role;
GRANT EXECUTE ON FUNCTION public.cycle_electoral_aligne_dimanche(jsonb,timestamp with time zone) TO postgres;
GRANT EXECUTE ON FUNCTION public.cycle_electoral_aligne_dimanche(jsonb,timestamp with time zone) TO service_role;
GRANT EXECUTE ON FUNCTION public.cycles_electoraux_dimanche() TO postgres;
GRANT EXECUTE ON FUNCTION public.cycles_electoraux_dimanche() TO service_role;
GRANT EXECUTE ON FUNCTION public.election_voter(text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.election_voter(text,text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.election_voter(text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.elections_voix_pnj_enregistrer(text,text,text,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.elections_voix_pnj_enregistrer(text,text,text,text,text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.elections_voix_pnj_enregistrer(text,text,text,text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.indice_ville_ajuster_interne(text,text,text,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.indice_ville_ajuster_interne(text,text,text,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.militant_recruter(text,text,text,text,text,text,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.militant_recruter(text,text,text,text,text,text,integer,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.militant_recruter(text,text,text,text,text,text,integer,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.poste_accepter_nomination(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poste_accepter_nomination(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.poste_accepter_nomination(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.poste_attribuer_candidature(text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poste_attribuer_candidature(text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.poste_attribuer_candidature(text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.poste_attribuer_interne(text,text,text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.poste_attribuer_interne(text,text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.poste_autorite_de(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poste_autorite_de(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.poste_autorite_de(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.poste_est_atteste(text,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poste_est_atteste(text,jsonb,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.poste_est_atteste(text,jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.poste_nommer(text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poste_nommer(text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.poste_nommer(text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.poste_postuler(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poste_postuler(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.poste_postuler(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.poste_quitter() TO authenticated;
GRANT EXECUTE ON FUNCTION public.poste_quitter() TO postgres;
GRANT EXECUTE ON FUNCTION public.poste_quitter() TO service_role;
GRANT EXECUTE ON FUNCTION public.poste_revoquer(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poste_revoquer(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.poste_revoquer(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.postes_nommes_regles_empreinte_reelle() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.postes_nommes_regles_empreinte_reelle() TO authenticated;
GRANT EXECUTE ON FUNCTION public.postes_nommes_regles_empreinte_reelle() TO postgres;
GRANT EXECUTE ON FUNCTION public.postes_nommes_regles_empreinte_reelle() TO service_role;

-- DROITS SUR LES SEQUENCES
GRANT SELECT, USAGE ON SEQUENCE public.elections_tracts_pnj_id_seq TO anon;
GRANT SELECT, USAGE ON SEQUENCE public.elections_tracts_pnj_id_seq TO authenticated;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.elections_tracts_pnj_id_seq TO postgres;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.elections_tracts_pnj_id_seq TO service_role;

-- DROITS SUR LES TABLES
GRANT SELECT ON TABLE public.candidatures TO anon;
GRANT DELETE, INSERT, SELECT ON TABLE public.candidatures TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.candidatures TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.candidatures TO service_role;
GRANT SELECT ON TABLE public.cycles_electoraux TO anon;
GRANT INSERT, SELECT, UPDATE ON TABLE public.cycles_electoraux TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.cycles_electoraux TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.cycles_electoraux TO service_role;
GRANT SELECT ON TABLE public.demandes_manifestation TO anon;
GRANT INSERT, SELECT, UPDATE ON TABLE public.demandes_manifestation TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.demandes_manifestation TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.demandes_manifestation TO service_role;
GRANT SELECT ON TABLE public.elections_tracts_pnj TO anon;
GRANT SELECT ON TABLE public.elections_tracts_pnj TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.elections_tracts_pnj TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.elections_tracts_pnj TO service_role;
GRANT SELECT ON TABLE public.fraudes_electorales TO anon;
GRANT INSERT, SELECT, UPDATE ON TABLE public.fraudes_electorales TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.fraudes_electorales TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.fraudes_electorales TO service_role;
GRANT SELECT ON TABLE public.greves_generales TO anon;
GRANT INSERT, SELECT, UPDATE ON TABLE public.greves_generales TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.greves_generales TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.greves_generales TO service_role;
GRANT SELECT ON TABLE public.indices_villes TO anon;
GRANT INSERT, SELECT, UPDATE ON TABLE public.indices_villes TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.indices_villes TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.indices_villes TO service_role;
GRANT SELECT ON TABLE public.mandats_maires_archives TO anon;
GRANT SELECT ON TABLE public.mandats_maires_archives TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mandats_maires_archives TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mandats_maires_archives TO service_role;
GRANT SELECT ON TABLE public.militants_recrutes TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.militants_recrutes TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.militants_recrutes TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rp_epoques TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rp_epoques TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rp_transitions TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rp_transitions TO service_role;
GRANT SELECT ON TABLE public.votes_confiance TO anon;
GRANT INSERT, SELECT, UPDATE ON TABLE public.votes_confiance TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.votes_confiance TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.votes_confiance TO service_role;
GRANT SELECT ON TABLE public.votes_confiance_bulletins TO anon;
GRANT SELECT ON TABLE public.votes_confiance_bulletins TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.votes_confiance_bulletins TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.votes_confiance_bulletins TO service_role;
GRANT SELECT ON TABLE public.votes_electoraux TO anon;
GRANT DELETE, INSERT, SELECT ON TABLE public.votes_electoraux TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.votes_electoraux TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.votes_electoraux TO service_role;
