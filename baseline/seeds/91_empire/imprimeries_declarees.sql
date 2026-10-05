-- SEED -- imprimeries_declarees
-- ============================================================================
-- Table      : public.imprimeries_declarees
-- Domaine    : economie
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 3
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 3 imprimeries de Republia, pays=republic.
-- ============================================================================

INSERT INTO public.imprimeries_declarees (pays, ville, batiment) VALUES ('republic', 'capitale', 'la-tribune');
INSERT INTO public.imprimeries_declarees (pays, ville, batiment) VALUES ('republic', 'ville_a', 'imprimerie-librairie');
INSERT INTO public.imprimeries_declarees (pays, ville, batiment) VALUES ('republic', 'ville_b', 'la-tribune');
