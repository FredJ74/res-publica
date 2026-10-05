-- SEED -- chaines_production_usine
-- ============================================================================
-- Table      : public.chaines_production_usine
-- Domaine    : economie
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 5
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Chaines de production disponibles.
-- ============================================================================

INSERT INTO public.chaines_production_usine (produit, ville, building_id, matiere, salaire_pa) VALUES ('alcool', 'ville_a', 'pole-tabac-alcools-psm', 'cereales', '55');
INSERT INTO public.chaines_production_usine (produit, ville, building_id, matiere, salaire_pa) VALUES ('carburant', 'ville_b', 'raffinerie-montrouge', 'petrole', '70');
INSERT INTO public.chaines_production_usine (produit, ville, building_id, matiere, salaire_pa) VALUES ('desinfectant', 'capitale', 'usine-pharmaceutique-luthecia', 'alcool', '70');
INSERT INTO public.chaines_production_usine (produit, ville, building_id, matiere, salaire_pa) VALUES ('medicaments', 'capitale', 'usine-pharmaceutique-luthecia', 'plantes', '84');
INSERT INTO public.chaines_production_usine (produit, ville, building_id, matiere, salaire_pa) VALUES ('tabac', 'ville_a', 'pole-tabac-alcools-psm', 'plantes', '66');
