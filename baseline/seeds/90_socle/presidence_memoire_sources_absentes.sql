-- SEED -- presidence_memoire_sources_absentes
-- ============================================================================
-- Table      : public.presidence_memoire_sources_absentes
-- Domaine    : politique et elections
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 12
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- CE QUI N'EST PAS ENCORE RACCORDABLE A LA MEMOIRE, et pourquoi -- greve et
-- manifestation (tables ecrites depuis le navigateur), sous-actions du
-- Bureau presidentiel (declarees a 0 PA, donc sans porte serveur), ouverture
-- du mandat par le depouillement (postes_attribues n'est pas encore a jour
-- quand il s'execute). Ce n'est pas de la documentation : le banc la lit
-- pour verifier qu'aucune de ces sources n'a ete branchee en cachette. DOUZE
-- LIGNES depuis le 11 octobre 2026 : la chronique nationale et l'election
-- presidentielle y sont entrees avec leur obstacle reel, apres avoir ete
-- branchees puis retirees le meme jour.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE : un monde neuf doit savoir ce qui reste a faire. Une
-- source quitte cette table le jour ou elle obtient une porte serveur, par
-- migration.
-- ============================================================================

-- SEED -- presidence_memoire_sources_absentes
-- ============================================================================
-- Table      : public.presidence_memoire_sources_absentes
-- Domaine    : politique et elections
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 12
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- CE QUI N'EST PAS ENCORE RACCORDABLE A LA MEMOIRE, et pourquoi -- greve et
-- manifestation (tables ecrites depuis le navigateur), sous-actions du
-- Bureau presidentiel (declarees a 0 PA, donc sans porte serveur), ouverture
-- du mandat par le depouillement (postes_attribues n'est pas encore a jour
-- quand il s'execute). Ce n'est pas de la documentation : le banc la lit
-- pour verifier qu'aucune de ces sources n'a ete branchee en cachette. DOUZE
-- LIGNES depuis le 11 octobre 2026 : la chronique nationale et l'election
-- presidentielle y sont entrees avec leur obstacle reel, apres avoir ete
-- branchees puis retirees le meme jour.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE : un monde neuf doit savoir ce qui reste a faire. Une
-- source quitte cette table le jour ou elle obtient une porte serveur, par
-- migration.
-- ============================================================================

INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES ('chronique nationale', 'contexte', 'ECARTEE LE 11 OCTOBRE 2026 APRES AVOIR ETE BRANCHEE LE MATIN MEME. La table porte une policy INSERT ouverte a authenticated (WITH CHECK acteur_identifie()) et elle est ecrite depuis le navigateur par sbEnregistrerEvenementPublic : un joueur pouvait donc fabriquer un fait national et le faire entrer dans la memoire presidentielle. La fermer au client casserait une dizaine de hooks legitimes -- organisations, elections, lobbying, immobilier, Tribune -- donc c est la memoire qui cesse de la croire. A raccorder le jour ou les ecritures publiques de la chronique passeront par des portes serveur.');
INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES ('decret presidentiel', 'reaction', 'Sous-action de adresse_a_la_nation (1 PA), ambigue avec le deuil national.');
INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES ('deuil national', 'reaction', 'Sous-action de adresse_a_la_nation (1 PA), ambigue avec le decret presidentiel. On ne nomme pas un acte qu on ne peut pas distinguer.');
INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES ('dissolution de l Assemblee', 'reaction', 'Sous-action de pouvoirs_exceptionnels (4 PA). Meme obstacle.');
INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES ('effort national', 'reaction', 'Sous-action de effort_national (2 PA), panneau declare a (0,0).');
INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES ('election presidentielle', 'contexte', 'N etait alimentee que par le declencheur de chronique, retire le 11 octobre 2026. Le probleme de fond reste celui deja consigne : au moment ou election_resultats_consigner s execute, postes_attribues ne porte pas encore le nouveau President.');
INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES ('etat d urgence', 'reaction', 'Sous-action de pouvoirs_exceptionnels (3 PA). Le miroir ne declare que le panneau a (0,0) : l acte n atteint aucune porte serveur. L enregistrer depuis payer_ordre reviendrait a confondre l ouverture de la fenetre avec la decision.');
INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES ('greve generale', 'contexte', 'greves_generales n a AUCUNE fonction serveur : la table est ecrite depuis le navigateur. Y puiser ferait entrer dans la memoire un fait qu un client a declare. A raccorder le jour ou le lancement de greve passe par une porte.');
INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES ('manifestation', 'contexte', 'demandes_manifestation est egalement sans fonction serveur, et vide. Meme obstacle que la greve.');
INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES ('nomination du Premier ministre', 'reaction', 'Sous-action de gestion_premier_ministre (2 PA). poste_nommer existe bien au serveur, mais elle sert TOUTES les nominations de tous les postes : y brancher la memoire presidentielle demanderait de decider quelles nominations sont presidentielles, ce qui est un arbitrage et non une lecture.');
INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES ('ouverture du mandat par le depouillement', 'contexte', 'DEUX OBSTACLES, ET LE PREMIER EST NEUF. (1) La chronique nationale a ete ECARTEE des sources le 11 octobre 2026 -- elle est ecrite depuis le navigateur -- donc le depouillement n alimente plus la memoire du tout. (2) L obstacle de fond demeure : au moment ou election_resultats_consigner s execute, postes_attribues ne porte pas encore le nouveau President, donc une ligne se rattacherait au mandat SORTANT. L ouverture d un mandat ne pourra etre datee proprement que le jour ou l attribution du poste et le depouillement seront dans la meme transaction. Ce n est pas bloquant : la separation des mandats est portee par mandat_depuis, pas par cette ligne.');
INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES ('referendum', 'reaction', 'Sous-action de adresse_a_la_nation (3 PA). Meme obstacle -- et le couple (fn, 1 PA) de cette famille est en outre AMBIGU entre le deuil national et le decret presidentiel, donc inexploitable meme si le cout passait.');
