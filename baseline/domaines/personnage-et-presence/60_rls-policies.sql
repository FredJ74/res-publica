-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine personnage et presence -- phase 60 : rls-policies
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

ALTER TABLE public.contacts_organisations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contacts_organisations_passeurs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.demandes_mariage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.demandes_naturalisation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dons_en_attente ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dons_requetes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escort_evenements_commerciaux ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escorts_agences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escorts_catalogue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fiche_hausses_observees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fiche_inventaire_observe ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historique_deplacements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitations_diner ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mariages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.objets_abandonnes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.objets_recus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organisations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personnages_donnees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personnages_supprimes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quetes_actives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reconciliation_fantomes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.souvenirs_accueil ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.testaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournees ENABLE ROW LEVEL SECURITY;

-- demandes_mariage
CREATE POLICY allow_all_demandes_mariage ON public.demandes_mariage FOR ALL TO PUBLIC
  USING (true)
  WITH CHECK (true);

-- demandes_naturalisation
CREATE POLICY allow_all_demandes_naturalisation ON public.demandes_naturalisation FOR ALL TO PUBLIC
  USING (true)
  WITH CHECK (true);

-- dons_en_attente
CREATE POLICY "dons consommation destinataire" ON public.dons_en_attente FOR UPDATE TO authenticated
  USING (destinataire = mon_personnage())
  WITH CHECK (destinataire = mon_personnage());
CREATE POLICY "dons lecture destinataire" ON public.dons_en_attente FOR SELECT TO authenticated
  USING (destinataire = mon_personnage());

-- invitations_diner
CREATE POLICY "invitation creee par l inviteur" ON public.invitations_diner FOR INSERT TO authenticated
  WITH CHECK (inviteur = (( SELECT mon_personnage() AS mon_personnage)));
CREATE POLICY "invitation lecture par les deux parties" ON public.invitations_diner FOR SELECT TO authenticated
  USING (inviteur = (( SELECT mon_personnage() AS mon_personnage)) OR invite = (( SELECT mon_personnage() AS mon_personnage)));
CREATE POLICY "invitation repondue par l invite" ON public.invitations_diner FOR UPDATE TO authenticated
  USING (invite = (( SELECT mon_personnage() AS mon_personnage)))
  WITH CHECK (invite = (( SELECT mon_personnage() AS mon_personnage)));
CREATE POLICY "invitation supprimee par les deux parties" ON public.invitations_diner FOR DELETE TO authenticated
  USING (inviteur = (( SELECT mon_personnage() AS mon_personnage)) OR invite = (( SELECT mon_personnage() AS mon_personnage)));

-- mariages
CREATE POLICY allow_all_mariages ON public.mariages FOR ALL TO PUBLIC
  USING (true)
  WITH CHECK (true);

-- objets_abandonnes
CREATE POLICY allow_all_objets_abandonnes ON public.objets_abandonnes FOR ALL TO PUBLIC
  USING (true)
  WITH CHECK (true);

-- objets_recus
CREATE POLICY objets_recus_lire_le_sien ON public.objets_recus FOR SELECT TO authenticated
  USING (destinataire = mon_personnage());
CREATE POLICY objets_recus_reclamer_le_sien ON public.objets_recus FOR DELETE TO authenticated
  USING (destinataire = mon_personnage());

-- organisations
CREATE POLICY allow_all_organisations ON public.organisations FOR ALL TO PUBLIC
  USING (true)
  WITH CHECK (true);

-- personnages_donnees
CREATE POLICY personnages_creation_soi ON public.personnages_donnees FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());
CREATE POLICY personnages_lecture ON public.personnages_donnees FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY personnages_maj_soi ON public.personnages_donnees FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
CREATE POLICY personnages_suppression_soi ON public.personnages_donnees FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- presences
CREATE POLICY presences_creation_soi ON public.presences FOR INSERT TO authenticated
  WITH CHECK (name = mon_personnage());
CREATE POLICY presences_lecture_publique ON public.presences FOR SELECT TO PUBLIC
  USING (true);
CREATE POLICY presences_maj_soi ON public.presences FOR UPDATE TO authenticated
  USING (name = mon_personnage())
  WITH CHECK (name = mon_personnage());
CREATE POLICY presences_suppression_soi ON public.presences FOR DELETE TO authenticated
  USING (name = mon_personnage());

-- quetes_actives
CREATE POLICY allow_all_quetes_actives ON public.quetes_actives FOR ALL TO PUBLIC
  USING (true)
  WITH CHECK (true);

-- souvenirs_accueil
CREATE POLICY allow_all_souvenirs_accueil ON public.souvenirs_accueil FOR ALL TO PUBLIC
  USING (true)
  WITH CHECK (true);

-- testaments
CREATE POLICY "testament lu par son seul testateur" ON public.testaments FOR SELECT TO authenticated
  USING (testateur = (( SELECT mon_personnage() AS mon_personnage)));
CREATE POLICY "testament redige en son propre nom" ON public.testaments FOR INSERT TO authenticated
  WITH CHECK (testateur = (( SELECT mon_personnage() AS mon_personnage)));
CREATE POLICY "testament revoque ou remplace par son testateur" ON public.testaments FOR UPDATE TO authenticated
  USING (testateur = (( SELECT mon_personnage() AS mon_personnage)))
  WITH CHECK (testateur = (( SELECT mon_personnage() AS mon_personnage)));

-- tournees
CREATE POLICY "tournee creee par l offreur" ON public.tournees FOR INSERT TO authenticated
  WITH CHECK (offreur = (( SELECT mon_personnage() AS mon_personnage)));
CREATE POLICY "tournee lue par l offreur et ses invites" ON public.tournees FOR SELECT TO authenticated
  USING (offreur = (( SELECT mon_personnage() AS mon_personnage)) OR (EXISTS ( SELECT 1
   FROM invitations_diner i
  WHERE i.tournee_id = tournees.id AND i.invite = (( SELECT mon_personnage() AS mon_personnage)))));
CREATE POLICY "tournee pilotee par l offreur" ON public.tournees FOR UPDATE TO authenticated
  USING (offreur = (( SELECT mon_personnage() AS mon_personnage)))
  WITH CHECK (offreur = (( SELECT mon_personnage() AS mon_personnage)));
