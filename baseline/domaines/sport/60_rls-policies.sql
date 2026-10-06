-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine sport -- phase 60 : rls-policies
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- Activation de la RLS. Une table dont la RLS est active SANS policy est
-- fermee a tout role soumis a la RLS : c'est un etat VOULU, pas un oubli.

ALTER TABLE public.championnat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.championnat_tentatives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clubs_football ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clubs_sportifs_regles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entrainements_football ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.football_primes_versees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.paris_sportifs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presidents_clubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transferts_clubs ENABLE ROW LEVEL SECURITY;

-- championnat
CREATE POLICY championnat_insert_hors_ligne_historique ON public.championnat FOR INSERT TO anon, authenticated
  WITH CHECK (id <> 1);
CREATE POLICY championnat_select_public ON public.championnat FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY championnat_update_hors_ligne_historique ON public.championnat FOR UPDATE TO anon, authenticated
  USING (id <> 1)
  WITH CHECK (id <> 1);

-- clubs_football
CREATE POLICY clubs_football_lecture ON public.clubs_football FOR SELECT TO anon, authenticated
  USING (true);

-- presidents_clubs
CREATE POLICY presidents_clubs_lecture ON public.presidents_clubs FOR SELECT TO anon, authenticated
  USING (true);

-- transferts_clubs
CREATE POLICY "Lecture publique transferts clubs" ON public.transferts_clubs FOR SELECT TO PUBLIC
  USING (true);
CREATE POLICY transferts_clubs_ecriture_acteur ON public.transferts_clubs FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY transferts_clubs_maj_acteur ON public.transferts_clubs FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());
