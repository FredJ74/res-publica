-- SEED -- dossiers_judiciaires_actes_types
-- ============================================================================
-- Table      : public.dossiers_judiciaires_actes_types
-- Domaine    : justice
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 31
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- LISTE BLANCHE des actes qu'une chronologie judiciaire peut porter, avec
-- QUI les pose (plaignant, police, parquet, juge, serveur). TABLE ET NON
-- CONTRAINTE CHECK, et c'est le point : les couches futures -- temoignages,
-- audience, appel, execution de peine -- s'y ajoutent par une LIGNE au lieu
-- d'une migration de contrainte. Registre d'autorite du meme genre que
-- actes_nocturnes_mecanismes : aucune fonction ne l'ecrit, chaque entree est
-- une migration. `dossier_acte_consigner` LEVE sur un type absent -- le
-- refus propre qu'elle rendait avant etait jete par ses onze appelants, tous
-- en PERFORM, et creusait un trou silencieux dans la chronologie. TRENTE
-- types au 12 octobre 2026 -- les trois derniers sont l'appel interjete, le
-- jugement d'appel et l'indemnisation pour detention executee a tort. SEIZE
-- types : les treize du parquet, plus le PV d'audition, l'abandon des
-- charges pour delai expire et la defense en procedure simplifiee --
-- l'ACCUSE est devenu un auteur d'acte ce jour-la, et le CHECK de `pose_par`
-- a du s'ouvrir pour l'accueillir. Compte RELEVE EN BASE.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE, et pas par confort : sans ses lignes, chaque acte de
-- la chaine judiciaire fait LEVER la transaction qui le pose -- donc plus
-- aucune plainte, aucun non-lieu, aucun jugement. Le contenu du registre
-- fait partie du socle d'un monde neuf.
-- ============================================================================

-- SEED -- dossiers_judiciaires_actes_types
-- ============================================================================
-- Table      : public.dossiers_judiciaires_actes_types
-- Domaine    : justice
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 31
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- LISTE BLANCHE des actes qu'une chronologie judiciaire peut porter, avec
-- QUI les pose (plaignant, police, parquet, juge, serveur). TABLE ET NON
-- CONTRAINTE CHECK, et c'est le point : les couches futures -- temoignages,
-- audience, appel, execution de peine -- s'y ajoutent par une LIGNE au lieu
-- d'une migration de contrainte. Registre d'autorite du meme genre que
-- actes_nocturnes_mecanismes : aucune fonction ne l'ecrit, chaque entree est
-- une migration. `dossier_acte_consigner` LEVE sur un type absent -- le
-- refus propre qu'elle rendait avant etait jete par ses onze appelants, tous
-- en PERFORM, et creusait un trou silencieux dans la chronologie. TRENTE
-- types au 12 octobre 2026 -- les trois derniers sont l'appel interjete, le
-- jugement d'appel et l'indemnisation pour detention executee a tort. SEIZE
-- types : les treize du parquet, plus le PV d'audition, l'abandon des
-- charges pour delai expire et la defense en procedure simplifiee --
-- l'ACCUSE est devenu un auteur d'acte ce jour-la, et le CHECK de `pose_par`
-- a du s'ouvrir pour l'accueillir. Compte RELEVE EN BASE.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE, et pas par confort : sans ses lignes, chaque acte de
-- la chaine judiciaire fait LEVER la transaction qui le pose -- donc plus
-- aucune plainte, aucun non-lieu, aucun jugement. Le contenu du registre
-- fait partie du socle d'un monde neuf.
-- ============================================================================

INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('abandon_poursuites', 'Abandon des poursuites par le parquet', 'parquet', NULL);
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('affaire_transmise_police', 'Affaire transmise par la police', 'police', 'Un acte illegal decouvert et transmis au parquet par l''autorite judiciaire de la ville.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('appel_ouvert', 'Appel interjete', 'accuse', 'Le condamne ou le Procureur a interjete appel dans la fenetre de deux jours. Un seul appel par affaire : le premier qui le declenche l''ouvre. L''acte nomme QUI l''a declenche, et rien de plus -- ni motif, ni qualite de la demande.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('audience_consentement', 'Consentement du prevenu a une audience anticipee', 'accuse', 'Le prevenu accepte EXPLICITEMENT d''etre juge avant le delai de trois jours, sur un jour precis. Aucun consentement n''est jamais deduit d''un silence.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('audience_consentement_retire', 'Consentement a une audience anticipee retire', 'accuse', 'Le prevenu retire son consentement. Possible tant que l''audience n''est pas ouverte.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('audience_fixee', 'Jour d''audience fixe', 'juge', 'Le juge fixe le jour du proces. Au minimum trois jours apres, sauf consentement explicite du prevenu sur ce jour-la.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('audience_ouverte', 'Audience ouverte', 'juge', 'Le jour fixe est venu et le juge est dans sa salle d''audience. L''acte CONSTATE qui etait present -- le prevenu, le procureur -- et rien de plus : aucune absence n''emporte de consequence mecanique.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('charges_abandonnees_delai', 'Charges abandonnees -- delai de jugement expire', 'serveur', 'Le delai de jugement de premiere instance a expire sans jugement. Ce n''est ni une relaxe ni un non-lieu : c''est la cloture d''une procedure qui n''a pas abouti dans le temps imparti.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('condamnation', 'Condamnation prononcee', 'juge', 'Porte la qualification finale et la peine validee par le bareme serveur.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('defense_constituee', 'Defense constituee -- avocat retenu', 'avocat', 'Pose par l''avocat qui accepte la defense.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('defense_rompue', 'Defense rompue -- revocation ou abandon', 'avocat', 'Pose par celui qui rompt : l''avocat qui abandonne, ou le prevenu qui revoque. L''acte lui-meme porte son auteur reel dans `acteur` et `acteur_poste`.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('defense_simplifiee', 'Defense plaidee (procedure simplifiee)', 'accuse', 'La personne mise en cause a plaide sa defense sur une affaire dont la peine de reference est courte. L''acte consigne le FAIT et son issue ; il ne juge ni la sincerite ni la qualite de la plaidoirie. Une seule fois par affaire : la procedure simplifiee est definitive.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('enquete_acte_police', 'Acte d''enquete accompli par la police', 'police', 'Le parquet ordonne, la police accomplit. L''acte lui-meme reste celui qui existait.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('enquete_diligentee', 'Enquete diligentee par le parquet', 'parquet', NULL);
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('indemnisation', 'Indemnisation pour detention executee a tort', 'serveur', 'Des jours de prison ont ete purges au-dela de la peine devenue definitive. L''acte consigne le NOMBRE de jours indus et le montant du. Ce n''est pas un jugement de valeur sur la premiere decision : c''est une difference arithmetique entre ce qui a ete execute et ce qui etait du.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('juge_arret_accepte', 'Le juge accepte l''arret de la procedure', 'juge', 'Suite a un abandon du parquet apres saisine.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('juge_enquete_ouverte', 'Le juge ouvre une enquete malgre le non-lieu du parquet', 'juge', 'Pose par le juge de la ville de l''affaire sur un dossier que le parquet a clos par un non-lieu. Fait DISTINCT du non-lieu : les deux coexistent dans la chronologie. Il ouvre une enquete et rien de plus -- il ne poursuit pas, ne qualifie pas et ne se saisit pas.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('juge_poursuite_maintenue', 'Le juge poursuit malgre l''abandon du parquet', 'juge', 'Suite a un abandon du parquet apres saisine. Fait DISTINCT de l''abandon : les deux coexistent dans la chronologie.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('juge_saisi', 'Juge saisi', 'parquet', NULL);
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('jugement_appel', 'Jugement d''appel', 'juge', 'Le second examen, par le MEME juge, et il est DEFINITIF. Il peut confirmer, alleger, aggraver, relaxer ou requalifier dans les memes bornes que la premiere instance. Le premier jugement reste au registre.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('non_lieu', 'Non-lieu prononce par le parquet', 'parquet', 'Le parquet decide de ne pas poursuivre. Ne dit rien de la veracite de la plainte ni de l''innocence de la personne visee.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('plainte_deposee', 'Plainte deposee', 'plaignant', 'La declaration d''un joueur. Le texte libre du plaignant est conserve sur le DOSSIER, pas recopie dans chaque acte.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('poursuites_engagees', 'Poursuites engagees par le parquet', 'parquet', 'Porte la qualification canonique retenue par le parquet.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('pv_audition', 'Proces-verbal d''audition', 'accuse', 'La declaration de la personne mise en cause, ou son refus explicite de repondre. Le refus est une reponse procedurale valide : il n''est ni un aveu, ni une faute, et n''emporte aucun malus. Le texte est consigne VERBATIM et n''est lu par aucune IA.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('relaxe', 'Relaxe prononcee', 'juge', 'Un verdict, pas une absence de peine.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('requalification', 'Requalification des faits par le juge', 'juge', 'Porte la qualification AVANT et APRES. Elle n''efface pas celle du parquet : les deux coexistent, et c''est la raison d''etre des colonnes qualif_avant / qualif_apres.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('temoin_citation_eteinte', 'Citation de temoin eteinte -- affaire close', 'serveur', 'Posee a la cloture definitive de l''affaire.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('temoin_cite', 'Temoin cite a comparaitre', 'juge', 'Pose par l''autorite qui cite : avocat, parquet, juge, ou plaignant au moment du depot. L''acte porte sa qualite reelle dans `acteur_poste`.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('temoin_convocation_renouvelee', 'Seconde convocation d''un temoin', 'serveur', 'Posee par la passe de minuit a l''echeance de la premiere convocation.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('temoin_deposition', 'Deposition de temoin', 'temoin', 'La deposition ou le refus de temoigner, consignes verbatim. Aucune interpretation.');
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES ('temoin_recherche', 'Temoin recherche -- non-presentation', 'serveur', 'Posee par la passe de minuit a l''echeance de la seconde convocation. Seule consequence automatique de l''absence.');
