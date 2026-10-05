-- SEED -- structures_medicales
-- ============================================================================
-- Table      : public.structures_medicales
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
-- 3 structures medicales. Contenu de Republia dans une table sans colonne
-- pays.
--
-- ARBITRAGE DE GAME DESIGN
-- Separation moteur/contenu.
-- ============================================================================

INSERT INTO public.structures_medicales (building_id, ressources, financement, categorie_caisse) VALUES ('clinique-privee', '["desinfectant", "medicaments"]', 'propre', NULL);
INSERT INTO public.structures_medicales (building_id, ressources, financement, categorie_caisse) VALUES ('dispensaire-public', '["desinfectant"]', 'institution', 'dispensaire');
INSERT INTO public.structures_medicales (building_id, ressources, financement, categorie_caisse) VALUES ('dispensaire-public-v', '["desinfectant"]', 'institution', 'dispensaire');
