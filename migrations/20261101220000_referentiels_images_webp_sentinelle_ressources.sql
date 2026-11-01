-- Référentiels #219 (Claude, intégrateur, 01/11/2026) — contrôle Referential.
-- Indépendante de l'écran ; ne touche à aucun personnage, compte, prix, recette ou palier.
--
-- 1. recettes_commerce.image : les 18 produits des marchés (Luthécia, PSM, Montrouge) pointent
--    encore vers des .png supprimés lors du passage au WebP ; data.js (miroir généré par
--    generer_miroirs_entreprises.py) déclare les .webp, présents dans images/. Relecture de la
--    production du 01/11 vers 21 h 50 : c'est le SEUL écart entre data.js et les sept tables du
--    miroir entreprises (tarifs, cartes, dotations, rachats, menus et boissons identiques).
-- 2. ressources_economie_empreinte : la sentinelle posée (2c2a88b3833ca978) ne correspond plus
--    au contenu ; le contenu réel (d65ae14b210eaac4) est égal au générateur. On repose la
--    sentinelle sur le contenu mesuré, sans toucher au contenu.
-- Gardes : chaque écriture exige l'état exact relu en production ; rejouable sans effet.
DO $ref219$
DECLARE n integer; reelle text;
BEGIN
 WITH v(id, ancien, nouveau) AS (VALUES
  ('tshirt_psm','images/port-sainte-marie-marche-tshirt.png','images/port-sainte-marie-marche-tshirt.webp'),
  ('echarpe_luthecia','images/luthecia-marche-echarpe.png','images/luthecia-marche-echarpe.webp'),
  ('cornet_friture_psm','images/port-sainte-marie-marche-friture.png','images/port-sainte-marie-marche-friture.webp'),
  ('casquette_montrouge','images/montrouge/montrouge-marche-casquette.png','images/montrouge/montrouge-marche-casquette.webp'),
  ('carte_psm_touristique','images/port-sainte-marie-carte-postale-touristique.png','images/port-sainte-marie-carte-postale-touristique.webp'),
  ('casse_croute_cheminot','images/montrouge/montrouge-marche-casse-croute.png','images/montrouge/montrouge-marche-casse-croute.webp'),
  ('garde_republien_plomb','images/luthecia-souvenir-garde-republien.png','images/luthecia-souvenir-garde-republien.webp'),
  ('carte_luthecia_culture','images/luthecia-carte-postale-culture.png','images/luthecia-carte-postale-culture.webp'),
  ('carte_psm_culture_marine','images/port-sainte-marie-carte-postale-culture-marine.png','images/port-sainte-marie-carte-postale-culture-marine.webp'),
  ('carte_psm_notre_dame_mer','images/port-sainte-marie-carte-postale-notre-dame-mer.png','images/port-sainte-marie-carte-postale-notre-dame-mer.webp'),
  ('croque_monsieur_luthecia','images/luthecia-marche-croque-monsieur.png','images/luthecia-marche-croque-monsieur.webp'),
  ('figurine_maxence_monfils','images/luthecia-souvenir-maxence-monfils.png','images/luthecia-souvenir-maxence-monfils.webp'),
  ('porte_cle_palais_luthecia','images/luthecia-souvenir-porte-cle-palais.png','images/luthecia-souvenir-porte-cle-palais.webp'),
  ('carte_montrouge_musee_rail','images/montrouge/montrouge-carte-postale-musee-rail.png','images/montrouge/montrouge-carte-postale-musee-rail.webp'),
  ('carte_montrouge_place_rail','images/montrouge/montrouge-carte-postale-place-rail.png','images/montrouge/montrouge-carte-postale-place-rail.webp'),
  ('carte_luthecia_institutions','images/luthecia-carte-postale-institutions.png','images/luthecia-carte-postale-institutions.webp'),
  ('carte_montrouge_touristique','images/montrouge/montrouge-carte-postale-touristique.png','images/montrouge/montrouge-carte-postale-touristique.webp'),
  ('carte_luthecia_internationale','images/luthecia-carte-postale-internationale.png','images/luthecia-carte-postale-internationale.webp'))
 UPDATE public.recettes_commerce r SET image = v.nouveau FROM v WHERE r.id = v.id AND r.image = v.ancien;
 GET DIAGNOSTICS n = ROW_COUNT;
 IF n NOT IN (0, 18) THEN RAISE EXCEPTION 'ref219_images_etat_partiel: % ligne(s)', n; END IF;
 IF EXISTS (SELECT 1 FROM public.recettes_commerce WHERE image LIKE '%.png') THEN
  RAISE EXCEPTION 'ref219_images_png_restantes';
 END IF;

 reelle := public.ressources_economie_empreinte_reelle();
 IF reelle IS DISTINCT FROM 'd65ae14b210eaac4' THEN
  RAISE EXCEPTION 'ref219_ressources_contenu_different: %', reelle;
 END IF;
 UPDATE public.ressources_economie_empreinte SET empreinte = reelle, pose_le = now()
  WHERE seul AND empreinte = '2c2a88b3833ca978';
 PERFORM 1 FROM public.ressources_economie_empreinte WHERE seul AND empreinte = reelle;
 IF NOT FOUND OR (SELECT count(*) FROM public.ressources_economie_empreinte) <> 1
    OR (SELECT empreinte FROM public.ressources_economie_empreinte) IS DISTINCT FROM reelle THEN
  RAISE EXCEPTION 'ref219_ressources_sentinelle_inattendue';
 END IF;
END $ref219$;
