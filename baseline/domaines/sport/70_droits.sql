-- GRANT sur tables, colonnes et fonctions
-- ============================================================================
-- BASELINE Human Gambit -- domaine sport -- phase 70 : droits
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- DROITS SUR LES FUNCTIONS
GRANT EXECUTE ON FUNCTION public.championnat_date_sportive(timestamp with time zone) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.championnat_date_sportive(timestamp with time zone) TO anon;
GRANT EXECUTE ON FUNCTION public.championnat_date_sportive(timestamp with time zone) TO authenticated;
GRANT EXECUTE ON FUNCTION public.championnat_date_sportive(timestamp with time zone) TO postgres;
GRANT EXECUTE ON FUNCTION public.championnat_date_sportive(timestamp with time zone) TO service_role;
GRANT EXECUTE ON FUNCTION public.championnat_echeance(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.championnat_echeance(text) TO anon;
GRANT EXECUTE ON FUNCTION public.championnat_echeance(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.championnat_echeance(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.championnat_echeance(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.championnat_matchs(jsonb) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.championnat_matchs(jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.championnat_matchs(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.championnat_matchs(jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.championnat_matchs(jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.championnat_publier_journee(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.championnat_publier_journee(integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.championnat_publier_journee(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.championnat_publier_sacre() TO authenticated;
GRANT EXECUTE ON FUNCTION public.championnat_publier_sacre() TO postgres;
GRANT EXECUTE ON FUNCTION public.championnat_publier_sacre() TO service_role;
GRANT EXECUTE ON FUNCTION public.championnat_publier_tour(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.championnat_publier_tour(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.championnat_publier_tour(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.championnat_rang_etape(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.championnat_rang_etape(text) TO anon;
GRANT EXECUTE ON FUNCTION public.championnat_rang_etape(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.championnat_rang_etape(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.championnat_rang_etape(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.championnat_verrou_calendrier() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.championnat_verrou_calendrier() TO postgres;
GRANT EXECUTE ON FUNCTION public.championnat_verrou_calendrier() TO service_role;
GRANT EXECUTE ON FUNCTION public.club_capitaine(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_capitaine(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.club_capitaine(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.club_electeurs(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_electeurs(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.club_electeurs(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.club_president_cloturer(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_president_cloturer(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.club_president_cloturer(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.club_president_postuler(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_president_postuler(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.club_president_postuler(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.club_president_voter(text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_president_voter(text,boolean) TO postgres;
GRANT EXECUTE ON FUNCTION public.club_president_voter(text,boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.football_entrainement_consommer(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.football_entrainement_consommer(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.football_entrainement_consommer(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.football_entrainements_du_jour() TO authenticated;
GRANT EXECUTE ON FUNCTION public.football_entrainements_du_jour() TO postgres;
GRANT EXECUTE ON FUNCTION public.football_entrainements_du_jour() TO service_role;
GRANT EXECUTE ON FUNCTION public.football_noms_composition(jsonb) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.football_noms_composition(jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.football_noms_composition(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.football_noms_composition(jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.football_noms_composition(jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.football_pari_engager(text,text,integer,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.football_pari_engager(text,text,integer,text,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.football_pari_engager(text,text,integer,text,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.football_paris_resoudre(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.football_paris_resoudre(integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.football_paris_resoudre(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.football_primes_journee(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.football_primes_journee(integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.football_primes_journee(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.football_primes_match(integer,text,jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.football_primes_match(integer,text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.football_primes_tour(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.football_primes_tour(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.football_primes_tour(text) TO service_role;

-- DROITS SUR LES SEQUENCES
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.championnat_tentatives_id_seq TO postgres;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.championnat_tentatives_id_seq TO service_role;

-- DROITS SUR LES TABLES
GRANT SELECT ON TABLE public.championnat TO anon;
GRANT INSERT, SELECT, UPDATE ON TABLE public.championnat TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.championnat TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.championnat TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.championnat_tentatives TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.championnat_tentatives TO service_role;
GRANT SELECT ON TABLE public.clubs_football TO anon;
GRANT SELECT ON TABLE public.clubs_football TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.clubs_football TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.clubs_football TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.clubs_sportifs_regles TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.clubs_sportifs_regles TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.entrainements_football TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.entrainements_football TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.football_primes_versees TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.football_primes_versees TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.paris_sportifs TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.paris_sportifs TO service_role;
GRANT SELECT ON TABLE public.presidents_clubs TO anon;
GRANT SELECT ON TABLE public.presidents_clubs TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.presidents_clubs TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.presidents_clubs TO service_role;
GRANT SELECT ON TABLE public.transferts_clubs TO anon;
GRANT INSERT, SELECT, UPDATE ON TABLE public.transferts_clubs TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.transferts_clubs TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.transferts_clubs TO service_role;
