-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine economie -- phase 60 : rls-policies
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

ALTER TABLE public.apports_matieres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caisses_fret ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogue_correspondance_legacy ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogue_familles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogue_generique_type ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogue_generiques ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogue_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogue_variantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chaines_production_usine ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chantiers_besoins_jour ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chantiers_paliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commerces_dotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commerces_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.confiscations_douanieres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contenu_caisses_fret ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.directeurs_usine ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entrepot_journal ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entrepot_transits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entrepots_par_ville ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entrepots_reversements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entreprises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entreprises_constantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entreprises_prix_rachat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.imprimeries_declarees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investissements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oeuvres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ordres_couts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ordres_couts_ecarts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ordres_couts_empreinte ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ordres_couts_inconnus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productions_references ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produits_manufactures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recettes_commerce ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recettes_production ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ressources_economie ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ressources_economie_empreinte ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.structures_medicales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usines_rachat_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ventes_snapshots ENABLE ROW LEVEL SECURITY;

-- caisses_fret
CREATE POLICY caisses_fret_ecriture_acteur ON public.caisses_fret FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY caisses_fret_lecture_publique ON public.caisses_fret FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY caisses_fret_maj_acteur ON public.caisses_fret FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- catalogue_correspondance_legacy
CREATE POLICY "catalogue_correspondance_legacy lecture" ON public.catalogue_correspondance_legacy FOR SELECT TO anon, authenticated
  USING (true);

-- catalogue_familles
CREATE POLICY "catalogue_familles lecture" ON public.catalogue_familles FOR SELECT TO anon, authenticated
  USING (true);

-- catalogue_generique_type
CREATE POLICY "catalogue_generique_type lecture" ON public.catalogue_generique_type FOR SELECT TO anon, authenticated
  USING (true);

-- catalogue_generiques
CREATE POLICY "catalogue_generiques lecture" ON public.catalogue_generiques FOR SELECT TO anon, authenticated
  USING (true);

-- catalogue_types
CREATE POLICY "catalogue_types lecture" ON public.catalogue_types FOR SELECT TO anon, authenticated
  USING (true);

-- catalogue_variantes
CREATE POLICY "catalogue_variantes lecture" ON public.catalogue_variantes FOR SELECT TO anon, authenticated
  USING (true);

-- chaines_production_usine
CREATE POLICY chaines_production_lecture ON public.chaines_production_usine FOR SELECT TO anon, authenticated
  USING (true);

-- chantiers_besoins_jour
CREATE POLICY "chantiers_besoins_jour lecture" ON public.chantiers_besoins_jour FOR SELECT TO PUBLIC
  USING (true);

-- chantiers_paliers
CREATE POLICY "chantiers_paliers lecture" ON public.chantiers_paliers FOR SELECT TO PUBLIC
  USING (true);

-- commerces_dotations
CREATE POLICY "commerces_dotations lecture" ON public.commerces_dotations FOR SELECT TO PUBLIC
  USING (true);

-- commerces_types
CREATE POLICY "commerces_types lecture" ON public.commerces_types FOR SELECT TO PUBLIC
  USING (true);

-- contenu_caisses_fret
CREATE POLICY contenu_caisses_fret_ecriture_acteur ON public.contenu_caisses_fret FOR INSERT TO authenticated
  WITH CHECK (acteur_identifie());
CREATE POLICY contenu_caisses_fret_lecture_publique ON public.contenu_caisses_fret FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY contenu_caisses_fret_maj_acteur ON public.contenu_caisses_fret FOR UPDATE TO authenticated
  USING (acteur_identifie())
  WITH CHECK (acteur_identifie());

-- directeurs_usine
CREATE POLICY directeurs_usine_lecture ON public.directeurs_usine FOR SELECT TO anon, authenticated
  USING (true);

-- entrepot_journal
CREATE POLICY journal_lecture ON public.entrepot_journal FOR SELECT TO PUBLIC
  USING (true);

-- entrepot_transits
CREATE POLICY transits_lecture ON public.entrepot_transits FOR SELECT TO PUBLIC
  USING (true);

-- entrepots_par_ville
CREATE POLICY entrepots_par_ville_lecture ON public.entrepots_par_ville FOR SELECT TO anon, authenticated
  USING (true);

-- entreprises
CREATE POLICY "entreprises lecture publique" ON public.entreprises FOR SELECT TO PUBLIC
  USING (true);

-- entreprises_constantes
CREATE POLICY "entreprises_constantes lecture" ON public.entreprises_constantes FOR SELECT TO PUBLIC
  USING (true);

-- entreprises_prix_rachat
CREATE POLICY "prix_rachat lecture" ON public.entreprises_prix_rachat FOR SELECT TO PUBLIC
  USING (true);

-- imprimeries_declarees
CREATE POLICY "imprimeries lecture" ON public.imprimeries_declarees FOR SELECT TO PUBLIC
  USING (true);

-- investissements
CREATE POLICY investissements_lecture ON public.investissements FOR SELECT TO anon, authenticated
  USING (true);

-- oeuvres
CREATE POLICY oeuvres_select ON public.oeuvres FOR SELECT TO PUBLIC
  USING (true);

-- offres
CREATE POLICY offres_select ON public.offres FOR SELECT TO PUBLIC
  USING (true);

-- produits_manufactures
CREATE POLICY produits_manufactures_lecture ON public.produits_manufactures FOR SELECT TO anon, authenticated
  USING (true);

-- recettes_commerce
CREATE POLICY "recettes_commerce lecture" ON public.recettes_commerce FOR SELECT TO PUBLIC
  USING (true);

-- recettes_production
CREATE POLICY "recettes_production lecture" ON public.recettes_production FOR SELECT TO PUBLIC
  USING (true);

-- ressources_economie
CREATE POLICY ressources_economie_lecture ON public.ressources_economie FOR SELECT TO anon, authenticated
  USING (true);

-- structures_medicales
CREATE POLICY structures_medicales_lecture ON public.structures_medicales FOR SELECT TO anon, authenticated
  USING (true);

-- usines_rachat_config
CREATE POLICY usines_rachat_config_lecture ON public.usines_rachat_config FOR SELECT TO anon, authenticated
  USING (true);
