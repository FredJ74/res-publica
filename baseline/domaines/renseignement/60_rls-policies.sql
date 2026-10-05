-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine renseignement -- phase 60 : rls-policies
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

ALTER TABLE public.agent_tentatives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agents_renseignement ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cellules_renseignement ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contre_espionnage_tentatives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rapports_cellules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rapports_renseignement ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.renseignement_couvertures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.renseignement_identites_reelles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.renseignements_connus ENABLE ROW LEVEL SECURITY;

-- rapports_renseignement
CREATE POLICY "rens creation acteur" ON public.rapports_renseignement FOR INSERT TO authenticated
  WITH CHECK (mon_personnage() IS NOT NULL);
CREATE POLICY "rens lecture destinataire" ON public.rapports_renseignement FOR SELECT TO authenticated
  USING ((data ->> 'lieutenantNom'::text) = mon_personnage());
CREATE POLICY "rens maj destinataire" ON public.rapports_renseignement FOR UPDATE TO authenticated
  USING ((data ->> 'lieutenantNom'::text) = mon_personnage())
  WITH CHECK ((data ->> 'lieutenantNom'::text) = mon_personnage());
