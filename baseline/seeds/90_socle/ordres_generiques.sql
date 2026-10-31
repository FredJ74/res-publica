-- SEED -- ordres_generiques
-- ============================================================================
-- Table      : public.ordres_generiques
-- Domaine    : socle
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 5
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Référentiel serveur : contenu initial requis, extraction des lignes encore
-- nécessaire.
--
-- ARBITRAGE DE GAME DESIGN
-- Structure constatée dans les exports canoniques du 31/10/2026. Aucun
-- compte de lignes déduit du schéma. Compte SQL relevé en lecture seule par
-- ChatGPT, commit 2a71eaf77dac83370a02c4f12cd71b502a20d772, 31/10/2026 ; ne
-- prouve pas la possession des lignes ni leur actualité au prochain point de
-- coupe.
--
-- COLONNES OMISES (defaut now()) : maj_le
-- La date de creation d'une ligne n'est pas du contenu authored : c'est le
-- jour ou le monde est ne. Omettre la colonne laisse le defaut jouer.
-- ============================================================================

INSERT INTO public.ordres_generiques (fn, taux_reussite, toujours_reussi, effets, batiments, poste_requis) VALUES ('deliberer_loge', '100', 'true', '{"inf": 3}', '{loge-maconnique}', NULL);
INSERT INTO public.ordres_generiques (fn, taux_reussite, toujours_reussi, effets, batiments, poste_requis) VALUES ('fuite_info', '60', 'false', '{"inf": 5, "pop": 10}', '{palais-gouvernement}', '*');
INSERT INTO public.ordres_generiques (fn, taux_reussite, toujours_reussi, effets, batiments, poste_requis) VALUES ('interroger', '75', 'false', '{"inf": 5}', '{qhs-prison}', 'commissaire');
INSERT INTO public.ordres_generiques (fn, taux_reussite, toujours_reussi, effets, batiments, poste_requis) VALUES ('soins_discrets', '95', 'false', '{"hp": 30, "dis": -2}', '{clinique-privee}', NULL);
INSERT INTO public.ordres_generiques (fn, taux_reussite, toujours_reussi, effets, batiments, poste_requis) VALUES ('soins_urgence', '100', 'true', '{"hp": 40}', '{clinique-privee}', NULL);
