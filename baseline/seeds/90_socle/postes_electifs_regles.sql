-- SEED -- postes_electifs_regles
-- ============================================================================
-- Table      : public.postes_electifs_regles
-- Domaine    : postes et institutions
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 4
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Regles des postes electifs.
--
-- AVERTISSEMENT : CETTE TABLE EST UN MIROIR DE data.js
-- Un generateur existe deja : .scratch/generer_postes_electifs.py. Les
-- lignes ci-dessous sont copiees depuis la base, conformement a la strategie
-- seed_complet du chantier 2C -- mais copier un miroir fige sa derive. Celui
-- des couts d'ordre avait derive de 24 lignes mortes et 19 ordres gratuits
-- non declares. A terme, ce fichier doit etre ecrit par son generateur
-- depuis data.js, et la table doit rejoindre 95_a-regenerer.
-- ============================================================================

INSERT INTO public.postes_electifs_regles (poste_id, nom, scope, niveau, min_inf, nb_par_ville) VALUES ('chef_syndicat', 'Chef Syndical', 'national', 'national', '5', NULL);
INSERT INTO public.postes_electifs_regles (poste_id, nom, scope, niveau, min_inf, nb_par_ville) VALUES ('depute', 'Député', 'departemental', 'ville', '5', '3');
INSERT INTO public.postes_electifs_regles (poste_id, nom, scope, niveau, min_inf, nb_par_ville) VALUES ('maire', 'Maire', 'local', 'ville', '3', NULL);
INSERT INTO public.postes_electifs_regles (poste_id, nom, scope, niveau, min_inf, nb_par_ville) VALUES ('president', 'Président', 'national', 'national', '10', NULL);
