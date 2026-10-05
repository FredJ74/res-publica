-- SEED -- armureries_dotations
-- ============================================================================
-- Table      : public.armureries_dotations
-- Domaine    : militaire
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 3
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Dotation initiale d'armurerie, renseignee pour 3 empires.
--
-- AVERTISSEMENT : CETTE TABLE EST UN MIROIR DE data.js
-- Un generateur existe deja : .scratch/generer_miroirs_entreprises.py. Les
-- lignes ci-dessous sont copiees depuis la base, conformement a la strategie
-- seed_complet du chantier 2C -- mais copier un miroir fige sa derive. Celui
-- des couts d'ordre avait derive de 24 lignes mortes et 19 ordres gratuits
-- non declares. A terme, ce fichier doit etre ecrit par son generateur
-- depuis data.js, et la table doit rejoindre 95_a-regenerer.
-- ============================================================================

INSERT INTO public.armureries_dotations (pays, caisse, stock_matieres, parametres) VALUES ('narco', '20000', '{"bois": 10, "metal": 20}', '{"stockMax": {"ak47": 5, "machette": 10, "desert_eagle": 5}, "prixVente": {"ak47": 1200, "machette": 300, "desert_eagle": 800}, "prixAchatMatiere": {"bois": 10, "metal": 20}}');
INSERT INTO public.armureries_dotations (pays, caisse, stock_matieres, parametres) VALUES ('republic', '20000', '{"bois": 10, "metal": 20}', '{"stockMax": {"couteau": 10, "revolver": 5, "carabine_chasse": 5}, "prixVente": {"couteau": 300, "revolver": 800, "carabine_chasse": 1200}, "prixAchatMatiere": {"bois": 10, "metal": 20}}');
INSERT INTO public.armureries_dotations (pays, caisse, stock_matieres, parametres) VALUES ('soviet', '20000', '{"bois": 10, "metal": 20}', '{"stockMax": {"makarov": 5, "baionnette": 10, "kalachnikov": 5}, "prixVente": {"makarov": 800, "baionnette": 300, "kalachnikov": 1200}, "prixAchatMatiere": {"bois": 10, "metal": 20}}');
