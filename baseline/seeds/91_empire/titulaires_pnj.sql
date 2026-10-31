-- SEED -- titulaires_pnj
-- ============================================================================
-- Table      : public.titulaires_pnj
-- Domaine    : postes et institutions
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_filtre (classification du chantier 2C)
-- Lignes     : 18
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 18 titulaires. DECISION GD ACQUISE : les postes institutionnels destines a
-- des PNJ sont occupes par ces PNJ dans un monde neuf. LE COMPTE EST RELEVE,
-- PAS DECIDE, et il bouge tout seul : aucune ligne de cette table n'a jamais
-- ete ecrite a la main. Les douze premieres viennent de la passe de minuit
-- du 14 septembre 2026, les deux juges de province de celle du 21, et le
-- commissaire de la capitale (Raoul Toufaud) et le directeur d'entrepot de
-- la capitale (Marcel Silo) de celle du 12 octobre a 01 h 59, qui a trouve
-- ces deux postes vacants. La dix-huitieme est la seule posee par une
-- migration : le Procureur de la Republique (20261012091457). Chaque fois
-- que la cascade nocturne pourvoit un poste de plus, ce seed grossit -- et
-- c'est pour cela que le compte est tenu ici et non suppose.
--
-- ARBITRAGE DE GAME DESIGN
-- Filtrer : ne garder que les lignes PNJ, jamais un titulaire PJ herite de
-- la beta.
--
-- COLONNES OMISES (defaut now()) : updated_at
-- La date de creation d'une ligne n'est pas du contenu authored : c'est le
-- jour ou le monde est ne. Omettre la colonne laisse le defaut jouer.
-- ============================================================================

-- SEED -- titulaires_pnj
-- ============================================================================
-- Table      : public.titulaires_pnj
-- Domaine    : postes et institutions
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_filtre (classification du chantier 2C)
-- Lignes     : 18
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 18 titulaires. DECISION GD ACQUISE : les postes institutionnels destines a
-- des PNJ sont occupes par ces PNJ dans un monde neuf. LE COMPTE EST RELEVE,
-- PAS DECIDE, et il bouge tout seul : aucune ligne de cette table n'a jamais
-- ete ecrite a la main. Les douze premieres viennent de la passe de minuit
-- du 14 septembre 2026, les deux juges de province de celle du 21, et le
-- commissaire de la capitale (Raoul Toufaud) et le directeur d'entrepot de
-- la capitale (Marcel Silo) de celle du 12 octobre a 01 h 59, qui a trouve
-- ces deux postes vacants. La dix-huitieme est la seule posee par une
-- migration : le Procureur de la Republique (20261012091457). Chaque fois
-- que la cascade nocturne pourvoit un poste de plus, ce seed grossit -- et
-- c'est pour cela que le compte est tenu ici et non suppose.
--
-- ARBITRAGE DE GAME DESIGN
-- Filtrer : ne garder que les lignes PNJ, jamais un titulaire PJ herite de
-- la beta.
--
-- COLONNES OMISES (defaut now()) : updated_at
-- La date de creation d'une ligne n'est pas du contenu authored : c'est le
-- jour ou le monde est ne. Omettre la colonne laisse le defaut jouer.
-- ============================================================================

INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_capitaine_port_national', 'republic', 'capitaine_port', NULL, 'Marcel Ancre (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_chef_douanes_national', 'republic', 'chef_douanes', NULL, 'Pascal Paguevite (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_commandant_national', 'republic', 'commandant', NULL, 'Commandant Tom Hawak');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_commissaire_capitale', 'republic', 'commissaire', 'capitale', 'Raoul Toufaud (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_directeur_entrepot_capitale', 'republic', 'directeur_entrepot', 'capitale', 'Marcel Silo (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_directeur_pharma_national', 'republic', 'directeur_pharma', NULL, 'Bernard Piluler (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_directeur_raffinerie_national', 'republic', 'directeur_raffinerie', NULL, 'Gustave Baril (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_directeur_tabac_alcools_national', 'republic', 'directeur_tabac_alcools', NULL, 'Fernand Cendrier (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_juge_capitale', 'republic', 'juge', 'capitale', 'Honoré Cozetoujours (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_juge_ville_a', 'republic', 'juge', 'ville_a', 'Mireille Sedlex (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_juge_ville_b', 'republic', 'juge', 'ville_b', 'Gérard Bretellewood (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_min_ae_national', 'republic', 'min_ae', NULL, 'Le Ministre des Affaires Étrangères (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_min_fin_national', 'republic', 'min_fin', NULL, 'Le Ministre des Finances (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_min_info_national', 'republic', 'min_info', NULL, 'Le Ministre de l''Information (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_min_int_national', 'republic', 'min_int', NULL, 'Le Ministre de l''Intérieur (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_min_just_national', 'republic', 'min_just', NULL, 'Le Ministre de la Justice (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_pm_national', 'republic', 'pm', NULL, 'Le Premier Ministre (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_procureur', 'republic', 'procureur', NULL, 'Procureur Saad');
