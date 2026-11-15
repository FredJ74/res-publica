-- Correction du placement de la raffinerie, demandé par Fred le 15/11/2026.
-- Ordre exact : pétrole-ferme ↔ terrains ↔ raffinerie ↔ logements collectifs.
-- Les sorties verticales du carrefour, des logements et les façades restent inchangées.
DO $correctif$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.rue_noeuds_serveur
  WHERE country='soviet' AND city='ville_a'
    AND ((noeud='starovka-rue-petrole-ferme'
            AND directions->'liens'->>'droite' IN ('starovka-rue-raffinerie','starovka-rue-terrains')
            AND directions->'liens'->>'toutDroit'='starovka-maisons-ferme'
            AND directions->'liens'->>'arriere'='starovka-rue-locaux-a-louer')
      OR (noeud='starovka-rue-terrains'
            AND directions->'liens'->>'gauche' IN ('starovka-rue-raffinerie','starovka-rue-petrole-ferme')
            AND directions->'liens'->>'droite' IN ('starovka-rue-logements-collectifs','starovka-rue-raffinerie'))
      OR (noeud='starovka-rue-raffinerie'
            AND directions->'liens'->>'gauche' IN ('starovka-rue-petrole-ferme','starovka-rue-terrains')
            AND directions->'liens'->>'droite' IN ('starovka-rue-terrains','starovka-rue-logements-collectifs'))
      OR (noeud='starovka-rue-logements-collectifs'
            AND directions->'liens'->>'gauche' IN ('starovka-rue-terrains','starovka-rue-raffinerie')
            AND directions->'liens'->>'arriere'='starovka-rue-restaurant-boutique'
            AND directions->'liens'->>'droite'='starovka-rue-stade'));
  IF n<>4 THEN RAISE EXCEPTION 'Starovka : topologie de départ non conforme (% noeuds)', n; END IF;

  UPDATE public.rue_noeuds_serveur SET
    directions=jsonb_set(directions,'{liens,droite}','"starovka-rue-terrains"'::jsonb),
    voisins=array_replace(voisins,'starovka-rue-raffinerie','starovka-rue-terrains')
  WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-petrole-ferme';

  UPDATE public.rue_noeuds_serveur SET
    directions=jsonb_set(jsonb_set(directions,'{liens,gauche}','"starovka-rue-petrole-ferme"'::jsonb),
                             '{liens,droite}','"starovka-rue-raffinerie"'::jsonb),
    voisins=ARRAY['starovka-rue-petrole-ferme','starovka-rue-raffinerie']::text[]
  WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-terrains';

  UPDATE public.rue_noeuds_serveur SET
    directions=jsonb_set(jsonb_set(directions,'{liens,gauche}','"starovka-rue-terrains"'::jsonb),
                             '{liens,droite}','"starovka-rue-logements-collectifs"'::jsonb),
    voisins=ARRAY['starovka-rue-terrains','starovka-rue-logements-collectifs']::text[]
  WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-raffinerie';

  UPDATE public.rue_noeuds_serveur SET
    directions=jsonb_set(directions,'{liens,gauche}','"starovka-rue-raffinerie"'::jsonb),
    voisins=array_replace(voisins,'starovka-rue-terrains','starovka-rue-raffinerie')
  WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-logements-collectifs';

  SELECT count(*) INTO n FROM public.rue_noeuds_serveur
  WHERE country='soviet' AND city='ville_a' AND
    ((noeud='starovka-rue-petrole-ferme' AND directions->'liens'->>'droite'='starovka-rue-terrains')
     OR (noeud='starovka-rue-terrains' AND directions->'liens'='{"gauche":"starovka-rue-petrole-ferme","droite":"starovka-rue-raffinerie"}'::jsonb)
     OR (noeud='starovka-rue-raffinerie' AND directions->'liens'='{"gauche":"starovka-rue-terrains","droite":"starovka-rue-logements-collectifs"}'::jsonb)
     OR (noeud='starovka-rue-logements-collectifs'
             AND directions->'liens'->>'gauche'='starovka-rue-raffinerie'));
  IF n<>4 THEN RAISE EXCEPTION 'Starovka : correction incomplète'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments
       WHERE country='soviet' AND city='ville_a'
         AND noeud='starovka-rue-raffinerie' AND building='usine-principale')
     THEN RAISE EXCEPTION 'Starovka : entrée de raffinerie manquante'; END IF;
END $correctif$;