-- SEED -- assemblee_catalogue_illegal
-- ============================================================================
-- Table      : public.assemblee_catalogue_illegal
-- Domaine    : assemblee
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 7
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 7 entrees du catalogue illegal.
-- ============================================================================

INSERT INTO public.assemblee_catalogue_illegal (circuit, ref, objet, libelle) VALUES ('armurerie_marche_noir', 'carabine_chasse', '{"type": "arme", "sousType": "carabine"}', 'Carabine de chasse');
INSERT INTO public.assemblee_catalogue_illegal (circuit, ref, objet, libelle) VALUES ('armurerie_marche_noir', 'couteau', '{"type": "arme", "sousType": "blanche"}', 'Couteau de poche');
INSERT INTO public.assemblee_catalogue_illegal (circuit, ref, objet, libelle) VALUES ('armurerie_marche_noir', 'revolver', '{"type": "arme", "sousType": "poing"}', 'Revolver .38');
INSERT INTO public.assemblee_catalogue_illegal (circuit, ref, objet, libelle) VALUES ('poison', 'ghb', '{"type": "poison"}', 'Poison');
INSERT INTO public.assemblee_catalogue_illegal (circuit, ref, objet, libelle) VALUES ('poison', 'parapluie', '{"type": "poison"}', 'Poison');
INSERT INTO public.assemblee_catalogue_illegal (circuit, ref, objet, libelle) VALUES ('poison', 'polonium', '{"type": "poison"}', 'Poison');
INSERT INTO public.assemblee_catalogue_illegal (circuit, ref, objet, libelle) VALUES ('poison', 'vipere', '{"type": "poison"}', 'Poison');
