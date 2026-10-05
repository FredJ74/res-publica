-- SEED -- commerces_types
-- ============================================================================
-- Table      : public.commerces_types
-- Domaine    : economie
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 11
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Types de commerce du referentiel.
--
-- AVERTISSEMENT : CETTE TABLE EST UN MIROIR DE data.js
-- Un generateur existe deja : .scratch/generer_miroirs_entreprises.py. Les
-- lignes ci-dessous sont copiees depuis la base, conformement a la strategie
-- seed_complet du chantier 2C -- mais copier un miroir fige sa derive. Celui
-- des couts d'ordre avait derive de 24 lignes mortes et 19 ordres gratuits
-- non declares. A terme, ce fichier doit etre ecrit par son generateur
-- depuis data.js, et la table doit rejoindre 95_a-regenerer.
-- ============================================================================

INSERT INTO public.commerces_types (cle, type) VALUES ('bar-des-pecheurs|salle_bar', 'bar');
INSERT INTO public.commerces_types (cle, type) VALUES ('brasserie-voyageurs-montrouge', 'brasserie');
INSERT INTO public.commerces_types (cle, type) VALUES ('cafe-gare-montrouge', 'cafe');
INSERT INTO public.commerces_types (cle, type) VALUES ('cafe-tabac-cheminots-montrouge', 'cafe');
INSERT INTO public.commerces_types (cle, type) VALUES ('capitaine-sauvage|salle_principale', 'brasserie');
INSERT INTO public.commerces_types (cle, type) VALUES ('hotel-mineur', 'cafe');
INSERT INTO public.commerces_types (cle, type) VALUES ('hotel-port|hall_port', 'cafe');
INSERT INTO public.commerces_types (cle, type) VALUES ('hotel-republica', 'brasserie');
INSERT INTO public.commerces_types (cle, type) VALUES ('marche', 'marche');
INSERT INTO public.commerces_types (cle, type) VALUES ('marche-psm|etals', 'marche');
INSERT INTO public.commerces_types (cle, type) VALUES ('stade|buvette', 'buvette');
