-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine postes et institutions -- phase 60 : rls-policies
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

ALTER TABLE public.nominations_en_attente ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nominations_poste_attente ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.postes_attribues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.postes_electifs_regles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.postes_nommes_regles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.postes_nommes_regles_empreinte ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.titulaires_pnj ENABLE ROW LEVEL SECURITY;

-- nominations_en_attente
CREATE POLICY nominations_attente_lecture ON public.nominations_en_attente FOR SELECT TO anon, authenticated
  USING (true);

-- nominations_poste_attente
CREATE POLICY nominations_poste_attente_lecture ON public.nominations_poste_attente FOR SELECT TO anon, authenticated
  USING (true);

-- postes_attribues
CREATE POLICY postes_attribues_lecture ON public.postes_attribues FOR SELECT TO anon, authenticated
  USING (true);

-- postes_electifs_regles
CREATE POLICY postes_electifs_regles_lecture ON public.postes_electifs_regles FOR SELECT TO anon, authenticated
  USING (true);

-- postes_nommes_regles
CREATE POLICY postes_regles_lecture ON public.postes_nommes_regles FOR SELECT TO anon, authenticated
  USING (true);

-- postes_nommes_regles_empreinte
CREATE POLICY postes_nommes_regles_empreinte_lecture_publique ON public.postes_nommes_regles_empreinte FOR SELECT TO anon, authenticated
  USING (true);

-- titulaires_pnj
CREATE POLICY titulaires_pnj_ecriture_non_politique ON public.titulaires_pnj FOR INSERT TO authenticated
  WITH CHECK (NOT (EXISTS ( SELECT 1
   FROM postes_nommes_regles r
  WHERE r.poste_id = titulaires_pnj.poste_id)));
CREATE POLICY titulaires_pnj_lecture ON public.titulaires_pnj FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY titulaires_pnj_maj_non_politique ON public.titulaires_pnj FOR UPDATE TO authenticated
  USING (NOT (EXISTS ( SELECT 1
   FROM postes_nommes_regles r
  WHERE r.poste_id = titulaires_pnj.poste_id)))
  WITH CHECK (NOT (EXISTS ( SELECT 1
   FROM postes_nommes_regles r
  WHERE r.poste_id = titulaires_pnj.poste_id)));
CREATE POLICY titulaires_pnj_suppression_non_politique ON public.titulaires_pnj FOR DELETE TO authenticated
  USING (NOT (EXISTS ( SELECT 1
   FROM postes_nommes_regles r
  WHERE r.poste_id = titulaires_pnj.poste_id)));
