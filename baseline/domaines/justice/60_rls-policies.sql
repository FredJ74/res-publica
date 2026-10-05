-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 60 : rls-policies
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

ALTER TABLE public.actions_tracables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.demandes_grace ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.detentions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.impacts_indices_attente ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jugements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plaintes_en_cours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prisonniers_qhs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rumeurs_actives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vols_en_attente ENABLE ROW LEVEL SECURITY;

-- actions_tracables
CREATE POLICY "traces confession" ON public.actions_tracables FOR DELETE TO authenticated
  USING (auteur = mon_personnage() AND decouvert IS NOT TRUE);
CREATE POLICY "traces creation acteur" ON public.actions_tracables FOR INSERT TO authenticated
  WITH CHECK (auteur = mon_personnage() OR type_action = 'condamnation_torture'::text AND (EXISTS ( SELECT 1
   FROM acteur_poste_courant() a(nom, poste_id, poste_city, pays)
  WHERE a.poste_id = 'juge'::text)));
CREATE POLICY "traces lecture" ON public.actions_tracables FOR SELECT TO anon, authenticated
  USING (true);

-- demandes_grace
CREATE POLICY "grace lue par le president et le proposant" ON public.demandes_grace FOR SELECT TO authenticated
  USING (mon_poste_est_dans('president'::text, data ->> 'pays'::text) OR (data ->> 'proposePar'::text) = (( SELECT mon_personnage() AS mon_personnage)));
CREATE POLICY "grace proposee par le ministre de la justice" ON public.demandes_grace FOR INSERT TO authenticated
  WITH CHECK (mon_poste_est_dans('min_just'::text, data ->> 'pays'::text) AND (data ->> 'proposePar'::text) = (( SELECT mon_personnage() AS mon_personnage)));
CREATE POLICY "grace tranchee par le president" ON public.demandes_grace FOR UPDATE TO authenticated
  USING (mon_poste_est_dans('president'::text, data ->> 'pays'::text))
  WITH CHECK (mon_poste_est_dans('president'::text, data ->> 'pays'::text));

-- detentions
CREATE POLICY detentions_ecriture_soi ON public.detentions FOR INSERT TO authenticated
  WITH CHECK (nom = mon_personnage());
CREATE POLICY detentions_lecture ON public.detentions FOR SELECT TO anon, authenticated
  USING (true);
CREATE POLICY detentions_maj_soi ON public.detentions FOR UPDATE TO authenticated
  USING (nom = mon_personnage())
  WITH CHECK (nom = mon_personnage());

-- impacts_indices_attente
CREATE POLICY impacts_lecture_victime ON public.impacts_indices_attente FOR SELECT TO authenticated
  USING (victime = mon_personnage());

-- jugements
CREATE POLICY jugements_insertion_juge ON public.jugements FOR INSERT TO authenticated
  WITH CHECK (affaire_autorite_de(city));
CREATE POLICY jugements_lecture ON public.jugements FOR SELECT TO anon, authenticated
  USING (true);

-- plaintes_en_cours
CREATE POLICY "affaire lue par les parties, l autorite, ou publique une fois j" ON public.plaintes_en_cours FOR SELECT TO authenticated
  USING (affaire_statut(data) = 'jugee'::text OR affaire_autorite_de(city) OR mon_poste_est_dans('min_just'::text, country) OR mon_poste_est_dans('min_int'::text, country) OR affaire_me_concerne(data));
CREATE POLICY plaintes_insertion_affaires ON public.plaintes_en_cours FOR INSERT TO authenticated
  WITH CHECK ((data IS NULL OR "left"(btrim(data), 1) <> '{'::text OR NOT data::jsonb ? 'commissaire_pj'::text) AND (affaire_autorite_de(city) OR affaire_me_concerne(data)));
CREATE POLICY plaintes_maj_affaires ON public.plaintes_en_cours FOR UPDATE TO authenticated
  USING ((data IS NULL OR "left"(btrim(data), 1) <> '{'::text OR NOT data::jsonb ? 'commissaire_pj'::text) AND (affaire_autorite_de(city) OR affaire_me_concerne(data)))
  WITH CHECK ((data IS NULL OR "left"(btrim(data), 1) <> '{'::text OR NOT data::jsonb ? 'commissaire_pj'::text) AND (affaire_autorite_de(city) OR affaire_me_concerne(data)));

-- prisonniers_qhs
CREATE POLICY prisonniers_qhs_insertion_soi ON public.prisonniers_qhs FOR INSERT TO anon, authenticated
  WITH CHECK ((data ->> 'nom'::text) = mon_personnage());
CREATE POLICY prisonniers_qhs_maj_soi ON public.prisonniers_qhs FOR UPDATE TO anon, authenticated
  USING ((data ->> 'nom'::text) = mon_personnage())
  WITH CHECK ((data ->> 'nom'::text) = mon_personnage());
CREATE POLICY "qhs registre reserve aux habilites et au detenu" ON public.prisonniers_qhs FOR SELECT TO authenticated
  USING (mon_poste_est_dans('min_just'::text, data ->> 'pays'::text) OR mon_poste_est_dans('min_int'::text, data ->> 'pays'::text) OR (data ->> 'nom'::text) = (( SELECT mon_personnage() AS mon_personnage)));

-- rumeurs_actives
CREATE POLICY "dementi par un membre du gouvernement" ON public.rumeurs_actives FOR UPDATE TO authenticated
  USING (mon_poste_est('president'::text) OR mon_poste_est('pm'::text) OR mon_poste_est('min_int'::text) OR mon_poste_est('min_fin'::text) OR mon_poste_est('min_just'::text) OR mon_poste_est('min_def'::text) OR mon_poste_est('min_info'::text) OR mon_poste_est('min_ae'::text))
  WITH CHECK (true);
CREATE POLICY "les rumeurs courent entre joueurs" ON public.rumeurs_actives FOR SELECT TO authenticated
  USING (true);
CREATE POLICY "rumeur creee sur soi-meme" ON public.rumeurs_actives FOR INSERT TO authenticated
  WITH CHECK ((data ->> 'cible'::text) = (( SELECT mon_personnage() AS mon_personnage)));

-- vols_en_attente
CREATE POLICY "vols consommation victime" ON public.vols_en_attente FOR UPDATE TO authenticated
  USING (victime = mon_personnage())
  WITH CHECK (victime = mon_personnage());
CREATE POLICY "vols depot par le voleur" ON public.vols_en_attente FOR INSERT TO authenticated
  WITH CHECK (voleur = mon_personnage());
CREATE POLICY "vols lecture victime" ON public.vols_en_attente FOR SELECT TO authenticated
  USING (victime = mon_personnage());
