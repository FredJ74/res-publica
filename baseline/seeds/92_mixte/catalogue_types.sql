-- SEED -- catalogue_types
-- ============================================================================
-- Table      : public.catalogue_types
-- Domaine    : economie
-- Categorie  : D (mixte)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 14
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 14 types de commerce. Forme generique, mais AUCUNE colonne pays dans les 6
-- tables du catalogue.
--
-- ARBITRAGE DE GAME DESIGN
-- Separation moteur/contenu : le catalogue est partage par les 4 empires
-- alors que son seed porte des identifiants Republia (menu_psm, tshirt_psm,
-- casquette_montrouge).
-- ============================================================================

INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('armurerie', 'Armurerie', '1');
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('arts-culture', 'Arts & culture', '2');
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('bar-restauration', 'Bar & restauration', '3');
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('bien-etre-mode', 'Bien-être & mode', '4');
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('bricolage-outillage', 'Bricolage & outillage', '5');
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('commerce-alimentaire', 'Commerce alimentaire', '6');
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('commerce-non-alimentaire', 'Commerce non alimentaire', '7');
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('electronique-informatique', 'Électronique & informatique', '8');
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('garage-automobile', 'Garage automobile', '9');
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('hotellerie-hebergement', 'Hôtellerie & hébergement', '10');
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('maison-decoration', 'Maison & décoration', '11');
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('pharmacie', 'Pharmacie', '12');
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('sport-loisirs', 'Sport & loisirs', '13');
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('vetements', 'Vêtements', '14');
