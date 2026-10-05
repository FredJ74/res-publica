-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle PNJ -- phase 60 : rls-policies
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

ALTER TABLE public.pnj_axes_autorite ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_candidats_catalogue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_employes_metier ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_employeurs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_evenements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_familles_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_fonctions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_force_publique_metier ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_institutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_membres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_metiers_profils ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_militants_metier ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_mouvement_individuel ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_possessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_referents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_referents_pedagogie ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_referents_sujets_connus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_social_escort_choisi ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_social_jalons_regles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_social_relations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_soldats_metier ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_transitions ENABLE ROW LEVEL SECURITY;
