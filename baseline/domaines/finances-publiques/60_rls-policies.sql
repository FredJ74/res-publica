-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine finances publiques -- phase 60 : rls-policies
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

ALTER TABLE public.budget_national_champs_regles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets_clubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets_municipaux ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets_nationaux ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caisses_autorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caisses_batiments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caisses_mouvements_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contributions_piete ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.directions_etablissements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dotations_amorcage_caisses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fiscalite_journal ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fonds_credits_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fonds_credits_uniques ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fonds_debits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pa_bonus_differes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pa_bonus_differes_empreinte ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pa_bonus_hotel ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pa_credits_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pa_credits_uniques ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salaires_caisses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salaires_civils_declares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salaires_civils_verses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salaires_religieux_declares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salaires_religieux_verses ENABLE ROW LEVEL SECURITY;

-- budgets_clubs
CREATE POLICY "Lecture publique du budget club" ON public.budgets_clubs FOR SELECT TO PUBLIC
  USING (true);
CREATE POLICY budgets_clubs_ecriture_acteur ON public.budgets_clubs FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY budgets_clubs_maj_acteur ON public.budgets_clubs FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- budgets_municipaux
CREATE POLICY "Lecture publique du budget municipal" ON public.budgets_municipaux FOR SELECT TO PUBLIC
  USING (true);
CREATE POLICY budgets_municipaux_ecriture_acteur ON public.budgets_municipaux FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY budgets_municipaux_maj_acteur ON public.budgets_municipaux FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- budgets_nationaux
CREATE POLICY "Lecture publique budgets nationaux" ON public.budgets_nationaux FOR SELECT TO PUBLIC
  USING (true);
CREATE POLICY budgets_nationaux_ecriture_acteur ON public.budgets_nationaux FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY budgets_nationaux_maj_acteur ON public.budgets_nationaux FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- caisses_batiments
CREATE POLICY "caisses_batiments lecture publique hors commissariat" ON public.caisses_batiments FOR SELECT TO anon, authenticated
  USING (id !~~ '%commissariat%'::text);

-- contributions_piete
CREATE POLICY contributions_piete_ecriture_acteur ON public.contributions_piete FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY contributions_piete_lecture_publique ON public.contributions_piete FOR SELECT TO anon, authenticated
  USING (true);

-- pa_bonus_differes
CREATE POLICY pa_bonus_differes_lecture ON public.pa_bonus_differes FOR SELECT TO anon, authenticated
  USING (true);

-- pa_bonus_differes_empreinte
CREATE POLICY pa_bonus_differes_empreinte_lecture_publique ON public.pa_bonus_differes_empreinte FOR SELECT TO anon, authenticated
  USING (true);

-- pa_bonus_hotel
CREATE POLICY pa_bonus_hotel_lecture ON public.pa_bonus_hotel FOR SELECT TO anon, authenticated
  USING (true);

-- pa_credits_sources
CREATE POLICY pa_credits_sources_lecture_publique ON public.pa_credits_sources FOR SELECT TO anon, authenticated
  USING (true);
