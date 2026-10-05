-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913203248
-- Nom original      : chantier_c_phase3_miroirs_entreprises_donnees
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 20:32:48 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 7db8dbd338e94fc30b573c121ec37633
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
DELETE FROM public.recettes_production;
INSERT INTO public.recettes_production (id, ut, label, pays, materiaux) VALUES
  ('ak47', 3, 'AK-47', 'narco', '{"bois": 1, "metal": 3}'::jsonb),
  ('baionnette', 1, 'Baïonnette', 'soviet', '{"metal": 1}'::jsonb),
  ('carabine_chasse', 3, 'Carabine de chasse', 'republic', '{"bois": 2, "metal": 2}'::jsonb),
  ('carabine_precision', 3, 'Carabine de précision', 'khalija', '{"bois": 2, "metal": 2}'::jsonb),
  ('couteau', 1, 'Couteau de poche', 'republic', '{"metal": 1}'::jsonb),
  ('desert_eagle', 2, 'Desert Eagle', 'narco', '{"metal": 2}'::jsonb),
  ('jambiya', 1, 'Jambiya', 'khalija', '{"metal": 1}'::jsonb),
  ('kalachnikov', 3, 'Kalachnikov', 'soviet', '{"bois": 1, "metal": 3}'::jsonb),
  ('machette', 1, 'Machette', 'narco', '{"metal": 1}'::jsonb),
  ('makarov', 2, 'Makarov', 'soviet', '{"metal": 2}'::jsonb),
  ('pistolet_dore', 2, 'Pistolet doré', 'khalija', '{"metal": 2}'::jsonb),
  ('revolver', 2, 'Revolver', 'republic', '{"bois": 1, "metal": 2}'::jsonb);

DELETE FROM public.recettes_alimentaires;
INSERT INTO public.recettes_alimentaires (id, label, pa, portions, materiaux, prix_fixe, type_objet) VALUES
  ('biere_pression', 'Bière', 1, 15, '{"cereales": 1}'::jsonb, NULL, NULL),
  ('boeuf_bourguignon', 'Bœuf bourguignon — plat du jour', 1, 5, '{"cereales": 1, "viande": 1}'::jsonb, NULL, NULL),
  ('boisson_sans_alcool', 'Boisson sans alcool', 1, 10, '{}'::jsonb, NULL, NULL),
  ('cafe_boisson', 'Café', 1, 15, '{"produits_exotiques": 1}'::jsonb, NULL, NULL),
  ('carbonade_frites', 'Carbonade-frites', 1, 5, '{"cereales": 1, "viande": 1}'::jsonb, NULL, NULL),
  ('jus_de_fruits', 'Jus de fruits', 1, 15, '{"fruits_legumes": 1}'::jsonb, NULL, NULL),
  ('menu_gastronomique_1', 'Menu 1 — Carpaccio de Saint-Jacques aux agrumes, Pavé de cerf sauce aux airelles, Omelette norvégienne', 1, 5, '{"cereales": 1, "poisson": 1, "viande": 1}'::jsonb, NULL, NULL),
  ('menu_gastronomique_2', 'Menu 2 — Huîtres gratinées au four (origine Port-Sainte-Marie), Turbot sauce hollandaise, Soufflé au Grand Marnier', 1, 5, '{"cereales": 1, "poisson": 2}'::jsonb, NULL, NULL),
  ('menu_gastronomique_3', 'Menu 3 — Foie gras et sa gelée de gewurztraminer, Chapon sauce aux morilles, Pavlova aux fruits rouges', 1, 5, '{"fruits_legumes": 1, "viande": 2}'::jsonb, NULL, NULL),
  ('menu_psm_1', 'Menu 1 — Salade verte à l''ail et aux noix, Poulpe à la mariannaise, Riz au lait à la cannelle', 1, 6, '{"cereales": 1, "fruits_legumes": 1, "poisson": 1}'::jsonb, NULL, NULL),
  ('menu_psm_2', 'Menu 2 — Salade de chou rouge et pomme verte, Magret de canard colvert, Île flottante', 1, 6, '{"cereales": 1, "fruits_legumes": 1, "viande": 1}'::jsonb, NULL, NULL),
  ('menu_psm_3', 'Menu 3 — Huîtres de PSM, Tourte au crabe, Crème brûlée au Grand Marnier', 1, 6, '{"cereales": 1, "poisson": 2}'::jsonb, NULL, NULL),
  ('petit_dejeuner', 'Petit-déjeuner', 1, 10, '{"cereales": 1}'::jsonb, NULL, NULL),
  ('plat_de_poisson', 'Plat de poisson', 1, 5, '{"cereales": 1, "poisson": 1}'::jsonb, NULL, NULL),
  ('sandwich', 'Sandwich', 1, 8, '{"cereales": 1, "fruits_legumes": 1, "viande": 1}'::jsonb, NULL, NULL),
  ('sandwich_cheminots', 'Sandwich jambon-beurre-cornichon', 1, 5, '{"cereales": 1, "viande": 1}'::jsonb, NULL, NULL),
  ('saucisse_puree', 'Saucisse-purée', 1, 5, '{"cereales": 1, "viande": 1}'::jsonb, NULL, NULL),
  ('snack_buvette', 'Cacahuètes salées', 1, 15, '{"cereales": 1}'::jsonb, NULL, NULL),
  ('vin', 'Vin', 1, 15, '{"fruits_legumes": 1}'::jsonb, NULL, NULL);

