-- SEED -- assemblee_sieges
-- ============================================================================
-- Table      : public.assemblee_sieges
-- Domaine    : assemblee
-- Categorie  : D (mixte)
-- Strategie  : seed_filtre (classification du chantier 2C)
-- Lignes     : 9
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 9 sieges. Le commentaire est explicite : la ligne porte l'identite
-- PERMANENTE du depute Gamma et n'est jamais videe. La presence d'un PJ est
-- derivee.
--
-- ARBITRAGE DE GAME DESIGN
-- Seeder les 9 deputes Gamma, jamais l'occupation PJ.
--
-- COLONNES REMISES A L'ETAT INITIAL : endormi, endormi_par, endormi_ts
-- Le commentaire de la table est explicite : la ligne porte l'identite
-- PERMANENTE du depute Gamma et n'est jamais videe. Seules endormi /
-- endormi_ts / endormi_par decrivent un etat vivant -- un PJ qui a
-- neutralise le Gamma. Les 3 seules fonctions qui ecrivent cette table
-- (assemblee_neutraliser_depute, assemblee_reveiller_depute,
-- assemblee_reveil_minuit) ne touchent que ces colonnes. Aucune fonction n'y
-- insere : les 9 lignes doivent donc preexister. Au premier jour, aucun
-- depute n'est endormi -- et c'est deja le cas en base aujourd'hui (0 ligne
-- endormie).
--
-- COLONNES OMISES (defaut now()) : updated_at
-- La date de creation d'une ligne n'est pas du contenu authored : c'est le
-- jour ou le monde est ne. Omettre la colonne laisse le defaut jouer.
-- ============================================================================

INSERT INTO public.assemblee_sieges (id, country, city, rang, pnj_id, pnj_nom, endormi, endormi_ts, endormi_par) VALUES ('republic:capitale:1', 'republic', 'capitale', '1', 'dep_vauclerc', 'Étienne Vauclerc', false, NULL, NULL);
INSERT INTO public.assemblee_sieges (id, country, city, rang, pnj_id, pnj_nom, endormi, endormi_ts, endormi_par) VALUES ('republic:capitale:2', 'republic', 'capitale', '2', 'dep_marechal', 'Sophie Maréchal', false, NULL, NULL);
INSERT INTO public.assemblee_sieges (id, country, city, rang, pnj_id, pnj_nom, endormi, endormi_ts, endormi_par) VALUES ('republic:capitale:3', 'republic', 'capitale', '3', 'dep_delorme', 'Benoît Delorme', false, NULL, NULL);
INSERT INTO public.assemblee_sieges (id, country, city, rang, pnj_id, pnj_nom, endormi, endormi_ts, endormi_par) VALUES ('republic:ville_a:1', 'republic', 'ville_a', '1', 'dep_legall', 'Yann Legall', false, NULL, NULL);
INSERT INTO public.assemblee_sieges (id, country, city, rang, pnj_id, pnj_nom, endormi, endormi_ts, endormi_par) VALUES ('republic:ville_a:2', 'republic', 'ville_a', '2', 'dep_leroux', 'Maëlle Leroux', false, NULL, NULL);
INSERT INTO public.assemblee_sieges (id, country, city, rang, pnj_id, pnj_nom, endormi, endormi_ts, endormi_par) VALUES ('republic:ville_a:3', 'republic', 'ville_a', '3', 'dep_kermeur', 'Loïc Kermeur', false, NULL, NULL);
INSERT INTO public.assemblee_sieges (id, country, city, rang, pnj_id, pnj_nom, endormi, endormi_ts, endormi_par) VALUES ('republic:ville_b:1', 'republic', 'ville_b', '1', 'dep_charron', 'Nathalie Charron', false, NULL, NULL);
INSERT INTO public.assemblee_sieges (id, country, city, rang, pnj_id, pnj_nom, endormi, endormi_ts, endormi_par) VALUES ('republic:ville_b:2', 'republic', 'ville_b', '2', 'dep_pichon', 'Gérard Pichon', false, NULL, NULL);
INSERT INTO public.assemblee_sieges (id, country, city, rang, pnj_id, pnj_nom, endormi, endormi_ts, endormi_par) VALUES ('republic:ville_b:3', 'republic', 'ville_b', '3', 'dep_vasseur', 'Élodie Vasseur', false, NULL, NULL);
