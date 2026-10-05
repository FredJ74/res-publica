-- SEED -- pa_credits_sources
-- ============================================================================
-- Table      : public.pa_credits_sources
-- Domaine    : finances publiques
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 2
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Liste blanche des sources de credit de PA, avec le montant autorise.
-- Ecriture fermee au client depuis le 26/09.
-- ============================================================================

INSERT INTO public.pa_credits_sources (source, montant) VALUES ('aliment_frais', '1');
INSERT INTO public.pa_credits_sources (source, montant) VALUES ('remboursement_ordre', NULL);
