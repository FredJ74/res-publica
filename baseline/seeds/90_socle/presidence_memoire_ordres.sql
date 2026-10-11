-- SEED -- presidence_memoire_ordres
-- ============================================================================
-- Table      : public.presidence_memoire_ordres
-- Domaine    : politique et elections
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 6
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- LISTE FERMEE DES ACTES PRESIDENTIELS MEMORABLES, par triplet (fn, pa,
-- cost) -- le meme triplet que payer_ordre valide contre le miroir de
-- data.js. Les quatre ordres de REGROUPEMENT du Bureau en sont
-- VOLONTAIREMENT absents : declares a (0 PA, 0 FR), ils n'attestent que
-- l'ouverture d'un panneau, pas un acte.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE : sans ces six lignes, aucun acte presidentiel n'entre
-- dans la memoire et payer_ordre ne temoigne de rien. Le contenu est du
-- socle, pas de l'etat vivant.
-- ============================================================================

INSERT INTO public.presidence_memoire_ordres (fn, pa, cost, sujet) VALUES ('banquet_diplo', '3', '2000', 'un banquet diplomatique');
INSERT INTO public.presidence_memoire_ordres (fn, pa, cost, sujet) VALUES ('conference_presse', '2', '0', 'une conference de presse');
INSERT INTO public.presidence_memoire_ordres (fn, pa, cost, sujet) VALUES ('dementi', '2', '0', 'un dementi officiel');
INSERT INTO public.presidence_memoire_ordres (fn, pa, cost, sujet) VALUES ('gracier', '2', '0', 'une grace examinee');
INSERT INTO public.presidence_memoire_ordres (fn, pa, cost, sujet) VALUES ('propagande_etat', '3', '500', 'une campagne de propagande d Etat');
INSERT INTO public.presidence_memoire_ordres (fn, pa, cost, sujet) VALUES ('reception_etat', '2', '1000', 'une reception d Etat');
