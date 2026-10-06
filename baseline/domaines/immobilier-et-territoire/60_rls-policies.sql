-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine immobilier et territoire -- phase 60 : rls-policies
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

ALTER TABLE public.batiments_etat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.batiments_fermes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dossiers_urbanisme ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.locations_actives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.locations_archives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logements_attributions_historique ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logements_demandes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations_salle_reception ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.terrains_etat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.terrains_historique_ventes ENABLE ROW LEVEL SECURITY;

-- batiments_etat
CREATE POLICY "batiments_etat lecture publique" ON public.batiments_etat FOR SELECT TO PUBLIC
  USING (true);

-- batiments_fermes
CREATE POLICY "fermeture inscrite en son propre nom" ON public.batiments_fermes FOR INSERT TO authenticated
  WITH CHECK (auteur = (( SELECT mon_personnage() AS mon_personnage)));
CREATE POLICY "fermetures visibles de tous les joueurs" ON public.batiments_fermes FOR SELECT TO authenticated
  USING (true);

-- dossiers_urbanisme
CREATE POLICY dossiers_urbanisme_ecriture_acteur ON public.dossiers_urbanisme FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY dossiers_urbanisme_lecture ON public.dossiers_urbanisme FOR SELECT TO PUBLIC
  USING (true);

-- locations_actives
CREATE POLICY locations_ecriture ON public.locations_actives FOR INSERT TO authenticated
  WITH CHECK (bail_autorite_de(data));
CREATE POLICY locations_lecture ON public.locations_actives FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY locations_maj ON public.locations_actives FOR UPDATE TO authenticated
  USING (bail_autorite_de(data))
  WITH CHECK (bail_autorite_de(data));
CREATE POLICY locations_resiliation ON public.locations_actives FOR DELETE TO authenticated
  USING (bail_autorite_de(data));

-- locations_archives
CREATE POLICY locations_archives_select ON public.locations_archives FOR SELECT TO PUBLIC
  USING (true);

-- logements_attributions_historique
CREATE POLICY logements_attributions_historique_ecriture_acteur ON public.logements_attributions_historique FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY logements_attributions_historique_lecture_publique ON public.logements_attributions_historique FOR SELECT TO anon, authenticated
  USING (true);

-- logements_demandes
CREATE POLICY logements_demandes_ecriture_acteur ON public.logements_demandes FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY logements_demandes_lecture_publique ON public.logements_demandes FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY logements_demandes_maj_acteur ON public.logements_demandes FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- reservations_salle_reception
CREATE POLICY "reservations visibles des joueurs" ON public.reservations_salle_reception FOR SELECT TO authenticated
  USING (true);
CREATE POLICY "salle reservee par un ambassadeur accredite" ON public.reservations_salle_reception FOR INSERT TO authenticated
  WITH CHECK ((data ->> 'reservePar'::text) = (( SELECT mon_personnage() AS mon_personnage)) AND (EXISTS ( SELECT 1
   FROM ambassades_ouvertes a
  WHERE a.pays_hote = reservations_salle_reception.pays_hote AND a.empire = (a.data ->> 'empire'::text) AND (a.data ->> 'ambassadeur'::text) = (( SELECT mon_personnage() AS mon_personnage)))));

-- terrains_etat
CREATE POLICY terrains_etat_ecriture_acteur ON public.terrains_etat FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY terrains_etat_lecture_publique ON public.terrains_etat FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY terrains_etat_maj_acteur ON public.terrains_etat FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- terrains_historique_ventes
CREATE POLICY terrains_historique_ventes_ecriture_acteur ON public.terrains_historique_ventes FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY terrains_historique_ventes_lecture_publique ON public.terrains_historique_ventes FOR SELECT TO anon, authenticated
  USING (true);
