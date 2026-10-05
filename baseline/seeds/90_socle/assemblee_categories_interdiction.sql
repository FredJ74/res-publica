-- SEED -- assemblee_categories_interdiction
-- ============================================================================
-- Table      : public.assemblee_categories_interdiction
-- Domaine    : assemblee
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 21
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 21 categories d'interdiction legislative.
-- ============================================================================

INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('alcools', 'Alcools', '{alcool}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('armes', 'Armes (large)', '{}', '{arme}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('armes_a_feu', 'Armes à feu', '{}', '{arme}', '{poing,carabine}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('armes_blanches', 'Armes blanches', '{}', '{arme}', '{blanche}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('bois_et_forets', 'Bois', '{bois}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('carburants', 'Carburants', '{carburant,petrole}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('cereales', 'Céréales', '{cereales}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('denrees_animales', 'Denrées animales (large)', '{viande,poisson}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('desinfectant', 'Désinfectant', '{desinfectant}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('fruits_legumes', 'Fruits et légumes', '{fruits_legumes}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('hydrocarbures', 'Hydrocarbures (large)', '{carburant,petrole,charbon}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('medicaments', 'Médicaments', '{medicaments}', '{medicament}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('metal', 'Métal', '{metal}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('minerai', 'Minerai', '{minerai}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('plantes', 'Plantes', '{plantes}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('poisons', 'Poisons', '{}', '{poison}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('poissons', 'Poissons', '{poisson}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('produits_exotiques', 'Produits exotiques', '{produits_exotiques}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('tabac', 'Tabac', '{tabac}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('textile', 'Textile', '{textile}', '{}', '{}');
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES ('viandes', 'Viandes', '{viande}', '{}', '{}');
