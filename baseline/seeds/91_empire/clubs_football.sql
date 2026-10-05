-- SEED -- clubs_football
-- ============================================================================
-- Table      : public.clubs_football
-- Domaine    : sport
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 12
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 12 clubs, renseignes pour les 4 empires.
--
-- AVERTISSEMENT : CETTE TABLE EST UN MIROIR DE data.js
-- Un generateur existe deja : .scratch/generer_clubs_football.py. Les lignes
-- ci-dessous sont copiees depuis la base, conformement a la strategie
-- seed_complet du chantier 2C -- mais copier un miroir fige sa derive. Celui
-- des couts d'ordre avait derive de 24 lignes mortes et 19 ordres gratuits
-- non declares. A terme, ce fichier doit etre ecrit par son generateur
-- depuis data.js, et la table doit rejoindre 95_a-regenerer.
-- ============================================================================

INSERT INTO public.clubs_football (id, nom, pays, ville) VALUES ('al-baraka-fc', 'Oasis City FC', 'khalija', 'ville_a');
INSERT INTO public.clubs_football (id, nom, pays, ville) VALUES ('brise-mariannaise', 'La Brise Mariannaise', 'republic', 'ville_a');
INSERT INTO public.clubs_football (id, nom, pays, ville) VALUES ('cheminote-montrouge', 'Union Cheminote de Montrouge', 'republic', 'ville_b');
INSERT INTO public.clubs_football (id, nom, pays, ville) VALUES ('dynamo-novomirsk', 'Dynamo Novomirsk', 'soviet', 'capitale');
INSERT INTO public.clubs_football (id, nom, pays, ville) VALUES ('fronterizos-unidos', 'Atlético Puerto Negro', 'narco', 'ville_a');
INSERT INTO public.clubs_football (id, nom, pays, ville) VALUES ('jaguares-selva', 'Independiente de Villa Sangre', 'narco', 'ville_b');
INSERT INTO public.clubs_football (id, nom, pays, ville) VALUES ('kolkhoze-ouvrier', 'Étoile Rouge de Krasnov', 'soviet', 'ville_b');
INSERT INTO public.clubs_football (id, nom, pays, ville) VALUES ('nadi-al-madina', 'Shabab Al Madina', 'khalija', 'capitale');
INSERT INTO public.clubs_football (id, nom, pays, ville) VALUES ('olympique-luthecia', 'Olympique de Luthécia', 'republic', 'capitale');
INSERT INTO public.clubs_football (id, nom, pays, ville) VALUES ('rojos-cartel', 'Estudiantes de la Ciudad', 'narco', 'capitale');
INSERT INTO public.clubs_football (id, nom, pays, ville) VALUES ('sharq-al-nour', 'Al-Petrol United FC', 'khalija', 'ville_b');
INSERT INTO public.clubs_football (id, nom, pays, ville) VALUES ('spartak-sibirsk', 'Partizan de Starovka', 'soviet', 'ville_a');
