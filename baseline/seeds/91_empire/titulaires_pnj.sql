-- SEED -- titulaires_pnj
-- ============================================================================
-- Table      : public.titulaires_pnj
-- Domaine    : postes et institutions
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_filtre (classification du chantier 2C)
-- Lignes     : 15
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 16 titulaires. DECISION GD ACQUISE : les postes institutionnels destines a
-- des PNJ sont occupes par ces PNJ dans un monde neuf.
--
-- ARBITRAGE DE GAME DESIGN
-- Filtrer : ne garder que les lignes PNJ, jamais un titulaire PJ herite de
-- la beta.
--
-- FILTRE APPLIQUE
-- ARBITRAGE RENDU LE 5 OCTOBRE 2026 : chaque ville de Republia a son PROPRE
-- juge PNJ -- Juge Fontaine a Luthecia, Mireille Sedlex a Port-Sainte-Marie,
-- Gerard Bretellewood a Montrouge -- et il n'y a PAS de quatrieme juge
-- generique a city = NULL. La ligne republic_juge_national est un vestige de
-- l'ancien systeme, anterieur a la dimension ville : son identifiant dit
-- `national`, son horodatage est du 13 septembre quand les trois lignes de
-- ville sont toutes du 20 septembre a la meme seconde, et `juge` est le SEUL
-- poste de la table a porter une ville -- les quinze autres titulaires sont
-- tous a NULL. Elle n'entre donc pas dans l'etat initial canonique. ELLE
-- N'EST PAS SUPPRIMEE DE LA BASE DE PRODUCTION : seul le seed l'ecarte. Le
-- monde neuf naît avec 15 titulaires PNJ, dont 3 juges municipaux distincts.
--
-- COLONNES OMISES (defaut now()) : updated_at
-- La date de creation d'une ligne n'est pas du contenu authored : c'est le
-- jour ou le monde est ne. Omettre la colonne laisse le defaut jouer.
-- ============================================================================

INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_capitaine_port_national', 'republic', 'capitaine_port', NULL, 'Marcel Ancre (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_chef_douanes_national', 'republic', 'chef_douanes', NULL, 'Pascal Paguevite (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_commandant_national', 'republic', 'commandant', NULL, 'Commandant Tom Hawak');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_directeur_pharma_national', 'republic', 'directeur_pharma', NULL, 'Bernard Piluler (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_directeur_raffinerie_national', 'republic', 'directeur_raffinerie', NULL, 'Gustave Baril (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_directeur_tabac_alcools_national', 'republic', 'directeur_tabac_alcools', NULL, 'Fernand Cendrier (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_juge_capitale', 'republic', 'juge', 'capitale', 'Juge Fontaine');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_juge_ville_a', 'republic', 'juge', 'ville_a', 'Mireille Sedlex (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_juge_ville_b', 'republic', 'juge', 'ville_b', 'Gérard Bretellewood (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_min_ae_national', 'republic', 'min_ae', NULL, 'Le Ministre des Affaires Étrangères (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_min_fin_national', 'republic', 'min_fin', NULL, 'Le Ministre des Finances (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_min_info_national', 'republic', 'min_info', NULL, 'Le Ministre de l''Information (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_min_int_national', 'republic', 'min_int', NULL, 'Le Ministre de l''Intérieur (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_min_just_national', 'republic', 'min_just', NULL, 'Le Ministre de la Justice (PNJ)');
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES ('republic_pm_national', 'republic', 'pm', NULL, 'Le Premier Ministre (PNJ)');
