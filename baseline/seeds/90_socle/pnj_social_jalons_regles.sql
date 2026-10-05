-- SEED -- pnj_social_jalons_regles
-- ============================================================================
-- Table      : public.pnj_social_jalons_regles
-- Domaine    : socle PNJ
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 2
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Quand un PNJ social declenche une intervention. Regle, pas etat.
-- ============================================================================

INSERT INTO public.pnj_social_jalons_regles (pnj_id, jalon, min_rencontres, max_conversations, rang) VALUES ('jean_lou_demer', 'abordage_deuxieme_visite', '2', '0', '1');
INSERT INTO public.pnj_social_jalons_regles (pnj_id, jalon, min_rencontres, max_conversations, rang) VALUES ('marine_leroux', 'accueil_premiere_visite', '1', NULL, '1');
