-- SEED -- entreprises_constantes
-- ============================================================================
-- Table      : public.entreprises_constantes
-- Domaine    : economie
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 20
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 20 constantes economiques pures (cout horaire, plafonds). Aucune fonction
-- ne l'ecrit.
--
-- AVERTISSEMENT : CETTE TABLE EST UN MIROIR DE data.js
-- Un generateur existe deja :
-- outils/generateurs/generer_miroirs_entreprises.py et
-- generer_miroirs_chantiers.py. Les lignes ci-dessous sont copiees depuis la
-- base, conformement a la strategie seed_complet du chantier 2C -- mais
-- copier un miroir fige sa derive. Celui des couts d'ordre avait derive de
-- 24 lignes mortes et 19 ordres gratuits non declares. A terme, ce fichier
-- doit etre ecrit par son generateur depuis data.js, et la table doit
-- rejoindre 95_a-regenerer.
-- ============================================================================

INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('acompte_compromis', '1000');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('bois_par_lot_tracts', '1');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('chantier_taux_horaire', '70');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('coef_prix_max_pj_republic', '4');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('cout_main_oeuvre_pa_alimentaire', '50');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('cycle_metal', '3');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('pa_par_lot_tracts', '1');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('pa_production_armurerie', '2');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('pa_tournee', '1');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('plafond_pret_compromis', '150000');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('prix_lot_tracts', '150');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('prix_rachat_armurerie', '130000');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('prix_rachat_imprimerie', '180000');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('references_max_base', '4');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('salaire_lot_tracts', '50');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('salaire_production_armurerie', '100');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('seuil_demarrage_pct', '35');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('stock_max_commerce', '20');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('stock_max_matiere_republic', '20');
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('types_commerce_max_base', '2');
