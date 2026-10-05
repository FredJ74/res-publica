-- SEED -- entrepots_par_ville
-- ============================================================================
-- Table      : public.entrepots_par_ville
-- Domaine    : economie
-- Categorie  : D (mixte)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 3
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 5 entrepots. Contenu de Republia dans une table sans colonne pays ; le
-- prix y est mute en jeu.
--
-- ARBITRAGE DE GAME DESIGN
-- Separation moteur/contenu, et le prix releve-t-il de l'initial ?
--
-- FILTRE APPLIQUE
-- 5 lignes en base, dont 2 de TEST : (zzville-a, entrepot-zztest-a) et
-- (zzville-b, entrepot-zztest-b). Les 3 entrepots reels sont Luthecia,
-- Port-Sainte-Marie et Montrouge. Les lignes de test ne traversent pas :
-- c'est une exclusion de fait, pas un arbitrage.
-- ============================================================================

INSERT INTO public.entrepots_par_ville (ville, building_id) VALUES ('capitale', 'entrepot-logistique-luthecia');
INSERT INTO public.entrepots_par_ville (ville, building_id) VALUES ('ville_a', 'entrepot-logistique-psm');
INSERT INTO public.entrepots_par_ville (ville, building_id) VALUES ('ville_b', 'entrepot-logistique-montrouge');
