-- SEED -- garde_republicaine_postes
-- ============================================================================
-- Table      : public.garde_republicaine_postes
-- Domaine    : militaire
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 3
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- DECLARATION DES POSTES DE GARDE : les trois lieux ou la Garde republicaine
-- tient faction -- Palais presidentiel, Palais du Gouvernement, Assemblee --
-- avec leur ville et leur piece. Registre d'autorite du meme genre que
-- caisses_autorites : c'est lui qui rend la Garde generique plutot que codee
-- batiment par batiment. La colonne vacant_depuis est la seule part vivante
-- de la table (l'horloge des 4 h du garde permanent) et nait a NULL.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE : sans ces trois lignes,
-- garde_republicaine_synchroniser() ne cree aucun garde et les trois halls
-- redeviennent du decor. Le contenu fait partie du socle d'un monde neuf.
-- vacant_depuis n'est JAMAIS seedee.
-- ============================================================================

INSERT INTO public.garde_republicaine_postes (pays, building_id, ville, room_id, libelle, vacant_depuis) VALUES ('republic', 'assemblee', 'capitale', 'accueil_assemblee', 'Accueil de l Assemblee nationale', NULL);
INSERT INTO public.garde_republicaine_postes (pays, building_id, ville, room_id, libelle, vacant_depuis) VALUES ('republic', 'palais-gouvernement', 'capitale', 'hall', 'Hall d entree du Palais du Gouvernement', NULL);
INSERT INTO public.garde_republicaine_postes (pays, building_id, ville, room_id, libelle, vacant_depuis) VALUES ('republic', 'palais-presidentiel', 'capitale', 'accueil_elysee', 'Hall d honneur du Palais de l Elysee', NULL);
