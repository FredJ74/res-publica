-- SEED -- contacts_organisations_passeurs
-- ============================================================================
-- Table      : public.contacts_organisations_passeurs
-- Domaine    : personnage et presence
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 1
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Liste fermee des passeurs, un par empire.
-- ============================================================================

INSERT INTO public.contacts_organisations_passeurs (passeur, type_organisation, pays, expediteur) VALUES ('pat_hounette', 'criminelle', 'republic', 'Pat Hounette');