DELETE FROM public.commerces_types;
INSERT INTO public.commerces_types (cle, type) VALUES
  ('bar-des-pecheurs|salle_bar', 'bar'),
  ('brasserie-voyageurs-montrouge', 'brasserie'),
  ('cafe-gare-montrouge', 'cafe'),
  ('cafe-tabac-cheminots-montrouge', 'cafe'),
  ('capitaine-sauvage|salle_principale', 'brasserie'),
  ('hotel-mineur', 'cafe'),
  ('hotel-port|hall_port', 'cafe'),
  ('hotel-republica', 'brasserie'),
  ('marche', 'marche'),
  ('marche-psm|etals', 'marche'),
  ('stade|buvette', 'buvette');

DELETE FROM public.commerces_dotations;
INSERT INTO public.commerces_dotations (cle, type, caisse, stock_matieres, cout_moyen_matieres, carte, parametres) VALUES
  ('bar-des-pecheurs|salle_bar', 'bar', 2000, '{"cereales": 10, "fruits_legumes": 10, "produits_exotiques": 10}'::jsonb, '{"cereales": 3, "fruits_legumes": 4, "produits_exotiques": 6}'::jsonb, '["biere_pression", "vin", "cafe_boisson", "boisson_sans_alcool", "snack_buvette"]'::jsonb, '{"prixVente": {"biere_pression": 7, "boisson_sans_alcool": 10, "cafe_boisson": 7, "snack_buvette": 7, "vin": 7}, "stockMax": {"biere_pression": 20, "boisson_sans_alcool": 20, "cafe_boisson": 20, "snack_buvette": 20, "vin": 20}}'::jsonb),
  ('brasserie-voyageurs-montrouge', 'brasserie', 3000, '{"cereales": 15, "poisson": 10, "viande": 15}'::jsonb, '{"cereales": 3, "poisson": 4, "viande": 5}'::jsonb, '["carbonade_frites", "plat_de_poisson", "saucisse_puree"]'::jsonb, '{"prixVente": {"carbonade_frites": 23, "plat_de_poisson": 23, "saucisse_puree": 23}, "stockMax": {"carbonade_frites": 20, "plat_de_poisson": 20, "saucisse_puree": 20}}'::jsonb),
  ('cafe-gare-montrouge', 'cafe', 2000, '{"cereales": 10, "fruits_legumes": 10, "produits_exotiques": 10, "viande": 10}'::jsonb, '{"cereales": 3, "fruits_legumes": 4, "produits_exotiques": 6, "viande": 5}'::jsonb, '["boeuf_bourguignon", "cafe_boisson", "jus_de_fruits", "vin", "biere_pression"]'::jsonb, '{"prixVente": {"biere_pression": 7, "boeuf_bourguignon": 23, "cafe_boisson": 7, "jus_de_fruits": 7, "vin": 7}, "stockMax": {"biere_pression": 20, "boeuf_bourguignon": 20, "cafe_boisson": 20, "jus_de_fruits": 20, "vin": 20}}'::jsonb),
  ('cafe-tabac-cheminots-montrouge', 'cafe', 2000, '{"cereales": 10, "fruits_legumes": 10, "produits_exotiques": 10, "viande": 10}'::jsonb, '{"cereales": 3, "fruits_legumes": 4, "produits_exotiques": 6, "viande": 5}'::jsonb, '["sandwich_cheminots", "cafe_boisson", "jus_de_fruits", "vin", "biere_pression"]'::jsonb, '{"prixVente": {"biere_pression": 7, "cafe_boisson": 7, "jus_de_fruits": 7, "sandwich_cheminots": 10, "vin": 7}, "stockMax": {"biere_pression": 20, "cafe_boisson": 20, "jus_de_fruits": 20, "sandwich_cheminots": 20, "vin": 20}}'::jsonb),
  ('capitaine-sauvage|salle_principale', 'brasserie', 3000, '{"cereales": 15, "fruits_legumes": 10, "poisson": 10, "viande": 10}'::jsonb, '{"cereales": 3, "fruits_legumes": 4, "poisson": 4, "viande": 5}'::jsonb, '["menu_psm_1", "menu_psm_2", "menu_psm_3", "vin"]'::jsonb, '{"prixVente": {"menu_psm_1": 20, "menu_psm_2": 21, "menu_psm_3": 20, "vin": 7}, "stockMax": {"menu_psm_1": 20, "menu_psm_2": 20, "menu_psm_3": 20, "vin": 20}}'::jsonb),
  ('hotel-mineur', 'cafe', 1000, '{"cereales": 10}'::jsonb, '{"cereales": 3}'::jsonb, '["petit_dejeuner"]'::jsonb, '{"prixVente": {"petit_dejeuner": 11}, "stockMax": {"petit_dejeuner": 20}}'::jsonb),
  ('hotel-port|hall_port', 'cafe', 1000, '{"cereales": 10}'::jsonb, '{"cereales": 3}'::jsonb, '["petit_dejeuner"]'::jsonb, '{"prixVente": {"petit_dejeuner": 11}, "stockMax": {"petit_dejeuner": 20}}'::jsonb),
  ('hotel-republica', 'brasserie', 5000, '{"cereales": 25, "fruits_legumes": 20, "poisson": 10, "produits_exotiques": 10, "viande": 15}'::jsonb, '{"cereales": 3, "fruits_legumes": 4, "poisson": 4, "produits_exotiques": 6, "viande": 5}'::jsonb, '["menu_gastronomique_1", "menu_gastronomique_2", "menu_gastronomique_3", "vin", "cafe_boisson", "biere_pression", "snack_buvette"]'::jsonb, '{"prixVente": {"biere_pression": 7, "cafe_boisson": 7, "menu_gastronomique_1": 120, "menu_gastronomique_2": 120, "menu_gastronomique_3": 120, "snack_buvette": 7, "vin": 7}, "stockMax": {"biere_pression": 20, "cafe_boisson": 20, "menu_gastronomique_1": 20, "menu_gastronomique_2": 20, "menu_gastronomique_3": 20, "snack_buvette": 20, "vin": 20}}'::jsonb),
  ('marche', 'marche', 0, '{"bois": 10, "cereales": 10, "fruits_legumes": 10, "metal": 10, "produits_exotiques": 10, "textile": 10, "viande": 10}'::jsonb, '{"bois": 5, "cereales": 3, "fruits_legumes": 4, "metal": 15, "produits_exotiques": 6, "textile": 5, "viande": 5}'::jsonb, '["croque_monsieur_luthecia", "echarpe_luthecia", "carte_luthecia_institutions", "carte_luthecia_internationale", "carte_luthecia_culture", "porte_cle_palais_luthecia", "garde_republien_plomb", "figurine_maxence_monfils"]'::jsonb, '{"prixVente": {"carte_luthecia_culture": 7, "carte_luthecia_institutions": 7, "carte_luthecia_internationale": 7, "croque_monsieur_luthecia": 16, "echarpe_luthecia": 20, "figurine_maxence_monfils": 22, "garde_republien_plomb": 22, "porte_cle_palais_luthecia": 22}, "stockMax": {"carte_luthecia_culture": 20, "carte_luthecia_institutions": 20, "carte_luthecia_internationale": 20, "croque_monsieur_luthecia": 20, "echarpe_luthecia": 20, "figurine_maxence_monfils": 20, "garde_republien_plomb": 20, "porte_cle_palais_luthecia": 20}}'::jsonb),
  ('marche-psm|etals', 'marche', 0, '{"bois": 10, "cereales": 10, "poisson": 10, "textile": 10}'::jsonb, '{"bois": 5, "cereales": 3, "poisson": 4, "textile": 5}'::jsonb, '["cornet_friture_psm", "tshirt_psm", "carte_psm_notre_dame_mer", "carte_psm_touristique", "carte_psm_culture_marine"]'::jsonb, '{"prixVente": {"carte_psm_culture_marine": 7, "carte_psm_notre_dame_mer": 7, "carte_psm_touristique": 7, "cornet_friture_psm": 14, "tshirt_psm": 20}, "stockMax": {"carte_psm_culture_marine": 20, "carte_psm_notre_dame_mer": 20, "carte_psm_touristique": 20, "cornet_friture_psm": 20, "tshirt_psm": 20}}'::jsonb),
  ('stade|buvette', 'buvette', 0, '{"alcool": 10, "cereales": 5}'::jsonb, '{"alcool": 14, "cereales": 3}'::jsonb, '["biere_pression", "boisson_sans_alcool", "snack_buvette"]'::jsonb, '{"prixVente": {"biere_pression": 7, "boisson_sans_alcool": 10, "snack_buvette": 7}, "stockMax": {"biere_pression": 20, "boisson_sans_alcool": 20, "snack_buvette": 20}}'::jsonb);

