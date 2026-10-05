-- SEED -- pnj_referents_sujets_connus
-- ============================================================================
-- Table      : public.pnj_referents_sujets_connus
-- Domaine    : socle PNJ
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 8
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Vocabulaire FERME des sujets memorisables. Le serveur refuse ce qui n'y
-- est pas.
-- ============================================================================

INSERT INTO public.pnj_referents_sujets_connus (referent_id, sujet, libelle) VALUES ('gretta_delieu', 'bureau_prestige', 'le Bureau Prestige');
INSERT INTO public.pnj_referents_sujets_connus (referent_id, sujet, libelle) VALUES ('gretta_delieu', 'bureau_standard', 'le Bureau Standard');
INSERT INTO public.pnj_referents_sujets_connus (referent_id, sujet, libelle) VALUES ('gretta_delieu', 'commerce', 'installer son activite dans un bureau');
INSERT INTO public.pnj_referents_sujets_connus (referent_id, sujet, libelle) VALUES ('gretta_delieu', 'equipements', 'les equipements professionnels a venir');
INSERT INTO public.pnj_referents_sujets_connus (referent_id, sujet, libelle) VALUES ('gretta_delieu', 'louer', 'comment on loue un bureau');
INSERT INTO public.pnj_referents_sujets_connus (referent_id, sujet, libelle) VALUES ('gretta_delieu', 'loyer', 'le prix et le paiement du loyer');
INSERT INTO public.pnj_referents_sujets_connus (referent_id, sujet, libelle) VALUES ('gretta_delieu', 'open_space', 'l''open space et ses postes');
INSERT INTO public.pnj_referents_sujets_connus (referent_id, sujet, libelle) VALUES ('gretta_delieu', 'resilier', 'rendre un bureau');
