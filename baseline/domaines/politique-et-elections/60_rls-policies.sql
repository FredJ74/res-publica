-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine politique et elections -- phase 60 : rls-policies
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

ALTER TABLE public.candidatures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cycles_electoraux ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.demandes_manifestation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.elections_tracts_pnj ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fraudes_electorales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.greves_generales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.indices_villes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mandats_maires_archives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.militants_recrutes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rp_epoques ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rp_transitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votes_confiance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votes_confiance_bulletins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votes_electoraux ENABLE ROW LEVEL SECURITY;

-- candidatures
CREATE POLICY candidatures_depot_soi ON public.candidatures FOR INSERT TO authenticated
  WITH CHECK (nom = mon_personnage());
CREATE POLICY candidatures_lecture ON public.candidatures FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY candidatures_retrait_soi ON public.candidatures FOR DELETE TO authenticated
  USING (nom = mon_personnage());

-- cycles_electoraux
CREATE POLICY cycles_electoraux_ecriture_acteur ON public.cycles_electoraux FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY cycles_electoraux_lecture ON public.cycles_electoraux FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY cycles_electoraux_maj_acteur ON public.cycles_electoraux FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- demandes_manifestation
CREATE POLICY "Lecture publique demandes manifestation" ON public.demandes_manifestation FOR SELECT TO PUBLIC
  USING (true);
CREATE POLICY demandes_manifestation_ecriture_acteur ON public.demandes_manifestation FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY demandes_manifestation_maj_acteur ON public.demandes_manifestation FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- elections_tracts_pnj
CREATE POLICY elections_tracts_pnj_lecture ON public.elections_tracts_pnj FOR SELECT TO PUBLIC
  USING (true);

-- fraudes_electorales
CREATE POLICY fraudes_electorales_ecriture_acteur ON public.fraudes_electorales FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY fraudes_electorales_lecture_publique ON public.fraudes_electorales FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY fraudes_electorales_maj_acteur ON public.fraudes_electorales FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- greves_generales
CREATE POLICY greves_generales_ecriture_acteur ON public.greves_generales FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY greves_generales_lecture_publique ON public.greves_generales FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY greves_generales_maj_acteur ON public.greves_generales FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- indices_villes
CREATE POLICY indices_villes_ecriture_acteur ON public.indices_villes FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY indices_villes_lecture_publique ON public.indices_villes FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY indices_villes_maj_acteur ON public.indices_villes FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- mandats_maires_archives
CREATE POLICY mandats_maires_archives_lecture ON public.mandats_maires_archives FOR SELECT TO anon, authenticated
  USING (true);

-- militants_recrutes
CREATE POLICY "militants : les siens, et rien d autre" ON public.militants_recrutes FOR SELECT TO authenticated
  USING (recruteur = (( SELECT mon_personnage() AS mon_personnage)));
CREATE POLICY "militants recrutes en son propre nom" ON public.militants_recrutes FOR INSERT TO authenticated
  WITH CHECK (recruteur = (( SELECT mon_personnage() AS mon_personnage)));

-- votes_confiance
CREATE POLICY votes_confiance_ecriture_acteur ON public.votes_confiance FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY votes_confiance_lecture_publique ON public.votes_confiance FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY votes_confiance_maj_acteur ON public.votes_confiance FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- votes_confiance_bulletins
CREATE POLICY votes_confiance_bulletins_lecture_publique ON public.votes_confiance_bulletins FOR SELECT TO anon, authenticated
  USING (true);

-- votes_electoraux
CREATE POLICY votes_electoraux_lecture ON public.votes_electoraux FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY votes_electoraux_suppression_acteur ON public.votes_electoraux FOR DELETE TO authenticated
  USING (acteur_identifie());
CREATE POLICY votes_electoraux_vote_soi ON public.votes_electoraux FOR INSERT TO authenticated
  WITH CHECK (votant = mon_personnage());
