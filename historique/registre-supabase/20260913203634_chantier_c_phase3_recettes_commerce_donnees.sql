-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913203634
-- Nom original      : chantier_c_phase3_recettes_commerce_donnees
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 20:36:34 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : aa7f50975126a0de72f3a31618491726
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
DELETE FROM public.recettes_commerce;
INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, prix_fixe, categorie, types_autorises, pays_autorises, villes_autorisees, buildings_autorises) VALUES
  ('biere_pression', 'alimentaire', 'Bière', 1, 15, '{"cereales": 1}'::jsonb, NULL, 'boisson', '["buvette", "bar", "cafe", "brasserie"]'::jsonb, NULL, NULL, NULL),
  ('boeuf_bourguignon', 'alimentaire', 'Bœuf bourguignon — plat du jour', 1, 5, '{"cereales": 1, "viande": 1}'::jsonb, NULL, 'plat', '["cafe", "brasserie"]'::jsonb, NULL, NULL, NULL),
  ('boisson_sans_alcool', 'alimentaire', 'Boisson sans alcool', 1, 10, '{}'::jsonb, NULL, 'boisson', '["buvette", "bar", "cafe"]'::jsonb, NULL, NULL, NULL),
  ('cafe_boisson', 'alimentaire', 'Café', 1, 15, '{"produits_exotiques": 1}'::jsonb, NULL, 'boisson', '["cafe", "bar", "brasserie"]'::jsonb, NULL, NULL, NULL),
  ('carbonade_frites', 'alimentaire', 'Carbonade-frites', 1, 5, '{"cereales": 1, "viande": 1}'::jsonb, NULL, 'plat', '["brasserie"]'::jsonb, NULL, '["ville_b"]'::jsonb, NULL),
  ('jus_de_fruits', 'alimentaire', 'Jus de fruits', 1, 15, '{"fruits_legumes": 1}'::jsonb, NULL, 'boisson', '["cafe"]'::jsonb, NULL, NULL, NULL),
  ('menu_gastronomique_1', 'alimentaire', 'Menu 1 — Carpaccio de Saint-Jacques aux agrumes, Pavé de cerf sauce aux airelles, Omelette norvégienne', 1, 5, '{"cereales": 1, "poisson": 1, "viande": 1}'::jsonb, NULL, 'menu', '["brasserie"]'::jsonb, '["republic"]'::jsonb, '["capitale"]'::jsonb, '["hotel-republica"]'::jsonb),
  ('menu_gastronomique_2', 'alimentaire', 'Menu 2 — Huîtres gratinées au four (origine Port-Sainte-Marie), Turbot sauce hollandaise, Soufflé au Grand Marnier', 1, 5, '{"cereales": 1, "poisson": 2}'::jsonb, NULL, 'menu', '["brasserie"]'::jsonb, '["republic"]'::jsonb, '["capitale"]'::jsonb, '["hotel-republica"]'::jsonb),
  ('menu_gastronomique_3', 'alimentaire', 'Menu 3 — Foie gras et sa gelée de gewurztraminer, Chapon sauce aux morilles, Pavlova aux fruits rouges', 1, 5, '{"fruits_legumes": 1, "viande": 2}'::jsonb, NULL, 'menu', '["brasserie"]'::jsonb, '["republic"]'::jsonb, '["capitale"]'::jsonb, '["hotel-republica"]'::jsonb),
  ('menu_psm_1', 'alimentaire', 'Menu 1 — Salade verte à l''ail et aux noix, Poulpe à la mariannaise, Riz au lait à la cannelle', 1, 6, '{"cereales": 1, "fruits_legumes": 1, "poisson": 1}'::jsonb, NULL, 'menu', '["brasserie"]'::jsonb, '["republic"]'::jsonb, '["ville_a"]'::jsonb, '["capitaine-sauvage"]'::jsonb),
  ('menu_psm_2', 'alimentaire', 'Menu 2 — Salade de chou rouge et pomme verte, Magret de canard colvert, Île flottante', 1, 6, '{"cereales": 1, "fruits_legumes": 1, "viande": 1}'::jsonb, NULL, 'menu', '["brasserie"]'::jsonb, '["republic"]'::jsonb, '["ville_a"]'::jsonb, '["capitaine-sauvage"]'::jsonb),
  ('menu_psm_3', 'alimentaire', 'Menu 3 — Huîtres de PSM, Tourte au crabe, Crème brûlée au Grand Marnier', 1, 6, '{"cereales": 1, "poisson": 2}'::jsonb, NULL, 'menu', '["brasserie"]'::jsonb, '["republic"]'::jsonb, '["ville_a"]'::jsonb, '["capitaine-sauvage"]'::jsonb),
  ('petit_dejeuner', 'alimentaire', 'Petit-déjeuner', 1, 10, '{"cereales": 1}'::jsonb, NULL, 'petit_dej', '["cafe"]'::jsonb, NULL, NULL, NULL),
  ('plat_de_poisson', 'alimentaire', 'Plat de poisson', 1, 5, '{"cereales": 1, "poisson": 1}'::jsonb, NULL, 'plat', '["brasserie"]'::jsonb, NULL, NULL, NULL),
  ('sandwich', 'alimentaire', 'Sandwich', 1, 8, '{"cereales": 1, "fruits_legumes": 1, "viande": 1}'::jsonb, NULL, 'plat', '["marche"]'::jsonb, NULL, '["capitale"]'::jsonb, NULL),
  ('sandwich_cheminots', 'alimentaire', 'Sandwich jambon-beurre-cornichon', 1, 5, '{"cereales": 1, "viande": 1}'::jsonb, NULL, 'plat', '["cafe"]'::jsonb, NULL, NULL, '["cafe-tabac-cheminots-montrouge"]'::jsonb),
  ('saucisse_puree', 'alimentaire', 'Saucisse-purée', 1, 5, '{"cereales": 1, "viande": 1}'::jsonb, NULL, 'plat', '["brasserie"]'::jsonb, NULL, NULL, NULL),
  ('snack_buvette', 'alimentaire', 'Cacahuètes salées', 1, 15, '{"cereales": 1}'::jsonb, NULL, 'snack', '["buvette", "bar", "brasserie"]'::jsonb, NULL, NULL, NULL),
  ('vin', 'alimentaire', 'Vin', 1, 15, '{"fruits_legumes": 1}'::jsonb, NULL, 'boisson', '["cafe", "brasserie", "bar"]'::jsonb, NULL, NULL, NULL),
  ('carte_luthecia_culture', 'marche', 'Carte postale — Musées et Jardin botanique', 1, 16, '{"bois": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["capitale"]'::jsonb, '["marche"]'::jsonb),
  ('carte_luthecia_institutions', 'marche', 'Carte postale — Institutions de Luthécia', 1, 16, '{"bois": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["capitale"]'::jsonb, '["marche"]'::jsonb),
  ('carte_luthecia_internationale', 'marche', 'Carte postale — Luthécia, ville internationale', 1, 16, '{"bois": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["capitale"]'::jsonb, '["marche"]'::jsonb),
  ('carte_montrouge_musee_rail', 'marche', 'Carte postale — Musée du Rail', 1, 16, '{"bois": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["ville_b"]'::jsonb, '["marche"]'::jsonb),
  ('carte_montrouge_place_rail', 'marche', 'Carte postale — Place du Rail', 1, 16, '{"bois": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["ville_b"]'::jsonb, '["marche"]'::jsonb),
  ('carte_montrouge_touristique', 'marche', 'Carte postale — Souvenir de Montrouge', 1, 16, '{"bois": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["ville_b"]'::jsonb, '["marche"]'::jsonb),
  ('carte_psm_culture_marine', 'marche', 'Carte postale — Traditions de la Marine', 1, 16, '{"bois": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["ville_a"]'::jsonb, '["marche-psm"]'::jsonb),
  ('carte_psm_notre_dame_mer', 'marche', 'Carte postale — Notre-Dame de la Mer', 1, 16, '{"bois": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["ville_a"]'::jsonb, '["marche-psm"]'::jsonb),
  ('carte_psm_touristique', 'marche', 'Carte postale — Souvenir de Port-Sainte-Marie', 1, 16, '{"bois": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["ville_a"]'::jsonb, '["marche-psm"]'::jsonb),
  ('casquette_montrouge', 'marche', 'Casquette de cheminot', 1, 6, '{"textile": 2}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["ville_b"]'::jsonb, '["marche"]'::jsonb),
  ('casse_croute_cheminot', 'marche', 'Casse-croûte du Cheminot', 1, 8, '{"cereales": 1, "viande": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["ville_b"]'::jsonb, '["marche"]'::jsonb),
  ('cornet_friture_psm', 'marche', 'Cornet de friture de poissons', 1, 8, '{"cereales": 1, "poisson": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["ville_a"]'::jsonb, '["marche-psm"]'::jsonb),
  ('croque_monsieur_luthecia', 'marche', 'Croque-Monsieur du Marché', 1, 8, '{"cereales": 1, "fruits_legumes": 1, "viande": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["capitale"]'::jsonb, '["marche"]'::jsonb),
  ('echarpe_luthecia', 'marche', 'Écharpe en soie', 1, 6, '{"produits_exotiques": 1, "textile": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["capitale"]'::jsonb, '["marche"]'::jsonb),
  ('figurine_maxence_monfils', 'marche', 'Figurine de Maxence Monfils', 1, 6, '{"metal": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["capitale"]'::jsonb, '["marche"]'::jsonb),
  ('garde_republien_plomb', 'marche', 'Garde républien en plomb', 1, 6, '{"metal": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["capitale"]'::jsonb, '["marche"]'::jsonb),
  ('porte_cle_palais_luthecia', 'marche', 'Porte-clé du Palais présidentiel', 1, 6, '{"metal": 1}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["capitale"]'::jsonb, '["marche"]'::jsonb),
  ('tshirt_psm', 'marche', 'T-shirt de Port-Sainte-Marie', 1, 6, '{"textile": 2}'::jsonb, NULL, 'objet', '["marche"]'::jsonb, '["republic"]'::jsonb, '["ville_a"]'::jsonb, '["marche-psm"]'::jsonb);
