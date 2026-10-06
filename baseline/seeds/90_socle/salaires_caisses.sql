-- SEED -- salaires_caisses
-- ============================================================================
-- Table      : public.salaires_caisses
-- Domaine    : finances publiques
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 13
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Quelle caisse paie quel poste. Le seed utilise un gabarit {pays}_batiment,
-- donc generique.
-- ============================================================================

INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES ('commissaire', '{pays}_commissariat_{ville}', 'true', 'commissariat de sa ville', NULL);
INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES ('depute', '{pays}_assemblee', 'false', 'Assemblee nationale', NULL);
INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES ('juge', '{pays}_tribunal_{ville}', 'true', 'tribunal de sa ville -- poste territorial, autorite nationale (min_just)', NULL);
INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES ('maire', '{pays}_mairie_{ville}', 'true', 'mairie de sa ville', NULL);
INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES ('maire_adjoint', '{pays}_mairie_{ville}', 'true', 'mairie de sa ville', NULL);
INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES ('min_ae', '{pays}_gouvernement-min_ae', 'false', 'ministere', NULL);
INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES ('min_def', '{pays}_gouvernement-min_def', 'false', 'ministere', NULL);
INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES ('min_fin', '{pays}_gouvernement-min_fin', 'false', 'ministere', NULL);
INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES ('min_info', '{pays}_gouvernement-min_info', 'false', 'ministere', NULL);
INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES ('min_int', '{pays}_gouvernement-min_int', 'false', 'ministere', NULL);
INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES ('min_just', '{pays}_gouvernement-min_just', 'false', 'ministere', NULL);
INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES ('pm', '{pays}_gouvernement-pm', 'false', 'Palais du Gouvernement — enveloppe du PM', NULL);
INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES ('president', '{pays}_palais-presidentiel', 'false', 'Palais presidentiel', NULL);
