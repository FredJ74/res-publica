-- Starovka, rue des locaux à louer (décisions de Fred, 17/11/2026, GAME-DESIGN-NOVOMIRSK.md
-- « Tour de Starovka ») :
-- 1. Les trois commerces de droite sont les locaux n°3 à 5 (bâtiment locaux-starovka-route), mêmes
--    règles que les locaux n°1 et 2 : demande à la mairie, loyer plafonné à 30 PSK par jour.
-- 2. Le champ de pétrole de gauche est un lieu distinct (champ-petrole-starovka) ; la récolte y
--    fonctionne comme au champ de la Compagnie (recolte_effectuer ne dépend que de la ville).
-- 3. Cette rue n'ouvre plus les locaux n°1 et 2, qui ont leurs propres rues (journal Metel, chasse).
BEGIN;

DO $starovka$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-locaux-a-louer')
  THEN RAISE EXCEPTION 'starovka_rue_locaux_absente'; END IF;
  IF NOT ('Pétrole' = ANY (public.recolte_matieres_ville('soviet','ville_a')))
  THEN RAISE EXCEPTION 'starovka_sans_petrole_a_recolter'; END IF;
END
$starovka$;

INSERT INTO public.navigation_lieux_regles(pays,ville,batiment,pieces,ferme,membership)
SELECT 'soviet','ville_a','locaux-starovka-route','["local_3","local_4","local_5"]'::jsonb,false,NULL
 WHERE NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_a' AND batiment='locaux-starovka-route');
INSERT INTO public.navigation_lieux_regles(pays,ville,batiment,pieces,ferme,membership)
SELECT 'soviet','ville_a','champ-petrole-starovka','["zone_recolte"]'::jsonb,false,NULL
 WHERE NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_a' AND batiment='champ-petrole-starovka');

INSERT INTO public.sovarka_locaux (pays, ville, batiment, piece, label, origine, loyer, plafond)
SELECT 'soviet','ville_a','locaux-starovka-route', p, 'Local à louer n°' || right(p,1), 'centre', 0, 30
  FROM unnest(ARRAY['local_3','local_4','local_5']) AS p
 WHERE NOT EXISTS (SELECT 1 FROM public.sovarka_locaux l
   WHERE l.pays='soviet' AND l.ville='ville_a' AND l.batiment='locaux-starovka-route' AND l.piece=p);

INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
VALUES ('soviet','ville_a','starovka-rue-locaux-a-louer','locaux-starovka-route'),
       ('soviet','ville_a','starovka-rue-locaux-a-louer','champ-petrole-starovka')
ON CONFLICT DO NOTHING;
DELETE FROM public.rue_sorties_batiments
 WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-locaux-a-louer' AND building='locaux-starovka';

DO $starovka$
BEGIN
  IF (SELECT count(*) FROM public.sovarka_locaux
      WHERE pays='soviet' AND ville='ville_a' AND batiment='locaux-starovka-route' AND plafond=30) <> 3
  THEN RAISE EXCEPTION 'starovka_locaux_route_incomplets'; END IF;
  IF (SELECT count(*) FROM public.rue_sorties_batiments
      WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-locaux-a-louer') <> 2
  THEN RAISE EXCEPTION 'starovka_rue_locaux_sorties'; END IF;
  IF (SELECT count(*) FROM public.navigation_lieux_regles
      WHERE pays='soviet' AND ville='ville_a' AND batiment IN ('locaux-starovka-route','champ-petrole-starovka')) <> 2
  THEN RAISE EXCEPTION 'starovka_regles_navigation'; END IF;
END
$starovka$;
COMMIT;