DELETE FROM public.armureries_dotations;
INSERT INTO public.armureries_dotations (pays, caisse, stock_matieres, parametres) VALUES
  ('republic', 20000, '{"bois": 10, "metal": 20}'::jsonb, '{"prixAchatMatiere": {"bois": 10, "metal": 20}, "prixVente": {"carabine_chasse": 1200, "couteau": 300, "revolver": 800}, "stockMax": {"carabine_chasse": 5, "couteau": 10, "revolver": 5}}'::jsonb),
  ('narco', 20000, '{"bois": 10, "metal": 20}'::jsonb, '{"prixAchatMatiere": {"bois": 10, "metal": 20}, "prixVente": {"ak47": 1200, "desert_eagle": 800, "machette": 300}, "stockMax": {"ak47": 5, "desert_eagle": 5, "machette": 10}}'::jsonb),
  ('soviet', 20000, '{"bois": 10, "metal": 20}'::jsonb, '{"prixAchatMatiere": {"bois": 10, "metal": 20}, "prixVente": {"baionnette": 300, "kalachnikov": 1200, "makarov": 800}, "stockMax": {"baionnette": 10, "kalachnikov": 5, "makarov": 5}}'::jsonb);

DELETE FROM public.entreprises_constantes;
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES
  ('cout_main_oeuvre_pa_alimentaire', 50),
  ('pa_production_armurerie', 2),
  ('salaire_production_armurerie', 100),
  ('stock_max_commerce', 20);
