-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine divers et technique -- phase 60 : rls-policies
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

ALTER TABLE public.ambassades_ouvertes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cron_journal ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evenements_globaux ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.propositions_diplomatiques ENABLE ROW LEVEL SECURITY;

-- ambassades_ouvertes
CREATE POLICY "ambassade geree par l empire ou par l hote" ON public.ambassades_ouvertes FOR UPDATE TO authenticated
  USING (mon_poste_est_dans('min_ae'::text, empire) OR mon_poste_est_dans('min_ae'::text, pays_hote))
  WITH CHECK (mon_poste_est_dans('min_ae'::text, empire) OR mon_poste_est_dans('min_ae'::text, pays_hote));
CREATE POLICY "ambassade ouverte par les affaires etrangeres" ON public.ambassades_ouvertes FOR INSERT TO authenticated
  WITH CHECK (mon_poste_est_dans('min_ae'::text, empire));
CREATE POLICY "ambassades visibles des joueurs" ON public.ambassades_ouvertes FOR SELECT TO authenticated
  USING (true);

-- evenements_globaux
CREATE POLICY allow_all_evenements_globaux ON public.evenements_globaux FOR ALL TO PUBLIC
  USING (true)
  WITH CHECK (true);

-- propositions_diplomatiques
CREATE POLICY "diplomatie lue par les deux chancelleries" ON public.propositions_diplomatiques FOR SELECT TO authenticated
  USING (mon_poste_est_dans('min_ae'::text, data ->> 'empireProposeur'::text) OR mon_poste_est_dans('min_ae'::text, data ->> 'empireCible'::text));
CREATE POLICY "proposition faite par le min_ae du pays proposeur" ON public.propositions_diplomatiques FOR INSERT TO authenticated
  WITH CHECK (mon_poste_est_dans('min_ae'::text, data ->> 'empireProposeur'::text));
CREATE POLICY "reponse donnee par le min_ae du pays cible" ON public.propositions_diplomatiques FOR UPDATE TO authenticated
  USING (mon_poste_est_dans('min_ae'::text, data ->> 'empireCible'::text))
  WITH CHECK (mon_poste_est_dans('min_ae'::text, data ->> 'empireCible'::text));

-- registre_ventes_armes
CREATE POLICY "Insertion publique du registre" ON public.registre_ventes_armes FOR INSERT TO PUBLIC
  WITH CHECK (true);
CREATE POLICY "Lecture publique du registre" ON public.registre_ventes_armes FOR SELECT TO PUBLIC
  USING (true);
