-- SEED -- repartitions_budgetaires
-- ============================================================================
-- Table      : public.repartitions_budgetaires
-- Domaine    : finances publiques
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 28
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- La cle de repartition budgetaire : quelle source verse quelle part a quel
-- beneficiaire, et quel poste peut la modifier. C'est la REGLE, pas un
-- historique -- elle doit naitre avec le monde. Les vingt-cinq lignes de
-- Republia sont celles des arbitrages du 8 octobre 2026. NEUF SONT
-- MUNICIPALES, ajoutees par le chantier des budgets municipaux : trois
-- villes x trois beneficiaires -- commissariat 40/100, entrepot 40/100, et
-- la mairie elle-meme 20/100, dont la part est journalisee mais jamais
-- transferee, comme celle du Ministere de l'Economie. Les seize autres sont
-- nationales ou ministerielles : dix caisses nationales (neuf a 9 %,
-- l'Assemblee a 19 %), Defense -> Caserne 65 %, Interieur -> Douanes 35 %,
-- QHS 0 % (beneficiaire reconnu de l'Interieur, sans financement recurrent
-- au demarrage -- a ne pas confondre avec une part non arbitree), et les
-- trois tribunaux a UN TIERS chacun. LA PART EST UNE FRACTION EXACTE
-- (part_numerateur sur part_denominateur) et non un pourcentage : trois
-- parts rigoureusement egales s'ecrivent 1/3, ce qu'aucun pourcentage
-- decimal ne sait faire sans creer une preference permanente. Les trois
-- autres empires n'ont AUCUNE ligne, et c'est voulu : sans ligne declaree,
-- la cascade ne verse rien plutot que d'appliquer la cle de Republia. DOUZE
-- SONT MUNICIPALES depuis le 10 octobre 2026 : une QUATRIEME ligne par
-- ville, libellee Subventions, a 0/100 -- part a 0 % PAR DEFAUT selon le
-- precedent du QHS, donc la ligne existe et est editable sans deplacer un
-- franc tant que le maire ne l'a pas decidee. Les trois sommes municipales
-- restent a 100 % exactement (40/40/20/0).
--
-- ARBITRAGE DE GAME DESIGN
-- ARBITRE LE 7 OCTOBRE 2026 : les trois tribunaux sont a PARTS EGALES au
-- demarrage, un tiers exact chacun. Il ne reste aucune part non arbitree
-- dans le systeme. Le Ministre de la Justice peut modifier librement cette
-- repartition depuis son tableau de bord.
-- ============================================================================

INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_def', 'caserne-militaire', 'min_def', '1', 'Caserne militaire', 'Valeur par defaut arbitree le 8 octobre 2026. Le ministre peut la modifier.', '65', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_fin', 'assemblee', 'min_fin', '10', 'Assemblée nationale', NULL, '19', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-min_ae', 'min_fin', '8', 'Ministère des Affaires étrangères', NULL, '9', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-min_def', 'min_fin', '6', 'Ministère de la Défense', NULL, '9', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-min_fin', 'min_fin', '4', 'Ministère de l''Économie et des Finances', 'Part conservee par le repartiteur : journalisee, jamais transferee. C''est ce qui empeche la boucle.', '9', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-min_info', 'min_fin', '7', 'Ministère de l''Information', NULL, '9', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-min_int', 'min_fin', '3', 'Ministère de l''Intérieur', NULL, '9', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-min_just', 'min_fin', '5', 'Ministère de la Justice', NULL, '9', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_fin', 'gouvernement-pm', 'min_fin', '2', 'Premier ministre', NULL, '9', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_fin', 'palais-gouvernement', 'min_fin', '9', 'Palais du Gouvernement', 'Actions gouvernementales communes -- communication et autres depenses institutionnelles. DISTINCTE de la caisse du Premier ministre.', '9', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_fin', 'palais-presidentiel', 'min_fin', '1', 'Présidence', NULL, '9', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_int', 'douane', 'min_int', '1', 'Service des douanes', 'Valeur par defaut arbitree le 8 octobre 2026. Le ministre peut la modifier.', '35', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_int', 'qhs-prison', 'min_int', '2', 'Quartier de Haute Sécurité', 'ARBITRAGE DU 8 OCTOBRE 2026 : le QHS releve budgetairement de l''Interieur, pas de la Justice. Part a 0 % PAR DECISION -- beneficiaire reconnu, sans financement recurrent au demarrage. Le ministre peut la modifier, et le virement ponctuel en FR reste possible meme a 0 %.', '0', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_just', 'tribunal_capitale', 'min_just', '1', 'Tribunal de Luthécia', 'ARBITRAGE DU 7 OCTOBRE 2026 : repartition initiale EGALE entre les trois tribunaux territoriaux. UN TIERS EXACT, et non 33,33 % -- qui ne fait pas 100 a trois, ni 33,34 pour l''un d''eux -- qui creerait une preference permanente. Le ministre peut modifier librement cette repartition depuis son tableau de bord.', '1', '3');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_just', 'tribunal_ville_a', 'min_just', '2', 'Tribunal de Port-Sainte-Marie', 'ARBITRAGE DU 7 OCTOBRE 2026 : repartition initiale EGALE entre les trois tribunaux territoriaux. UN TIERS EXACT, et non 33,33 % -- qui ne fait pas 100 a trois, ni 33,34 pour l''un d''eux -- qui creerait une preference permanente. Le ministre peut modifier librement cette repartition depuis son tableau de bord.', '1', '3');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'gouvernement-min_just', 'tribunal_ville_b', 'min_just', '3', 'Tribunal de Montrouge', 'ARBITRAGE DU 7 OCTOBRE 2026 : repartition initiale EGALE entre les trois tribunaux territoriaux. UN TIERS EXACT, et non 33,33 % -- qui ne fait pas 100 a trois, ni 33,34 pour l''un d''eux -- qui creerait une preference permanente. Le ministre peut modifier librement cette repartition depuis son tableau de bord.', '1', '3');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'mairie_ville_a', 'commissariat_ville_a', 'maire', '1', 'Commissariat — Port-Sainte-Marie', 'ARBITRAGE DU 8 OCTOBRE 2026 : valeurs INITIALES de Republia, 40/40/20. Le maire modifie librement les trois parts, la sienne comprise ; la seule contrainte est une somme de 100 % exactement.', '40', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'mairie_ville_a', 'entrepot_ville_a', 'maire', '2', 'Entrepôt municipal — Port-Sainte-Marie', 'ARBITRAGE DU 8 OCTOBRE 2026 : valeurs INITIALES de Republia, 40/40/20. Le maire modifie librement les trois parts, la sienne comprise ; la seule contrainte est une somme de 100 % exactement.', '40', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'mairie_ville_a', 'mairie_ville_a', 'maire', '3', 'Caisse propre de la mairie — Port-Sainte-Marie', 'ARBITRAGE DU 8 OCTOBRE 2026 : valeurs INITIALES de Republia, 40/40/20. Le maire modifie librement les trois parts, la sienne comprise ; la seule contrainte est une somme de 100 % exactement.', '20', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'mairie_ville_a', 'subventions_ville_a', 'maire', '4', 'Subventions', 'ARBITRAGE DU 10 OCTOBRE 2026 : voir la ligne de Luthecia. Part a 0 % par defaut.', '0', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'mairie_ville_b', 'commissariat_ville_b', 'maire', '1', 'Commissariat — Montrouge', 'ARBITRAGE DU 8 OCTOBRE 2026 : valeurs INITIALES de Republia, 40/40/20. Le maire modifie librement les trois parts, la sienne comprise ; la seule contrainte est une somme de 100 % exactement.', '40', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'mairie_ville_b', 'entrepot_ville_b', 'maire', '2', 'Entrepôt municipal — Montrouge', 'ARBITRAGE DU 8 OCTOBRE 2026 : valeurs INITIALES de Republia, 40/40/20. Le maire modifie librement les trois parts, la sienne comprise ; la seule contrainte est une somme de 100 % exactement.', '40', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'mairie_ville_b', 'mairie_ville_b', 'maire', '3', 'Caisse propre de la mairie — Montrouge', 'ARBITRAGE DU 8 OCTOBRE 2026 : valeurs INITIALES de Republia, 40/40/20. Le maire modifie librement les trois parts, la sienne comprise ; la seule contrainte est une somme de 100 % exactement.', '20', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'mairie_ville_b', 'subventions_ville_b', 'maire', '4', 'Subventions', 'ARBITRAGE DU 10 OCTOBRE 2026 : voir la ligne de Luthecia. Part a 0 % par defaut.', '0', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'mairie-capitale', 'commissariat_capitale', 'maire', '1', 'Commissariat — Luthécia', 'ARBITRAGE DU 8 OCTOBRE 2026 : valeurs INITIALES de Republia, 40/40/20. Le maire modifie librement les trois parts, la sienne comprise ; la seule contrainte est une somme de 100 % exactement.', '40', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'mairie-capitale', 'entrepot_capitale', 'maire', '2', 'Entrepôt municipal — Luthécia', 'ARBITRAGE DU 8 OCTOBRE 2026 : valeurs INITIALES de Republia, 40/40/20. Le maire modifie librement les trois parts, la sienne comprise ; la seule contrainte est une somme de 100 % exactement.', '40', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'mairie-capitale', 'mairie-capitale', 'maire', '3', 'Caisse propre de la mairie — Luthécia', 'ARBITRAGE DU 8 OCTOBRE 2026 : valeurs INITIALES de Republia, 40/40/20. Le maire modifie librement les trois parts, la sienne comprise ; la seule contrainte est une somme de 100 % exactement.', '20', '100');
INSERT INTO public.repartitions_budgetaires (pays, source, beneficiaire, poste_autorite, rang, libelle, note, part_numerateur, part_denominateur) VALUES ('republic', 'mairie-capitale', 'subventions_capitale', 'maire', '4', 'Subventions', 'ARBITRAGE DU 10 OCTOBRE 2026 : la commune peut subventionner les organisations eligibles de son territoire. Part a 0 % PAR DEFAUT -- meme precedent que le QHS : la ligne existe et est editable, elle ne deplace rien tant que le maire ne l''a pas decidee. La caisse est CUMULATIVE et appartient a la commune, pas au maire.', '0', '100');
