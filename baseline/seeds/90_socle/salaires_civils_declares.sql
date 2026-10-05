-- SEED -- salaires_civils_declares
-- ============================================================================
-- Table      : public.salaires_civils_declares
-- Domaine    : finances publiques
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 17
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Bareme des salaires civils.
-- ============================================================================

INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('commissaire', 'poste', '1000');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('default', 'universel', '150');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('depute', 'poste', '1200');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('docker_psm', 'emploi', '220');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('hotelier_montrouge', 'emploi', '250');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('juge', 'poste', '1800');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('maire', 'poste', '800');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('maire_adjoint', 'poste', '500');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('min_ae', 'poste', '2800');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('min_def', 'poste', '2800');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('min_fin', 'poste', '2800');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('min_info', 'poste', '2800');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('min_int', 'poste', '2800');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('min_just', 'poste', '2800');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('pm', 'poste', '3500');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('president', 'poste', '5000');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES ('serveur_luthecia', 'emploi', '200');
