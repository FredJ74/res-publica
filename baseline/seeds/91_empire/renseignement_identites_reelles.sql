-- SEED -- renseignement_identites_reelles
-- ============================================================================
-- Table      : public.renseignement_identites_reelles
-- Domaine    : renseignement
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 4
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 4 identites reelles d'agents. Contenu authored.
-- ============================================================================

INSERT INTO public.renseignement_identites_reelles (role, vrai_nom, dup, sexe) VALUES ('conseiller', 'Gladys Crête', '13', 'F');
INSERT INTO public.renseignement_identites_reelles (role, vrai_nom, dup, sexe) VALUES ('coordinateur', 'Yannick Helle', '13', 'H');
INSERT INTO public.renseignement_identites_reelles (role, vrai_nom, dup, sexe) VALUES ('garde', 'Boris Ketou', '13', 'H');
INSERT INTO public.renseignement_identites_reelles (role, vrai_nom, dup, sexe) VALUES ('traducteur', 'Raymond Hialiste', '13', 'H');
