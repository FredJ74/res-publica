-- SEED -- fonds_credits_sources
-- ============================================================================
-- Table      : public.fonds_credits_sources
-- Domaine    : finances publiques
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 6
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Liste blanche des sources de credit de fonds.
-- ============================================================================

INSERT INTO public.fonds_credits_sources (source, montant, part, libelle) VALUES ('remboursement_cession', NULL, '1', 'Remboursement — cession non finalisee');
INSERT INTO public.fonds_credits_sources (source, montant, part, libelle) VALUES ('remboursement_debauchage', NULL, '1', 'Remboursement — debauchage refuse par le serveur');
INSERT INTO public.fonds_credits_sources (source, montant, part, libelle) VALUES ('remboursement_kompromat', '300', '1', 'Remboursement — fabrication de kompromat echouee');
INSERT INTO public.fonds_credits_sources (source, montant, part, libelle) VALUES ('remboursement_ordre', NULL, '1', 'Remboursement integral du cout d''un ordre qui n''a pas abouti');
INSERT INTO public.fonds_credits_sources (source, montant, part, libelle) VALUES ('remboursement_ordre_echoue', NULL, '0.3', 'Remboursement de 30% du cout d''un ordre dont le jet a echoue');
INSERT INTO public.fonds_credits_sources (source, montant, part, libelle) VALUES ('remboursement_recette_lieu', NULL, '1', 'Remboursement — caisse du lieu indisponible');
