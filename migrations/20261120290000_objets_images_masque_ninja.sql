-- Images des objets de discrétion (Fred, 20/11/2026) : images/objet-masque-carnaval.webp et images/objet-tenue-ninja.webp.
--  • Recettes de commerce (masque des boutiques Habillement, tenue ninja du marché et de l'armurerie militaire) : colonne
--    image, recopiée en imageUrl par l'achat et la vente.
--  • Objets déposés par le serveur (crim_objet_interne : boutique « Équipement discret ») : imageUrl.
--  • Rattrapage : objets déjà possédés (inventaires) et références des commerces, sans image.
-- Idempotente (marques objets_images_masque_v1 / objets_images_ninja_v1).
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

UPDATE public.recettes_commerce SET image = 'images/objet-masque-carnaval.webp'
 WHERE id = 'masque_carnaval_habillement' AND image IS DISTINCT FROM 'images/objet-masque-carnaval.webp';
UPDATE public.recettes_commerce SET image = 'images/objet-tenue-ninja.webp'
 WHERE id IN ('tenue_ninja_marche', 'tenue_ninja_militaire') AND image IS DISTINCT FROM 'images/objet-tenue-ninja.webp';

SELECT pg_temp.rp_raccorder('public.crim_objet_interne(text)'::regprocedure,
  $a$jsonb_build_object('name', 'Masque de carnaval', 'icon', 'ti-mask',$a$,
  $b$jsonb_build_object('name', 'Masque de carnaval', 'icon', 'ti-mask', 'imageUrl', 'images/objet-masque-carnaval.webp' /* objets_images_masque_v1 */,$b$,
  'objets_images_masque_v1');
SELECT pg_temp.rp_raccorder('public.crim_objet_interne(text)'::regprocedure,
  $a$jsonb_build_object('name', 'Tenue ninja', 'icon', 'ti-shirt',$a$,
  $b$jsonb_build_object('name', 'Tenue ninja', 'icon', 'ti-shirt', 'imageUrl', 'images/objet-tenue-ninja.webp' /* objets_images_ninja_v1 */,$b$,
  'objets_images_ninja_v1');

-- Rattrapage des inventaires (objets reconnus par identité, jamais par nom).
UPDATE public.personnages_donnees d SET inventory = (
  SELECT jsonb_agg(CASE
    WHEN coalesce(e ->> 'imageUrl', '') = '' AND (e ->> 'generique_id' = 'masque_carnaval' OR e ->> 'recette_id' = 'masque_carnaval_habillement')
      THEN e || jsonb_build_object('imageUrl', 'images/objet-masque-carnaval.webp')
    WHEN coalesce(e ->> 'imageUrl', '') = '' AND (e ->> 'generique_id' = 'tenue_ninja' OR e ->> 'recette_id' IN ('tenue_ninja_marche', 'tenue_ninja_militaire'))
      THEN e || jsonb_build_object('imageUrl', 'images/objet-tenue-ninja.webp')
    ELSE e END ORDER BY o)
  FROM jsonb_array_elements(d.inventory) WITH ORDINALITY x(e, o))
 WHERE jsonb_typeof(d.inventory) = 'array'
   AND EXISTS (SELECT 1 FROM jsonb_array_elements(d.inventory) e
                WHERE coalesce(e ->> 'imageUrl', '') = ''
                  AND (e ->> 'generique_id' IN ('masque_carnaval', 'tenue_ninja')
                       OR e ->> 'recette_id' IN ('masque_carnaval_habillement', 'tenue_ninja_marche', 'tenue_ninja_militaire')));

-- Rattrapage des références des commerces (image recopiée à l'achat).
UPDATE public.entreprises e SET data = jsonb_set(e.data::jsonb, '{references}', (
  SELECT jsonb_object_agg(k, CASE
    WHEN coalesce(v ->> 'image', '') = '' AND v ->> 'recette_id' = 'masque_carnaval_habillement' THEN v || '{"image":"images/objet-masque-carnaval.webp"}'
    WHEN coalesce(v ->> 'image', '') = '' AND v ->> 'recette_id' IN ('tenue_ninja_marche', 'tenue_ninja_militaire') THEN v || '{"image":"images/objet-tenue-ninja.webp"}'
    ELSE v END)
  FROM jsonb_each(e.data::jsonb -> 'references') x(k, v)))
 WHERE jsonb_typeof(e.data::jsonb -> 'references') = 'object'
   AND EXISTS (SELECT 1 FROM jsonb_each(e.data::jsonb -> 'references') x(k, v)
                WHERE coalesce(v ->> 'image', '') = ''
                  AND v ->> 'recette_id' IN ('masque_carnaval_habillement', 'tenue_ninja_marche', 'tenue_ninja_militaire'));

COMMIT;
