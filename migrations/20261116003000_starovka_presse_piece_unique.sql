-- Starovka : le commerce du journal Metel est une salle de presse unique.
-- Le centre d'affaires distinct conserve ses salles de bureaux dans sa propre rue.
BEGIN;
DO $pre$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville='ville_a' AND batiment='centre-affaires' AND pieces @> '["tribune_republia"]'::jsonb) THEN
  RAISE EXCEPTION 'Ancienne salle de presse du centre affaires absente';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-blizzard' AND building='centre-affaires') THEN
  RAISE EXCEPTION 'Ancienne entrée de presse absente';
 END IF;
END $pre$;
INSERT INTO public.navigation_lieux_regles(pays,ville,batiment,pieces,ferme,membership)
VALUES ('soviet','ville_a','presse-starovka','["presse"]'::jsonb,false,NULL)
ON CONFLICT (pays,ville,batiment) DO UPDATE SET pieces=EXCLUDED.pieces;
INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
VALUES('soviet','ville_a','starovka-rue-blizzard','presse-starovka')
ON CONFLICT DO NOTHING;
UPDATE public.navigation_lieux_regles
SET pieces=pieces - 'tribune_republia'
WHERE pays='soviet' AND ville='ville_a' AND batiment='centre-affaires'
AND pieces @> '["tribune_republia"]'::jsonb;
DELETE FROM public.rue_sorties_batiments
WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-blizzard' AND building='centre-affaires';
DO $post$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville='ville_a' AND batiment='presse-starovka' AND pieces='["presse"]'::jsonb)
 OR EXISTS(SELECT 1 FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville='ville_a' AND batiment='centre-affaires' AND pieces @> '["tribune_republia"]'::jsonb)
 OR NOT EXISTS(SELECT 1 FROM public.rue_sorties_batiments WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-blizzard' AND building='presse-starovka')
 THEN RAISE EXCEPTION 'Séparation des salles presse et bureaux non appliquée'; END IF;
END $post$;
COMMIT;
