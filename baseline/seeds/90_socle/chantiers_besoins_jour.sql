-- SEED -- chantiers_besoins_jour
-- ============================================================================
-- Table      : public.chantiers_besoins_jour
-- Domaine    : economie
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 3
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Besoins journaliers d'un chantier.
--
-- AVERTISSEMENT : CETTE TABLE EST UN MIROIR DE data.js
-- Un generateur existe deja :
-- outils/generateurs/generer_miroirs_chantiers.py. Les lignes ci-dessous
-- sont copiees depuis la base, conformement a la strategie seed_complet du
-- chantier 2C -- mais copier un miroir fige sa derive. Celui des couts
-- d'ordre avait derive de 24 lignes mortes et 19 ordres gratuits non
-- declares. A terme, ce fichier doit etre ecrit par son generateur depuis
-- data.js, et la table doit rejoindre 95_a-regenerer.
-- ============================================================================

INSERT INTO public.chantiers_besoins_jour (position_cycle, bois, minerai, metal) VALUES ('1', '100', '50', '33');
INSERT INTO public.chantiers_besoins_jour (position_cycle, bois, minerai, metal) VALUES ('2', '100', '50', '33');
INSERT INTO public.chantiers_besoins_jour (position_cycle, bois, minerai, metal) VALUES ('3', '100', '50', '34');
