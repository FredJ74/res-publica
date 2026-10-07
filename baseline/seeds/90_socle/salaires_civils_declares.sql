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
-- Bareme des salaires civils. La colonne pays a ete ajoutee le 7 octobre
-- 2026 et la cle primaire est devenue (pays, cle) : la table n'avait aucune
-- dimension d'empire, et salaire_civil_percevoir y lisait sans filtre -- les
-- trois autres empires heritaient donc du bareme de Republia, revenu
-- universel compris. Les 17 lignes sont toutes en 'republic'.
-- ============================================================================

INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('commissaire', 'poste', '1000', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('default', 'universel', '150', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('depute', 'poste', '1200', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('docker_psm', 'emploi', '220', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('hotelier_montrouge', 'emploi', '250', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('juge', 'poste', '1800', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('maire', 'poste', '800', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('maire_adjoint', 'poste', '500', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('min_ae', 'poste', '2800', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('min_def', 'poste', '2800', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('min_fin', 'poste', '2800', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('min_info', 'poste', '2800', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('min_int', 'poste', '2800', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('min_just', 'poste', '2800', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('pm', 'poste', '3500', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('president', 'poste', '5000', 'republic');
INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('serveur_luthecia', 'emploi', '200', 'republic');
