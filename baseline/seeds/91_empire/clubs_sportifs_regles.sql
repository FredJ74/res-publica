-- SEED -- clubs_sportifs_regles
-- ============================================================================
-- Table      : public.clubs_sportifs_regles
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
-- ARBITRAGE RENDU : les clubs partagent les memes regles, qui relevent donc
-- du socle -- or cette table NE CONTIENT AUCUNE REGLE. Ses colonnes sont
-- club_id, nom, country, city, valeur_base : c'est un doublon du referentiel
-- des clubs, donc du contenu d'empire.
--
-- ARBITRAGE DE GAME DESIGN
-- DUPLICATION CONSTATEE : les 12 lignes sont les 12 memes clubs que
-- clubs_football (12/12 en commun, memes identifiants, memes noms, memes
-- pays et villes). Seule `valeur_base` n'y figure pas en double. Le nommage
-- diverge en outre : pays/ville ici, country/city la-bas. A fusionner hors
-- 2C.
-- ============================================================================

INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES ('al-baraka-fc', 'Oasis City FC', 'khalija', 'ville_a', '56');
INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES ('brise-mariannaise', 'La Brise Mariannaise', 'republic', 'ville_a', '60');
INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES ('cheminote-montrouge', 'Union Cheminote de Montrouge', 'republic', 'ville_b', '63');
INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES ('dynamo-novomirsk', 'Dynamo Novomirsk', 'soviet', 'capitale', '74');
INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES ('fronterizos-unidos', 'Atlético Puerto Negro', 'narco', 'ville_a', '58');
INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES ('jaguares-selva', 'Independiente de Villa Sangre', 'narco', 'ville_b', '61');
INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES ('kolkhoze-ouvrier', 'Étoile Rouge de Krasnov', 'soviet', 'ville_b', '59');
INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES ('nadi-al-madina', 'Shabab Al Madina', 'khalija', 'capitale', '70');
INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES ('olympique-luthecia', 'Olympique de Luthécia', 'republic', 'capitale', '72');
INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES ('rojos-cartel', 'Estudiantes de la Ciudad', 'narco', 'capitale', '68');
INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES ('sharq-al-nour', 'Al-Petrol United FC', 'khalija', 'ville_b', '62');
INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES ('spartak-sibirsk', 'Partizan de Starovka', 'soviet', 'ville_a', '57');
