-- Starovka : prolongation de la rue restaurant-boutique vers le siège du Blizzard.
DO $starovka$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
      AND noeud='starovka-rue-restaurant-boutique'
      AND directions->'liens'->>'toutDroit'='starovka-rue-logements-collectifs'
  ) THEN RAISE EXCEPTION 'starovka_restaurant_boutique_socle_absent'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_a','starovka-rue-restaurant-boutique',
      ARRAY['starovka-rue-logements-collectifs','starovka-rue-blizzard']::text[],
      '{"liens":{"toutDroit":"starovka-rue-logements-collectifs","arriere":"starovka-rue-blizzard"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-blizzard',
      ARRAY['starovka-rue-restaurant-boutique']::text[],
      '{"liens":{"toutDroit":"starovka-rue-restaurant-boutique"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

  IF (SELECT count(*) FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
    AND ((noeud='starovka-rue-restaurant-boutique'
      AND directions->'liens'='{"toutDroit":"starovka-rue-logements-collectifs","arriere":"starovka-rue-blizzard"}'::jsonb)
      OR (noeud='starovka-rue-blizzard'
      AND directions->'liens'='{"toutDroit":"starovka-rue-restaurant-boutique"}'::jsonb)))<>2
  THEN RAISE EXCEPTION 'starovka_blizzard_liens_invalides'; END IF;
END $starovka$;
