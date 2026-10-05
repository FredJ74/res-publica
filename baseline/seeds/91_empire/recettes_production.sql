-- SEED -- recettes_production
-- ============================================================================
-- Table      : public.recettes_production
-- Domaine    : economie
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 12
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- ARBITRAGE RENDU : les recettes ne sont pas generiques, leur granularite
-- voulue est la VILLE. Deux villes d'un meme empire peuvent differer, et
-- deux recettes identiques restent du contenu propre a chaque ville. Les 12
-- lignes sont donc du contenu, 3 armes par empire.
--
-- ARBITRAGE DE GAME DESIGN
-- DETTE DE DIMENSIONNEMENT : la table ne porte que `pays`, AUCUNE colonne
-- ville. La granularite voulue n'est pas exprimable en l'etat. A traiter
-- hors 2C.
--
-- AVERTISSEMENT : CETTE TABLE EST UN MIROIR DE data.js
-- Un generateur existe deja : .scratch/generer_miroirs_entreprises.py. Les
-- lignes ci-dessous sont copiees depuis la base, conformement a la strategie
-- seed_complet du chantier 2C -- mais copier un miroir fige sa derive. Celui
-- des couts d'ordre avait derive de 24 lignes mortes et 19 ordres gratuits
-- non declares. A terme, ce fichier doit etre ecrit par son generateur
-- depuis data.js, et la table doit rejoindre 95_a-regenerer.
-- ============================================================================

INSERT INTO public.recettes_production (id, ut, label, pays, materiaux, generique_id) VALUES ('ak47', '3', 'AK-47', 'narco', '{"bois": 1, "metal": 3}', NULL);
INSERT INTO public.recettes_production (id, ut, label, pays, materiaux, generique_id) VALUES ('baionnette', '1', 'Baïonnette', 'soviet', '{"metal": 1}', NULL);
INSERT INTO public.recettes_production (id, ut, label, pays, materiaux, generique_id) VALUES ('carabine_chasse', '3', 'Carabine de chasse', 'republic', '{"bois": 2, "metal": 2}', NULL);
INSERT INTO public.recettes_production (id, ut, label, pays, materiaux, generique_id) VALUES ('carabine_precision', '3', 'Carabine de précision', 'khalija', '{"bois": 2, "metal": 2}', NULL);
INSERT INTO public.recettes_production (id, ut, label, pays, materiaux, generique_id) VALUES ('couteau', '1', 'Couteau de poche', 'republic', '{"metal": 1}', NULL);
INSERT INTO public.recettes_production (id, ut, label, pays, materiaux, generique_id) VALUES ('desert_eagle', '2', 'Desert Eagle', 'narco', '{"metal": 2}', NULL);
INSERT INTO public.recettes_production (id, ut, label, pays, materiaux, generique_id) VALUES ('jambiya', '1', 'Jambiya', 'khalija', '{"metal": 1}', NULL);
INSERT INTO public.recettes_production (id, ut, label, pays, materiaux, generique_id) VALUES ('kalachnikov', '3', 'Kalachnikov', 'soviet', '{"bois": 1, "metal": 3}', NULL);
INSERT INTO public.recettes_production (id, ut, label, pays, materiaux, generique_id) VALUES ('machette', '1', 'Machette', 'narco', '{"metal": 1}', NULL);
INSERT INTO public.recettes_production (id, ut, label, pays, materiaux, generique_id) VALUES ('makarov', '2', 'Makarov', 'soviet', '{"metal": 2}', NULL);
INSERT INTO public.recettes_production (id, ut, label, pays, materiaux, generique_id) VALUES ('pistolet_dore', '2', 'Pistolet doré', 'khalija', '{"metal": 2}', NULL);
INSERT INTO public.recettes_production (id, ut, label, pays, materiaux, generique_id) VALUES ('revolver', '2', 'Revolver', 'republic', '{"bois": 1, "metal": 2}', NULL);
