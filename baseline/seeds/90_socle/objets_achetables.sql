-- SEED -- objets_achetables
-- ============================================================================
-- Table      : public.objets_achetables
-- Domaine    : socle
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 6
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Référentiel serveur : contenu initial requis, extraction des lignes encore
-- nécessaire.
--
-- ARBITRAGE DE GAME DESIGN
-- Structure constatée dans les exports canoniques du 31/10/2026. Aucun
-- compte de lignes déduit du schéma. Compte SQL relevé en lecture seule par
-- ChatGPT, commit 2a71eaf77dac83370a02c4f12cd71b502a20d772, 31/10/2026 ; ne
-- prouve pas la possession des lignes ni leur actualité au prochain point de
-- coupe.
-- ============================================================================

INSERT INTO public.objets_achetables (ordre, modele) VALUES ('acheter_ghb', 'poison:ghb');
INSERT INTO public.objets_achetables (ordre, modele) VALUES ('acheter_gilet', 'gilet');
INSERT INTO public.objets_achetables (ordre, modele) VALUES ('acheter_parapluie', 'poison:parapluie');
INSERT INTO public.objets_achetables (ordre, modele) VALUES ('acheter_polonium', 'poison:polonium');
INSERT INTO public.objets_achetables (ordre, modele) VALUES ('acheter_relique', 'relique_loukoum');
INSERT INTO public.objets_achetables (ordre, modele) VALUES ('acheter_vipere', 'poison:vipere');
