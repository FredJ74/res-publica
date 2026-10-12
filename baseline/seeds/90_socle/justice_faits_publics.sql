-- SEED -- justice_faits_publics
-- ============================================================================
-- Table      : public.justice_faits_publics
-- Domaine    : justice
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 12
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- QUELS ACTES DE PROCEDURE SONT DES FAITS PUBLICS, et avec quelle PHRASE
-- EXACTE. Douze lignes, lues par le declencheur
-- dossiers_actes_publier_au_journal qui depose la chronique. Le PV
-- d'audition, la deposition d'un temoin, le depot de plainte et la
-- constitution de defense n'y sont PAS : ce qui s'y dit appartient au
-- dossier, pas au Journal. Le silence est le defaut -- un acte non declare
-- ne publie rien.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE : sans ces lignes, aucun fait judiciaire n'atteint le
-- Journal, et toute la chaine -- non-lieu, poursuites, jugement, relaxe,
-- appel -- redevient invisible au pays.
-- ============================================================================

INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES ('abandon_poursuites', 'justice_abandon_parquet', 'Le parquet a abandonne les poursuites contre %s', NULL);
INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES ('appel_ouvert', 'justice_appel', 'Appel a ete interjete dans l''affaire visant %s', NULL);
INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES ('audience_fixee', 'justice_audience_fixee', 'Le jour du proces de %s a ete fixe', NULL);
INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES ('audience_ouverte', 'justice_audience', 'Le proces de %s s''est ouvert', 'Le libelle est complete par la PRESENCE constatee du Procureur, et par rien d''autre. Un constat, jamais un reproche.');
INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES ('condamnation', 'justice_condamnation', '%s a ete condamne(e)', NULL);
INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES ('juge_arret_accepte', 'justice_arret', 'Le juge a accepte l''arret de la procedure visant %s', NULL);
INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES ('juge_poursuite_maintenue', 'justice_poursuite_maintenue', 'Le juge a decide de poursuivre %s malgre l''abandon du parquet', NULL);
INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES ('jugement_appel', 'justice_jugement_appel', 'La cour a rendu son jugement d''appel dans l''affaire visant %s', NULL);
INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES ('non_lieu', 'justice_non_lieu', 'Le parquet a prononce un non-lieu dans l''affaire visant %s', 'Le non-lieu ne dit rien de la veracite de la plainte ni de l''innocence de la personne visee -- la phrase non plus.');
INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES ('poursuites_engagees', 'justice_poursuites', 'Le parquet a engage des poursuites contre %s', NULL);
INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES ('relaxe', 'justice_relaxe', '%s a ete relaxe(e)', NULL);
INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES ('requalification', 'justice_requalification', 'Le juge a requalifie les faits reproches a %s', NULL);
