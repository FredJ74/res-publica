-- Starovka : prolongation logements collectifs vers le restaurant et boutique.
DO $starovka$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
      AND noeud='starovka-rue-logements-collectifs'
      AND directions->'liens'->>'gauche'='starovka-rue-terrains'
  ) THEN RAISE EXCEPTION 'starovka_logements_socle_absent'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_a','starovka-rue-logements-collectifs',
      ARRAY['starovka-rue-terrains','starovka-rue-restaurant-boutique']::text[],
      '{"liens":{"gauche":"starovka-rue-terrains","arriere":"starovka-rue-restaurant-boutique"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-restaurant-boutique',
      ARRAY['starovka-rue-logements-collectifs']::text[],
      '{"liens":{"toutDroit":"starovka-rue-logements-collectifs"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

  IF (SELECT count(*) FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
    AND ((noeud='starovka-rue-logements-collectifs'
      AND directions->'liens'='{"gauche":"starovka-rue-terrains","arriere":"starovka-rue-restaurant-boutique"}'::jsonb)
      OR (noeud='starovka-rue-restaurant-boutique'
      AND directions->'liens'='{"toutDroit":"starovka-rue-logements-collectifs"}'::jsonb)))<>2
  THEN RAISE EXCEPTION 'starovka_restaurant_liens_invalides'; END IF;
END $starovka$;
