-- SEED -- presidence_memoire_sources
-- ============================================================================
-- Table      : public.presidence_memoire_sources
-- Domaine    : politique et elections
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 5
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- LISTE FERMEE DES PROVENANCES admises dans la memoire des mandats, avec le
-- genre (contexte ou reaction) de chacune. C'est ce qui rend la fabrication
-- d'un fait impossible : une source non declaree ne s'enregistre pas, et un
-- genre qui contredit sa source est refuse.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE : la cle etrangere de presidence_memoire pointe sur
-- cette table. Sans ses lignes, aucune ecriture n'est possible du tout.
-- ============================================================================

INSERT INTO public.presidence_memoire_sources (source, genre, note) VALUES ('chronique_nationale', 'contexte', 'Un fait national PUBLIC, recopie de public.chronique_nationale par un declencheur. Cette table n est ecrite que par trois portes serveur -- le depouillement d une election, la publication d une fuite, la publication d un scandale -- et jamais par un navigateur. Ce qui y figure est public par construction : une fuite n y entre qu une fois PUBLIEE. Le declencheur recopie le libelle deja ecrit, sans resumer ni qualifier.');
INSERT INTO public.presidence_memoire_sources (source, genre, note) VALUES ('election_presidentielle', 'contexte', 'Le mandat s ouvre. Consigne au depouillement par election_resultats_consigner, donc par le serveur et jamais par le client.');
INSERT INTO public.presidence_memoire_sources (source, genre, note) VALUES ('guerre_declaree', 'reaction', 'Notre President a declare la guerre. Atteste par guerre_declarer, qui est deja reservee au poste president et ecrit la ligne de guerres dans la meme transaction.');
INSERT INTO public.presidence_memoire_sources (source, genre, note) VALUES ('guerre_subie', 'contexte', 'Un autre empire nous a declare la guerre. C est le contexte national majeur le plus durement atteste du jeu : il ne peut pas etre produit par un navigateur.');
INSERT INTO public.presidence_memoire_sources (source, genre, note) VALUES ('ordre_presidentiel', 'reaction', 'Un ordre REELLEMENT paye par le President en exercice, franchi par payer_ordre et pris dans le registre ferme presidence_memoire_ordres. L acteur est relu en base : un ministre qui tient une conference de presse n entre pas dans la memoire presidentielle, meme si l ordre porte le meme nom.');
