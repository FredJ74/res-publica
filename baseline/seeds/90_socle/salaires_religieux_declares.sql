-- SEED -- salaires_religieux_declares
-- ============================================================================
-- Table      : public.salaires_religieux_declares
-- Domaine    : finances publiques
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 4
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Bareme des salaires religieux.
-- ============================================================================

INSERT INTO public.salaires_religieux_declares (cle, ville, caisse, montant, libelle) VALUES ('grand_pretre', NULL, 'republic_tabernacle-impots', '100', 'Grand Pretre national');
INSERT INTO public.salaires_religieux_declares (cle, ville, caisse, montant, libelle) VALUES ('pretre:capitale', 'capitale', 'republic_tabernacle-impots', '100', 'Pretre du Grand Tabernacle (Luthecia)');
INSERT INTO public.salaires_religieux_declares (cle, ville, caisse, montant, libelle) VALUES ('pretre:ville_a', 'ville_a', 'republic_notre-dame-mer', '100', 'Pretre de Notre-Dame-de-la-Mer (Port-Sainte-Marie)');
INSERT INTO public.salaires_religieux_declares (cle, ville, caisse, montant, libelle) VALUES ('pretre:ville_b', 'ville_b', 'republic_eglise-montrouge', '100', 'Pretre de l''eglise de Montrouge');
