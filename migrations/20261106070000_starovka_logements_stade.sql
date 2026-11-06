-- Starovka : accès latéral aux tribunes depuis les logements collectifs.
-- Le serveur reste autoritaire sur les deux directions.
DO $starovka$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
      AND noeud='starovka-rue-logements-collectifs'
      AND directions->'liens'->>'gauche'='starovka-rue-terrains'
      AND directions->'liens'->>'arriere'='starovka-rue-restaurant-boutique'
  ) THEN RAISE EXCEPTION 'starovka_logements_socle_absent'; END IF;
  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_a','starovka-rue-logements-collectifs',
      ARRAY['starovka-rue-terrains','starovka-rue-restaurant-boutique','starovka-rue-stade']::text[],
      '{"liens":{"gauche":"starovka-rue-terrains","arriere":"starovka-rue-restaurant-boutique","droite":"starovka-rue-stade"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-stade',
      ARRAY['starovka-rue-logements-collectifs']::text[],
      '{"liens":{"gauche":"starovka-rue-logements-collectifs"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;
  IF (SELECT count(*) FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
    AND ((noeud='starovka-rue-logements-collectifs'
      AND directions->'liens'='{"gauche":"starovka-rue-terrains","arriere":"starovka-rue-restaurant-boutique","droite":"starovka-rue-stade"}'::jsonb)
      OR (noeud='starovka-rue-stade'
      AND directions->'liens'='{"gauche":"starovka-rue-logements-collectifs"}'::jsonb)))<>2
  THEN RAISE EXCEPTION 'starovka_stade_liens_invalides'; END IF;
END $starovka$;
