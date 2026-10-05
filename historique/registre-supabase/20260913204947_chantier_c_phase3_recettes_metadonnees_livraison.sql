-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913204947
-- Nom original      : chantier_c_phase3_recettes_metadonnees_livraison
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 20:49:47 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 0fa135917ffffbde6d5b0ae3eafd056b
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
-- Le serveur doit pouvoir DECRIRE lui-meme ce qu'il vend : sans ces colonnes, le navigateur
-- resterait libre de se livrer autre chose que ce qu'il a paye. Genere, jamais saisi.
ALTER TABLE public.recettes_commerce
  ADD COLUMN IF NOT EXISTS effets jsonb,
  ADD COLUMN IF NOT EXISTS stack_key text,
  ADD COLUMN IF NOT EXISTS sous_type text,
  ADD COLUMN IF NOT EXISTS icone text,
  ADD COLUMN IF NOT EXISTS image text,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS famille_produit_marche text,
  ADD COLUMN IF NOT EXISTS bonus_integration_ville text;

UPDATE public.recettes_commerce r SET effets = v.effets, stack_key = v.stack_key,
  sous_type = v.sous_type, icone = v.icone, image = v.image, description = v.description,
  famille_produit_marche = v.fpm, bonus_integration_ville = v.biv
FROM (VALUES
  ('biere_pression', '{"moral": 2}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('boeuf_bourguignon', '{"hp": 8, "moral": 2}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('boisson_sans_alcool', '{"moral": 1}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('cafe_boisson', '{"moral": 2}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('carbonade_frites', '{"hp": 8, "moral": 3}'::jsonb, NULL, NULL, NULL, 'images/montrouge/montrouge-plat-carbonade.jpg', NULL, NULL, NULL),
  ('jus_de_fruits', '{"moral": 2}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('menu_gastronomique_1', '{"hp": 10, "moral": 1, "paDiffere": 3}'::jsonb, NULL, NULL, NULL, 'images/luthecia-restaurant-menu-1.jpg', NULL, NULL, NULL),
  ('menu_gastronomique_2', '{"hp": 10, "moral": 1, "paDiffere": 3}'::jsonb, NULL, NULL, NULL, 'images/luthecia-restaurant-menu-2.jpg', NULL, NULL, NULL),
  ('menu_gastronomique_3', '{"hp": 10, "moral": 1, "paDiffere": 3}'::jsonb, NULL, NULL, NULL, 'images/luthecia-restaurant-menu-3.jpg', NULL, NULL, NULL),
  ('menu_psm_1', '{"hp": 10, "moral": 1, "paDiffere": 3}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('menu_psm_2', '{"hp": 10, "moral": 1, "paDiffere": 3}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('menu_psm_3', '{"hp": 10, "moral": 1, "paDiffere": 3}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('petit_dejeuner', '{"hp": 3, "moral": 1}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('plat_de_poisson', '{"hp": 8, "moral": 2}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('sandwich', '{"hp": 5, "moral": 1, "paDiffere": 1}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('sandwich_cheminots', '{"hp": 5, "moral": 1}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('saucisse_puree', '{"hp": 8, "moral": 2}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('snack_buvette', '{"hp": 2, "moral": 1}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('vin', '{"moral": 2}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('carte_luthecia_culture', NULL, NULL, NULL, 'ti-mail', 'images/luthecia-carte-postale-culture.png', NULL, 'carte_postale', NULL),
  ('carte_luthecia_institutions', NULL, NULL, NULL, 'ti-mail', 'images/luthecia-carte-postale-institutions.png', NULL, 'carte_postale', NULL),
  ('carte_luthecia_internationale', NULL, NULL, NULL, 'ti-mail', 'images/luthecia-carte-postale-internationale.png', NULL, 'carte_postale', NULL),
  ('carte_montrouge_musee_rail', NULL, NULL, NULL, 'ti-mail', 'images/montrouge/montrouge-carte-postale-musee-rail.png', NULL, 'carte_postale', NULL),
  ('carte_montrouge_place_rail', NULL, NULL, NULL, 'ti-mail', 'images/montrouge/montrouge-carte-postale-place-rail.png', NULL, 'carte_postale', NULL),
  ('carte_montrouge_touristique', NULL, NULL, NULL, 'ti-mail', 'images/montrouge/montrouge-carte-postale-touristique.png', NULL, 'carte_postale', NULL),
  ('carte_psm_culture_marine', NULL, NULL, NULL, 'ti-mail', 'images/port-sainte-marie-carte-postale-culture-marine.png', NULL, 'carte_postale', NULL),
  ('carte_psm_notre_dame_mer', NULL, NULL, NULL, 'ti-mail', 'images/port-sainte-marie-carte-postale-notre-dame-mer.png', NULL, 'carte_postale', NULL),
  ('carte_psm_touristique', NULL, NULL, NULL, 'ti-mail', 'images/port-sainte-marie-carte-postale-touristique.png', NULL, 'carte_postale', NULL),
  ('casquette_montrouge', NULL, NULL, NULL, 'ti-shirt', 'images/montrouge/montrouge-marche-casquette.png', NULL, 'integration_locale', 'ville_b'),
  ('casse_croute_cheminot', NULL, NULL, NULL, 'ti-meat', 'images/montrouge/montrouge-marche-casse-croute.png', NULL, 'aliment', NULL),
  ('cornet_friture_psm', NULL, NULL, NULL, 'ti-fish', 'images/port-sainte-marie-marche-friture.png', NULL, 'aliment', NULL),
  ('croque_monsieur_luthecia', NULL, NULL, NULL, 'ti-meat', 'images/luthecia-marche-croque-monsieur.png', NULL, 'aliment', NULL),
  ('echarpe_luthecia', NULL, NULL, NULL, 'ti-shirt', 'images/luthecia-marche-echarpe.png', NULL, 'integration_locale', 'capitale'),
  ('figurine_maxence_monfils', NULL, NULL, NULL, 'ti-user', 'images/luthecia-souvenir-maxence-monfils.png', 'Figurine représentant Maxence Monfils enfant, avec une loupe et une sauterelle.', 'integration_locale', NULL),
  ('garde_republien_plomb', NULL, NULL, NULL, 'ti-chess-knight', 'images/luthecia-souvenir-garde-republien.png', 'Petite figurine de collection représentant un garde républien en uniforme.', 'integration_locale', NULL),
  ('porte_cle_palais_luthecia', NULL, NULL, NULL, 'ti-key', 'images/luthecia-souvenir-porte-cle-palais.png', 'Souvenir représentant le Palais présidentiel de Luthécia en miniature.', 'integration_locale', NULL),
  ('tshirt_psm', NULL, NULL, NULL, 'ti-shirt', 'images/port-sainte-marie-marche-tshirt.png', NULL, 'integration_locale', 'ville_a')
) AS v(id, effets, stack_key, sous_type, icone, image, description, fpm, biv)
WHERE r.id = v.id;
