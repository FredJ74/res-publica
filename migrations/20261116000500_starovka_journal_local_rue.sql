-- Rue du journal Metel, Starovka : autoriser les deux entrées visibles.
-- Réutilise les règles de pièces des bâtiments existants ; pas de modification de bail, commandes ou permissions.
BEGIN;
DO $a$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
 WHERE pays='soviet' AND ville='ville_a' AND batiment='locaux-starovka'
 AND pieces @> '["local_1"]'::jsonb)
 THEN RAISE EXCEPTION 'Local commercial 1 de Starovka absent'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
 WHERE pays='soviet' AND ville='ville_a' AND batiment='centre-affaires'
 AND pieces @> '["tribune_republia"]'::jsonb)
 THEN RAISE EXCEPTION 'Antenne de presse Starovka absente'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur
 WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-blizzard')
 THEN RAISE EXCEPTION 'Rue du journal Metel absente'; END IF;
END $a$;
INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
VALUES
 ('soviet','ville_a','starovka-rue-blizzard','locaux-starovka'),
 ('soviet','ville_a','starovka-rue-blizzard','centre-affaires')
ON CONFLICT DO NOTHING;
DO $b$
BEGIN
 IF (SELECT count(*) FROM public.rue_sorties_batiments
 WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-blizzard'
 AND building IN ('locaux-starovka','centre-affaires'))<>2
 THEN RAISE EXCEPTION 'Les deux vitrines ne sont pas accessibles depuis la rue'; END IF;
END $b$;
COMMIT;
