-- SEED -- catalogue_variantes
-- ============================================================================
-- Table      : public.catalogue_variantes
-- Domaine    : economie
-- Categorie  : D (mixte)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 6
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 6 variantes d'objets rattachees aux generiques. Meme absence de dimension
-- empire que le reste du catalogue.
--
-- ARBITRAGE DE GAME DESIGN
-- Voir catalogue_types.
-- ============================================================================

INSERT INTO public.catalogue_variantes (id, generique_id, cle, libelle, regime, surcharges, capacites, note) VALUES ('appareil-de-communication--militaire', 'appareil-de-communication', 'militaire', 'Radio de campagne', 'reglemente', NULL, '["transmettre_ordre_collectif_a_distance"]', 'Exigee des DEUX cotes de la chaine de commandement (militaire_ordre_collectif, refus radio_manquante).');
INSERT INTO public.catalogue_variantes (id, generique_id, cle, libelle, regime, surcharges, capacites, note) VALUES ('encas-a-emporter--militaire', 'encas-a-emporter', 'militaire', 'Ration de combat', 'reglemente', NULL, '["nourrir_soldat_pnj"]', 'Consommable par le PJ ou distribuable a des soldats PNJ menes.');
INSERT INTO public.catalogue_variantes (id, generique_id, cle, libelle, regime, surcharges, capacites, note) VALUES ('equipement-de-plein-air--militaire', 'equipement-de-plein-air', 'militaire', 'Jumelles', 'reglemente', NULL, '["observer_secteur"]', 'Ordre « Observer » a 1 PA via militaire_observer. Le chemin passif d''entree de zone est actuellement casse (anomalie documentee, non corrigee ici).');
INSERT INTO public.catalogue_variantes (id, generique_id, cle, libelle, regime, surcharges, capacites, note) VALUES ('materiel-de-premiers-secours--militaire', 'materiel-de-premiers-secours', 'militaire', 'Trousse de premiers secours', 'reglemente', NULL, '["soigner_co_present"]', 'Usage unique. Co-presence stricte exigee si la cible n''est pas soi.');
INSERT INTO public.catalogue_variantes (id, generique_id, cle, libelle, regime, surcharges, capacites, note) VALUES ('protection-corporelle--militaire', 'protection-corporelle', 'militaire', 'Gilet pare-balles réglementaire', 'reglemente', NULL, '["absorber_tir_en_bataille"]', 'Une seule chance, definitive : un gilet fragilise reste inerte, aucun code ne le repare.');
INSERT INTO public.catalogue_variantes (id, generique_id, cle, libelle, regime, surcharges, capacites, note) VALUES ('tente--militaire', 'tente', 'militaire', 'Tente de campagne', 'reglemente', NULL, '["abriter_bivouac", "reposer_section"]', 'Abrite 13 personnes, leader compris. Non consommee, aucune usure.');
