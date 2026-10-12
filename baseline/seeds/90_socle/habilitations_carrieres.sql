-- SEED -- habilitations_carrieres
-- ============================================================================
-- Table      : public.habilitations_carrieres
-- Domaine    : divers et technique
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 7
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- QUELLE FAMILLE OUVRE QUELLE HABILITATION. Sept lignes : JUSTICE ouvre
-- les quatre fonctions judiciaires, ARMEE ouvre le commandement,
-- PROFESSIONS INTELLECTUELLES la medecine, MEDIAS la communication.
-- L'union des carrieres d'un personnage -- une, ou deux au plus -- donne
-- ses habilitations.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE, pour la meme raison que habilitations : c'est la
-- table qui dit ce que chaque carriere permet, et un monde neuf doit
-- naitre avec.
-- ============================================================================

INSERT INTO public.habilitations_carrieres (habilitation, carriere) VALUES ('avocat', 'magistrat');
INSERT INTO public.habilitations_carrieres (habilitation, carriere) VALUES ('commissaire', 'magistrat');
INSERT INTO public.habilitations_carrieres (habilitation, carriere) VALUES ('communication', 'press');
INSERT INTO public.habilitations_carrieres (habilitation, carriere) VALUES ('juge', 'magistrat');
INSERT INTO public.habilitations_carrieres (habilitation, carriere) VALUES ('medecine', 'doctor');
INSERT INTO public.habilitations_carrieres (habilitation, carriere) VALUES ('militaire', 'officer');
INSERT INTO public.habilitations_carrieres (habilitation, carriere) VALUES ('procureur', 'magistrat');
