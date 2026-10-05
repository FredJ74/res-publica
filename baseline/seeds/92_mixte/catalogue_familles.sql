-- SEED -- catalogue_familles
-- ============================================================================
-- Table      : public.catalogue_familles
-- Domaine    : economie
-- Categorie  : D (mixte)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 40
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 40 familles commerciales. Meme absence de dimension empire.
--
-- ARBITRAGE DE GAME DESIGN
-- Voir catalogue_types.
-- ============================================================================

INSERT INTO public.catalogue_familles (id, libelle) VALUES ('accessoires-armes', 'Accessoires d''armes');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('animaux', 'Animaux');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('armes', 'Armes');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('articles-quotidien', 'Articles du quotidien');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('arts', 'Arts');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('bijoux-accessoires', 'Bijoux & accessoires');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('boissons', 'Boissons');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('coiffure-esthetique', 'Coiffure & esthétique');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('communication', 'Communication');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('decoration', 'Décoration');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('edition-papeterie', 'Édition & papeterie');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('electronique', 'Électronique');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('entretien', 'Entretien');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('equipement-domestique', 'Équipement domestique');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('fleurs-vegetaux', 'Fleurs & végétaux');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('hebergement', 'Hébergement');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('informatique', 'Informatique');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('jeux-electroniques', 'Jeux électroniques');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('jeux-jouets', 'Jeux & jouets');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('materiaux-fournitures', 'Matériaux & fournitures');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('medicaments', 'Médicaments');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('mobilier', 'Mobilier');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('musique-audiovisuel', 'Musique & audiovisuel');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('outillage', 'Outillage');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('pieces-accessoires', 'Pièces & accessoires');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('plein-air', 'Plein air');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('produits-frais', 'Produits frais');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('produits-sante', 'Produits de santé');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('produits-transformes', 'Produits transformés');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('protection', 'Protection');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('restauration', 'Restauration');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('securite-travail', 'Sécurité & travail');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('soins-premiers-secours', 'Soins & premiers secours');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('souvenirs-collections', 'Souvenirs & collections');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('spectacles', 'Spectacles');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('sport', 'Sport');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('tatouage-piercing', 'Tatouage & piercing');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('vehicules', 'Véhicules');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('vetements-civils', 'Vêtements civils');
INSERT INTO public.catalogue_familles (id, libelle) VALUES ('vetements-militaires', 'Vêtements militaires');
