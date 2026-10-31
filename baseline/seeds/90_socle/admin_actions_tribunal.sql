-- SEED -- admin_actions_tribunal
-- ============================================================================
-- Table      : public.admin_actions_tribunal
-- Domaine    : divers et technique
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 10
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- LE MENU DES ACTIONS INCARNABLES, et rien de plus : dix lignes, deux postes
-- -- le parquet national et le juge de la capitale. La colonne `statuts` dit
-- ce que le panneau PROPOSE ; la garde qui TRANCHE reste dans la fonction
-- metier. Pour que le menu ne puisse pas MENTIR, `garde_texte` porte le
-- fragment exact attendu dans le corps de cette fonction, et une preuve de
-- migration le verifie : un bareme deplace cote metier fait echouer la
-- migration suivante au lieu de donner un menu faux.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE : sans ses lignes, admin_incarner refuse
-- `action_hors_perimetre` pour tout et le panneau n'affiche aucun bouton. Le
-- contenu EST le perimetre arbitre -- l'elargir est une decision de game
-- design, pas une migration technique.
-- ============================================================================

-- SEED -- admin_actions_tribunal
-- ============================================================================
-- Table      : public.admin_actions_tribunal
-- Domaine    : divers et technique
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 10
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- LE MENU DES ACTIONS INCARNABLES, et rien de plus : dix lignes, deux postes
-- -- le parquet national et le juge de la capitale. La colonne `statuts` dit
-- ce que le panneau PROPOSE
--
-- ARBITRAGE DE GAME DESIGN
-- la garde qui TRANCHE reste dans la fonction metier. Pour que le menu ne
-- puisse pas MENTIR, `garde_texte` porte le fragment exact attendu dans le
-- corps de cette fonction, et une preuve de migration le verifie : un bareme
-- deplace cote metier fait echouer la migration suivante au lieu de donner
-- un menu faux.
-- ============================================================================

INSERT INTO public.admin_actions_tribunal (poste, action, fonction, statuts, garde_texte, libelle, ordre) VALUES ('juge', 'juger_appel', 'justice_appel_juger', '{appel}', '<> ''appel''', 'Juger en appel', '4');
INSERT INTO public.admin_actions_tribunal (poste, action, fonction, statuts, garde_texte, libelle, ordre) VALUES ('juge', 'relaxer', 'justice_relaxer', '{saisie}', '<> ''saisie''', 'Relaxer', '1');
INSERT INTO public.admin_actions_tribunal (poste, action, fonction, statuts, garde_texte, libelle, ordre) VALUES ('juge', 'rendre_sentence', 'justice_rendre_sentence', '{saisie}', '<> ''saisie''', 'Rendre la sentence', '2');
INSERT INTO public.admin_actions_tribunal (poste, action, fonction, statuts, garde_texte, libelle, ordre) VALUES ('juge', 'suite_apres_abandon', 'juge_suite_apres_abandon', '{abandon_demande}', '<> ''abandon_demande''', 'Statuer sur l''abandon', '3');
INSERT INTO public.admin_actions_tribunal (poste, action, fonction, statuts, garde_texte, libelle, ordre) VALUES ('procureur', 'abandonner', 'parquet_abandonner', '{poursuites,saisie}', 'ARRAY[''poursuites'', ''saisie'']', 'Abandonner les poursuites', '5');
INSERT INTO public.admin_actions_tribunal (poste, action, fonction, statuts, garde_texte, libelle, ordre) VALUES ('procureur', 'appel_ouvrir', 'justice_appel_ouvrir', '{jugee,relaxe}', 'NOT IN (''jugee'', ''relaxe'')', 'Interjeter appel', '6');
INSERT INTO public.admin_actions_tribunal (poste, action, fonction, statuts, garde_texte, libelle, ordre) VALUES ('procureur', 'enqueter', 'parquet_enqueter', '{au_parquet}', 'ARRAY[''au_parquet'']', 'Diligenter une enquete', '1');
INSERT INTO public.admin_actions_tribunal (poste, action, fonction, statuts, garde_texte, libelle, ordre) VALUES ('procureur', 'non_lieu', 'parquet_non_lieu', '{au_parquet,enquete}', 'ARRAY[''au_parquet'', ''enquete'']', 'Prononcer un non-lieu', '3');
INSERT INTO public.admin_actions_tribunal (poste, action, fonction, statuts, garde_texte, libelle, ordre) VALUES ('procureur', 'poursuivre', 'parquet_poursuivre', '{au_parquet,enquete}', 'ARRAY[''au_parquet'', ''enquete'']', 'Engager les poursuites', '2');
INSERT INTO public.admin_actions_tribunal (poste, action, fonction, statuts, garde_texte, libelle, ordre) VALUES ('procureur', 'transmettre_juge', 'parquet_transmettre_juge', '{poursuites}', 'ARRAY[''poursuites'']', 'Saisir le juge', '4');
