-- SEED -- escorts_agences
-- ============================================================================
-- Table      : public.escorts_agences
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
-- Agence d'escorts, une par empire. Contenu, jamais mutualise.
-- ============================================================================

INSERT INTO public.escorts_agences (pays, nom) VALUES ('republic', 'Agence Roxane Velours');
