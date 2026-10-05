-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine assemblee -- phase 60 : rls-policies
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

ALTER TABLE public.assemblee_catalogue_illegal ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_categories_interdiction ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_indemnites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_intentions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_propositions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_requetes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_sanctions_paliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_scrutins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_sieges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_votes ENABLE ROW LEVEL SECURITY;

-- assemblee_categories_interdiction
CREATE POLICY assemblee_categories_lecture ON public.assemblee_categories_interdiction FOR SELECT TO PUBLIC
  USING (true);

-- assemblee_intentions
CREATE POLICY assemblee_intentions_lecture ON public.assemblee_intentions FOR SELECT TO PUBLIC
  USING (true);

-- assemblee_propositions
CREATE POLICY assemblee_propositions_lecture ON public.assemblee_propositions FOR SELECT TO PUBLIC
  USING (true);

-- assemblee_scrutins
CREATE POLICY assemblee_scrutins_lecture ON public.assemblee_scrutins FOR SELECT TO PUBLIC
  USING (true);

-- assemblee_sieges
CREATE POLICY assemblee_sieges_lecture ON public.assemblee_sieges FOR SELECT TO PUBLIC
  USING (true);

-- assemblee_votes
CREATE POLICY assemblee_votes_lecture ON public.assemblee_votes FOR SELECT TO PUBLIC
  USING (true);
