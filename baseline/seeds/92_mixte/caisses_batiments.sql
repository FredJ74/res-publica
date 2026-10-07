-- SEED -- caisses_batiments
-- ============================================================================
-- Table      : public.caisses_batiments
-- Domaine    : finances publiques
-- Categorie  : D (mixte)
-- Strategie  : seed_filtre (classification du chantier 2C)
-- Lignes     : 41
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- ARBITRAGE DU 5 OCTOBRE 2026 : les dotations financieres d'amorcage sont
-- decidees -- 130 000 FR repartis sur 38 caisses de Republia. Ces 38 lignes
-- sont donc seedees, avec leur montant ECRIT depuis le tableau d'arbitrage
-- et non copie de la bêta. Les 113 autres lignes ne sont pas reprises.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED ECRIT, PAS EXTRAIT. L'audit du circuit fiscal a etabli que 24 de ces
-- caisses ne doivent PAS etre dotees -- vestiges dates, comptes de transit,
-- contreparties, caisses inertes, ou caisses alimentees par une autre. Elles
-- sont nommees une par une dans le tableau d'arbitrage. Le journal
-- dotations_amorcage_caisses, lui, reste hors baseline : il dit ce qui a ete
-- verse, pas ce qui doit l'etre.
--
-- FILTRE APPLIQUE
-- SEED ECRIT, PAS EXTRAIT. Les 41 caisses dont la dotation est arbitree sont
-- ecrites avec leur montant decide ; les 110 autres lignes de la table ne
-- sont pas reprises -- soit elles appartiennent aux trois autres empires,
-- soit l'audit du circuit fiscal les a declarees vestiges, comptes de
-- transit, contreparties ou caisses inertes, soit ce sont des lignes de
-- test. Aucun solde de bêta ne traverse : la colonne `data` est reconstruite
-- depuis le tableau d'arbitrage.
--
-- COLONNE ECRITE PAR ARBITRAGE : data
-- ARBITRAGE DU 5 OCTOBRE 2026. Le solde de chaque caisse est ECRIT depuis le
-- tableau d'arbitrage, jamais copie de la bêta. Le `case` ci-dessous est
-- engendre depuis baseline/arbitrages/dotations-financieres-republia.csv,
-- seule source de verite des montants decides.
--
-- COLONNES OMISES (defaut now()) : updated_at
-- La date de creation d'une ligne n'est pas du contenu authored : c'est le
-- jour ou le monde est ne. Omettre la colonne laisse le defaut jouer.
-- ============================================================================

INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_agence-grobras-securite', '{"solde": 0}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_assemblee', '{"solde": 5000}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_caserne-militaire', '{"solde": 0}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_centre-multinodal-luthecia', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_centre-multinodal-montrouge', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_centre-multinodal-port-sainte-marie', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_commissariat_capitale', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_commissariat_ville_a', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_commissariat_ville_b', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_dispensaire_capitale', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_dispensaire_ville_a', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_dispensaire_ville_b', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_douane', '{"solde": 0}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_gouvernement-min_ae', '{"solde": 10000}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_gouvernement-min_def', '{"solde": 35000}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_gouvernement-min_fin', '{"solde": 10000}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_gouvernement-min_info', '{"solde": 10000}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_gouvernement-min_int', '{"solde": 10000}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_gouvernement-min_just', '{"solde": 10000}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_gouvernement-pm', '{"solde": 10000}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_hotel_capitale', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_hotel_ville_a', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_hotel_ville_b', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_mairie_ville_a', '{"solde": 5000}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_mairie_ville_b', '{"solde": 5000}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_mairie-capitale', '{"solde": 5000}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_marche_capitale', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_marche_ville_a', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_marche_ville_b', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_office-notarial', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_palais-gouvernement', '{"solde": 0}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_palais-presidentiel', '{"solde": 10000}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_port-sainte-marie', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_qhs-prison', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_reserve-nationale', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_stade_capitale', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_stade_ville_a', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_stade_ville_b', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_tribunal_capitale', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_tribunal_ville_a', '{"solde": 200}');
INSERT INTO public.caisses_batiments (id, data) VALUES ('republic_tribunal_ville_b', '{"solde": 200}');
