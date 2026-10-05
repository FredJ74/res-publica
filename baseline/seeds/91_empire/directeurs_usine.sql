-- SEED -- directeurs_usine
-- ============================================================================
-- Table      : public.directeurs_usine
-- Domaine    : economie
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 3
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- ARBITRAGE RENDU : un monde neuf commence avec les directeurs PNJ des
-- usines deja en poste. C'est donc de l'etat initial authored, pas une
-- nomination produite par le jeu.
-- ============================================================================

INSERT INTO public.directeurs_usine (poste_id, ville, building_id, produits) VALUES ('directeur_pharma', 'capitale', 'usine-pharmaceutique-luthecia', '["medicaments", "desinfectant"]');
INSERT INTO public.directeurs_usine (poste_id, ville, building_id, produits) VALUES ('directeur_raffinerie', 'ville_b', 'raffinerie-montrouge', '["carburant"]');
INSERT INTO public.directeurs_usine (poste_id, ville, building_id, produits) VALUES ('directeur_tabac_alcools', 'ville_a', 'pole-tabac-alcools-psm', '["alcool", "tabac"]');
