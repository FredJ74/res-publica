-- SEED -- usines_rachat_config
-- ============================================================================
-- Table      : public.usines_rachat_config
-- Domaine    : economie
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 1
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Parametrage du rachat de matiere par l'usine.
-- ============================================================================

INSERT INTO public.usines_rachat_config (cle, prix_detail, matieres_hors_chaine) VALUES ('republic|ville_a|zone-production', 'true', '["bois", "minerai"]');
