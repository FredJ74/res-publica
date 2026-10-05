-- SEED -- rp_epoques
-- ============================================================================
-- Table      : public.rp_epoques
-- Domaine    : politique et elections
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 1
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Ancrage du calendrier RP de l'empire, pays=republic.
--
-- ARBITRAGE DE GAME DESIGN
-- L'epoque de depart d'un monde neuf est-elle celle-ci ?
-- ============================================================================

INSERT INTO public.rp_epoques (pays, jour_un, note) VALUES ('republic', '2026-09-13', 'Jour 1 = 13/09/2026, date de reinitialisation de la beta et de creation du premier personnage. Choisie pour que le passage de max(day) au temps reel ne decale aucune detention en cours.');
