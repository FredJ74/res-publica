-- SEED -- justice_avocats_commis
-- ============================================================================
-- Table      : public.justice_avocats_commis
-- Domaine    : justice
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 3
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- LES TROIS AVOCATS COMMIS D'OFFICE, et la seule caracteristique qu'ils
-- aient : CHA 16, identique dans les trois villes de Republia. Un REGISTRE
-- plutot qu'un CASE dans une fonction, pour que la quatrieme ville ou le
-- deuxieme empire s'ajoutent par une ligne. Les avocats existaient depuis la
-- veille comme PNJ de DECOR dans data.js, sans aucune caracteristique :
-- c'est ici que leur efficacite mecanique vit. Aucun droit client : la table
-- n'est lue que par justice_avocat_commis(), appelee depuis
-- plainte_defendre.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE : sans ses lignes, plainte_defendre refuse
-- `pas_d_avocat_commis_d_office` et la procedure simplifiee est inerte dans
-- tout le pays. Le CHA 16 est l'arbitrage du 12 octobre 2026
-- ============================================================================

INSERT INTO public.justice_avocats_commis (pays, ville, nom, cha) VALUES ('republic', 'capitale', 'Maître Plaidoyer (PNJ)', '16');
INSERT INTO public.justice_avocats_commis (pays, ville, nom, cha) VALUES ('republic', 'ville_a', 'Maître Ali Bihanbéton (PNJ)', '16');
INSERT INTO public.justice_avocats_commis (pays, ville, nom, cha) VALUES ('republic', 'ville_b', 'Maître Henri Nossant (PNJ)', '16');
