-- SEED -- entreprises_prix_rachat
-- ============================================================================
-- Table      : public.entreprises_prix_rachat
-- Domaine    : economie
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 6
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Prix de rachat par type d'entreprise.
--
-- AVERTISSEMENT : CETTE TABLE EST UN MIROIR DE data.js
-- Un generateur existe deja : .scratch/generer_miroirs_entreprises.py. Les
-- lignes ci-dessous sont copiees depuis la base, conformement a la strategie
-- seed_complet du chantier 2C -- mais copier un miroir fige sa derive. Celui
-- des couts d'ordre avait derive de 24 lignes mortes et 19 ordres gratuits
-- non declares. A terme, ce fichier doit etre ecrit par son generateur
-- depuis data.js, et la table doit rejoindre 95_a-regenerer.
-- ============================================================================

INSERT INTO public.entreprises_prix_rachat (batiment, prix) VALUES ('bar-des-pecheurs', '180000');
INSERT INTO public.entreprises_prix_rachat (batiment, prix) VALUES ('brasserie-voyageurs-montrouge', '120000');
INSERT INTO public.entreprises_prix_rachat (batiment, prix) VALUES ('cafe-gare-montrouge', '180000');
INSERT INTO public.entreprises_prix_rachat (batiment, prix) VALUES ('cafe-tabac-cheminots-montrouge', '180000');
INSERT INTO public.entreprises_prix_rachat (batiment, prix) VALUES ('hotel-mineur', '80000');
INSERT INTO public.entreprises_prix_rachat (batiment, prix) VALUES ('hotel-republica', '380000');
