-- SEED -- repartitions_budgetaires
-- ============================================================================
-- Table      : public.repartitions_budgetaires
-- Domaine    : finances publiques
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 15
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- La cle de repartition budgetaire : quelle source verse quelle part a quel
-- beneficiaire, et quel poste peut la modifier. C'est la REGLE, pas un
-- historique -- elle doit naitre avec le monde. Les quinze lignes de
-- Republia sont celles de l'arbitrage du 8 octobre 2026 : dix caisses
-- nationales (neuf a 9 %, l'Assemblee a 19 %), Defense -> Caserne 65 %,
-- Interieur -> Douanes 35 %, et les trois tribunaux a part NULLE. Les trois
-- autres empires n'ont AUCUNE ligne, et c'est voulu : sans ligne declaree,
-- la cascade ne verse rien plutot que d'appliquer la cle de Republia.
--
-- ARBITRAGE DE GAME DESIGN
-- Les trois parts de la Justice restent NON ARBITREES (part_pourcent NULL).
-- Le mecanisme est valide, les pourcentages ne le sont pas -- aucune
-- repartition par defaut entre les trois tribunaux n'a ete inventee. Le
-- Ministre de la Justice les fixe lui-meme, ou Fred les arbitre.
-- ============================================================================

INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_def', 'caserne-militaire', '65.00', 'min_def', '1', 'Caserne militaire', 'Valeur par defaut arbitree le 8 octobre 2026. Le ministre peut la modifier.');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_fin', 'assemblee', '19.00', 'min_fin', '10', 'Assemblée nationale', NULL);
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-min_ae', '9.00', 'min_fin', '8', 'Ministère des Affaires étrangères', NULL);
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-min_def', '9.00', 'min_fin', '6', 'Ministère de la Défense', NULL);
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-min_fin', '9.00', 'min_fin', '4', 'Ministère de l''Économie et des Finances', 'Part conservee par le repartiteur : journalisee, jamais transferee. C''est ce qui empeche la boucle.');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-min_info', '9.00', 'min_fin', '7', 'Ministère de l''Information', NULL);
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-min_int', '9.00', 'min_fin', '3', 'Ministère de l''Intérieur', NULL);
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-min_just', '9.00', 'min_fin', '5', 'Ministère de la Justice', NULL);
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-pm', '9.00', 'min_fin', '2', 'Premier ministre', NULL);
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_fin', 'palais-gouvernement', '9.00', 'min_fin', '9', 'Palais du Gouvernement', 'Actions gouvernementales communes -- communication et autres depenses institutionnelles. DISTINCTE de la caisse du Premier ministre.');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_fin', 'palais-presidentiel', '9.00', 'min_fin', '1', 'Présidence', NULL);
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_int', 'douane', '35.00', 'min_int', '1', 'Service des douanes', 'Valeur par defaut arbitree le 8 octobre 2026. Le ministre peut la modifier.');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_just', 'tribunal_capitale', NULL, 'min_just', '1', 'Tribunal de Luthécia', 'Part NON ARBITREE au 8 octobre 2026 : mecanisme valide, pourcentage a decider.');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_just', 'tribunal_ville_a', NULL, 'min_just', '2', 'Tribunal de Port-Sainte-Marie', 'Part NON ARBITREE au 8 octobre 2026.');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES ('republic', 'gouvernement-min_just', 'tribunal_ville_b', NULL, 'min_just', '3', 'Tribunal de Montrouge', 'Part NON ARBITREE au 8 octobre 2026.');
