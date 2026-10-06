-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine militaire -- phase 60 : rls-policies
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

ALTER TABLE public.armureries_dotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.batailles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.batailles_engagements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.batailles_groupes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.batailles_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.camions_destinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.camions_embarquements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.camions_militaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.camions_ordres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.candidatures_militaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commandes_militaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compagnies_militaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contacts_militaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decorations_militaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engagements_militaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guerres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.militaire_armes_bonus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.militaire_detections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.militaire_terminal_requetes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mutineries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mutineries_membres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nominations_militaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.retraits_materiel_militaire ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services_militaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.soldes_militaires ENABLE ROW LEVEL SECURITY;

-- armureries_dotations
CREATE POLICY "armureries_dotations lecture" ON public.armureries_dotations FOR SELECT TO PUBLIC
  USING (true);

-- batailles
CREATE POLICY batailles_lecture ON public.batailles FOR SELECT TO authenticated
  USING (true);

-- batailles_engagements
CREATE POLICY batailles_engagements_lecture ON public.batailles_engagements FOR SELECT TO authenticated
  USING (true);

-- batailles_groupes
CREATE POLICY batailles_groupes_lecture ON public.batailles_groupes FOR SELECT TO authenticated
  USING (true);

-- commandes_militaires
CREATE POLICY commandes_militaires_ecriture_acteur ON public.commandes_militaires FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY commandes_militaires_lecture ON public.commandes_militaires FOR SELECT TO PUBLIC
  USING (true);
CREATE POLICY commandes_militaires_maj_acteur ON public.commandes_militaires FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- compagnies_militaires
CREATE POLICY compagnies_lecture_mon_pays ON public.compagnies_militaires FOR SELECT TO authenticated
  USING ((data ->> 'pays'::text) = militaire_mon_pays());

-- decorations_militaires
CREATE POLICY decorations_lecture_publique ON public.decorations_militaires FOR SELECT TO authenticated
  USING (true);

-- engagements_militaires
CREATE POLICY "Lecture publique engagements militaires" ON public.engagements_militaires FOR SELECT TO PUBLIC
  USING (true);
CREATE POLICY engagements_militaires_lecture ON public.engagements_militaires FOR SELECT TO authenticated
  USING (true);

-- guerres
CREATE POLICY guerres_lecture ON public.guerres FOR SELECT TO anon, authenticated
  USING (true);

-- mutineries
CREATE POLICY mutineries_lecture_mon_pays ON public.mutineries FOR SELECT TO authenticated
  USING (pays = militaire_mon_pays());

-- mutineries_membres
CREATE POLICY mutineries_membres_lecture_mon_pays ON public.mutineries_membres FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM mutineries m
  WHERE m.camp = mutineries_membres.camp AND m.pays = militaire_mon_pays())));

-- nominations_militaires
CREATE POLICY "nominations militaires lecture interessee" ON public.nominations_militaires FOR SELECT TO authenticated
  USING (destinataire = mon_personnage() OR par = mon_personnage());

-- retraits_materiel_militaire
CREATE POLICY retraits_materiel_militaire_lecture ON public.retraits_materiel_militaire FOR SELECT TO PUBLIC
  USING (true);

-- services_militaires
CREATE POLICY services_militaires_lecture ON public.services_militaires FOR SELECT TO authenticated
  USING (pays = militaire_mon_pays());

-- soldes_militaires
CREATE POLICY soldes_militaires_lecture ON public.soldes_militaires FOR SELECT TO authenticated
  USING (personnage = mon_personnage());
