-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine presse -- phase 60 : rls-policies
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

ALTER TABLE public.calomnies_actes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chronique_nationale ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.corruptions_presse ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuites_journalistiques ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groupes_presse ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interviews_jodie ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_articles_en_attente ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_editions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journaux ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journaux_redacteurs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presse_membres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scandales_presse ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scandales_tentatives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tribune_articles_etouffes ENABLE ROW LEVEL SECURITY;

-- calomnies_actes
CREATE POLICY calomnies_actes_lecture ON public.calomnies_actes FOR SELECT TO PUBLIC
  USING (true);

-- chronique_nationale
CREATE POLICY chronique_nationale_ecriture_publique ON public.chronique_nationale FOR INSERT TO PUBLIC
  WITH CHECK (true);
CREATE POLICY chronique_nationale_lecture_publique ON public.chronique_nationale FOR SELECT TO PUBLIC
  USING (true);

-- corruptions_presse
CREATE POLICY corruptions_presse_lecture ON public.corruptions_presse FOR SELECT TO PUBLIC
  USING (true);

-- fuites_journalistiques
CREATE POLICY fuites_journalistiques_lecture ON public.fuites_journalistiques FOR SELECT TO PUBLIC
  USING (true);

-- groupes_presse
CREATE POLICY groupes_presse_lecture ON public.groupes_presse FOR SELECT TO anon, authenticated
  USING (true);

-- journal_editions
CREATE POLICY journal_editions_lecture_publique ON public.journal_editions FOR SELECT TO PUBLIC
  USING (true);

-- journaux
CREATE POLICY journaux_lecture ON public.journaux FOR SELECT TO anon, authenticated
  USING (true);

-- journaux_redacteurs
CREATE POLICY journaux_redacteurs_lecture ON public.journaux_redacteurs FOR SELECT TO anon, authenticated
  USING (true);

-- presse_membres
CREATE POLICY presse_membres_lecture ON public.presse_membres FOR SELECT TO anon, authenticated
  USING (true);

-- scandales_presse
CREATE POLICY scandales_presse_lecture ON public.scandales_presse FOR SELECT TO PUBLIC
  USING (true);

-- scandales_tentatives
CREATE POLICY scandales_tentatives_lecture ON public.scandales_tentatives FOR SELECT TO PUBLIC
  USING (true);

-- tribune_articles_etouffes
CREATE POLICY tribune_articles_etouffes_ecriture_publique ON public.tribune_articles_etouffes FOR INSERT TO PUBLIC
  WITH CHECK (true);
CREATE POLICY tribune_articles_etouffes_lecture_publique ON public.tribune_articles_etouffes FOR SELECT TO PUBLIC
  USING (true);
