-- Activation RLS et policies
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle -- phase 60 : rls-policies
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

ALTER TABLE public.inventaire_actions_recus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventaire_ecarts_observes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventaire_livraisons_recues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.objets_achetables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.objets_modeles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.objets_trouves_jours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ordres_generiques ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rue_noeuds_serveur ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rue_sorties_batiments ENABLE ROW LEVEL SECURITY;
