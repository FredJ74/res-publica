-- SEED -- niveaux_prison
-- ============================================================================
-- Table      : public.niveaux_prison
-- Domaine    : justice
-- Categorie  : D (mixte)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 4
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 4 niveaux de prison. Valeurs initiales plausibles, mais aucune colonne
-- pays et aucune RPC ecrivante.
--
-- ARBITRAGE DE GAME DESIGN
-- Separation moteur/contenu ; et la valeur 100 est-elle un etat initial ou
-- un parametre ?
--
-- COLONNES OMISES (defaut now()) : updated_at
-- La date de creation d'une ligne n'est pas du contenu authored : c'est le
-- jour ou le monde est ne. Omettre la colonne laisse le defaut jouer.
-- ============================================================================

INSERT INTO public.niveaux_prison (id, data) VALUES ('republic_capitale', '{"niveau": 100}');
INSERT INTO public.niveaux_prison (id, data) VALUES ('republic_caserne', '{"niveau": 100}');
INSERT INTO public.niveaux_prison (id, data) VALUES ('republic_ville_a', '{"niveau": 87}');
INSERT INTO public.niveaux_prison (id, data) VALUES ('republic_ville_b', '{"niveau": 100}');
