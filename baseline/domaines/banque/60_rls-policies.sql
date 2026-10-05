-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine banque -- phase 60 : rls-policies
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

ALTER TABLE public.biens_saisis_helvetia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bnr_refinancements_helvetia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compromis_historique ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comptes_bancaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.obligations_helvetia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.placements_bancaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prets_bancaires ENABLE ROW LEVEL SECURITY;

-- comptes_bancaires
CREATE POLICY "comptes_bancaires lecture proprietaire" ON public.comptes_bancaires FOR SELECT TO PUBLIC
  USING (est_mon_personnage(personnage));

-- placements_bancaires
CREATE POLICY placements_bancaires_proprietaire_lecture ON public.placements_bancaires FOR SELECT TO anon, authenticated
  USING (personnage = mon_personnage());
