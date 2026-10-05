-- SEED -- catalogue_generique_type
-- ============================================================================
-- Table      : public.catalogue_generique_type
-- Domaine    : economie
-- Categorie  : D (mixte)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 88
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 88 rattachements generique-type.
--
-- ARBITRAGE DE GAME DESIGN
-- Voir catalogue_types.
-- ============================================================================

INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('accessoire-automobile', 'garage-automobile');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('accessoire-d-arme', 'armurerie');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('accessoire-de-mode', 'bien-etre-mode');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('accessoire-militaire', 'vetements');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('accessoire-pour-animal', 'commerce-non-alimentaire');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('accessoire-vestimentaire', 'vetements');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('activite-sportive', 'sport-loisirs');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('affiche', 'arts-culture');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('aliment-brut', 'commerce-alimentaire');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('aliment-prepare', 'commerce-alimentaire');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('animal-de-compagnie', 'commerce-non-alimentaire');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('appareil-de-communication', 'electronique-informatique');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('appareil-electronique', 'electronique-informatique');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('arme-blanche', 'armurerie');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('arme-de-poing', 'armurerie');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('arme-longue', 'armurerie');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('article-de-supporter', 'commerce-non-alimentaire');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('article-de-supporter', 'sport-loisirs');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('article-du-quotidien', 'commerce-non-alimentaire');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('bas', 'vetements');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('bijou', 'bien-etre-mode');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('boisson', 'bar-restauration');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('boisson', 'commerce-alimentaire');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('camera-de-surveillance', 'electronique-informatique');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('carte-postale', 'commerce-non-alimentaire');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('chaussures', 'vetements');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('coiffure', 'bien-etre-mode');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('console-de-jeu', 'electronique-informatique');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('costume-complet', 'vetements');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('decoration-murale', 'maison-decoration');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('deux-roues', 'garage-automobile');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('encas', 'bar-restauration');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('encas-a-emporter', 'bar-restauration');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('encas-a-emporter', 'commerce-alimentaire');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('equipement-de-plein-air', 'sport-loisirs');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('equipement-de-protection-professionnelle', 'bricolage-outillage');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('equipement-domestique', 'maison-decoration');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('equipement-professionnel', 'bricolage-outillage');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('equipement-sportif', 'sport-loisirs');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('explosif', 'armurerie');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('fourniture-de-bricolage', 'bricolage-outillage');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('haut', 'vetements');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('hebergement-prestige', 'hotellerie-hebergement');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('hebergement-standard', 'hotellerie-hebergement');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('hebergement-superieur', 'hotellerie-hebergement');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('imprime', 'arts-culture');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('installation-de-piece', 'garage-automobile');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('instrument-de-musique', 'arts-culture');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('jeu', 'sport-loisirs');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('jeu-video', 'electronique-informatique');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('jouet', 'sport-loisirs');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('livre', 'arts-culture');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('luminaire', 'maison-decoration');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('materiau-de-construction', 'bricolage-outillage');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('materiel-de-premiers-secours', 'pharmacie');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('medicament', 'pharmacie');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('menu-gastronomique', 'bar-restauration');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('meuble-de-prestige', 'maison-decoration');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('meuble-de-rangement', 'maison-decoration');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('meuble-de-repos', 'maison-decoration');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('objet-de-collection', 'commerce-non-alimentaire');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('objet-decoratif', 'maison-decoration');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('oeuvre-d-art', 'arts-culture');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('ordinateur-complet', 'electronique-informatique');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('outil-a-main', 'bricolage-outillage');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('outil-electrique', 'bricolage-outillage');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('peripherique-informatique', 'electronique-informatique');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('piece-automobile', 'garage-automobile');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('piercing', 'bien-etre-mode');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('plat-elabore', 'bar-restauration');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('plat-simple', 'bar-restauration');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('produit-cosmetique', 'bien-etre-mode');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('produit-d-entretien-automobile', 'garage-automobile');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('produit-de-sante', 'pharmacie');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('protection-corporelle', 'armurerie');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('protection-corporelle', 'sport-loisirs');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('reparation', 'garage-automobile');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('soin-esthetique', 'bien-etre-mode');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('soin-pharmaceutique', 'pharmacie');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('souvenir', 'commerce-non-alimentaire');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('spectacle', 'arts-culture');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('support-culturel', 'arts-culture');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('tatouage', 'bien-etre-mode');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('tente', 'sport-loisirs');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('tenue-militaire', 'vetements');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('vegetal', 'commerce-non-alimentaire');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('vehicule-utilitaire', 'garage-automobile');
INSERT INTO public.catalogue_generique_type (generique_id, type_id) VALUES ('voiture', 'garage-automobile');
