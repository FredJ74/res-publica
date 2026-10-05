-- SEED -- budget_national_champs_regles
-- ============================================================================
-- Table      : public.budget_national_champs_regles
-- Domaine    : finances publiques
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 20
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Champs du budget national et leur autorite.
-- ============================================================================

INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('coefficientsArmesAcquis', 'commandant', 'recherche_militaire', 'Resultat de la meme recherche : meme autorite que le champ qui la porte', NULL, NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('couvreFeu', 'min_int', 'gerer_couvre_feu', 'Instaurer un couvre-feu — requiresPost declare sur l''ordre', NULL, NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('effortGuerre', 'min_def', 'tableau_effort_guerre', 'Pilotage operationnel : curseur du ministre de la Defense', 'prioriteProductionMilitaire', '50');
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('effortGuerre', 'min_def', 'tableau_effort_guerre', 'Pilotage operationnel : curseur du ministre de la Defense', 'prioriteRavitaillement', '50');
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('effortGuerre', 'president', 'effort_national', 'Auteur de la cloture', 'terminePar', NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('effortGuerre', 'president', 'effort_national', 'Auteur du declenchement', 'par', NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('effortGuerre', 'president', 'effort_national', 'Cloture', 'finA', NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('effortGuerre', 'president', 'effort_national', 'Compteur de periodes : incremente par le renouvellement presidentiel', 'periodes', NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('effortGuerre', 'president', 'effort_national', 'Compteur de prolongations hors guerre : il porte la penalite d''IS', 'periodesPreventives', NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('effortGuerre', 'president', 'effort_national', 'Decision politique : ouvrir et clore l''Effort national', 'actif', NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('effortGuerre', 'president', 'effort_national', 'Echeance de la periode de 3 jours : repoussee par le renouvellement presidentiel', 'expireA', NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('effortGuerre', 'president', 'effort_national', 'Horodatage de la decision presidentielle', 'debutA', NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('effortGuerre', 'president', 'effort_national', 'Motif de cloture (decision / echeance)', 'motifFin', NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('mobilisationNationaleActive', 'min_def', 'mobilisation_nationale', 'Mobilisation nationale — requiresPost declare (pose par confirmerMobilisation, leve par doDemobiliser)', NULL, NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('preemption', 'min_fin', 'preempter_entreprise', 'Droit de preemption sur une entreprise — requiresPost declare', NULL, NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('rechercheMilitaire', 'commandant', 'recherche_militaire', 'Lancer une recherche sur l''armement — requiresPost declare', NULL, NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('regimeException', '(serveur)', NULL, 'Regime d''exception : aucun ecrivain client, seul le cron constate son expiration', NULL, NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('repartition', 'min_fin', 'pilotage_fiscal_budgetaire', 'Repartition du budget national entre les institutions — arbitrage GD du 20/09/2026, requiresPost declare sur l''ordre', NULL, NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('tauxNational', 'min_fin', 'pilotage_fiscal_budgetaire', 'Taux d''imposition national — arbitrage GD du 20/09/2026, requiresPost declare sur l''ordre', NULL, NULL);
INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note, sous_champ, valeur_ouverture) VALUES ('virementJournalierQHS', 'min_just', 'gestion_qhs', 'Gestion du QHS — requiresPost declare', NULL, NULL);
