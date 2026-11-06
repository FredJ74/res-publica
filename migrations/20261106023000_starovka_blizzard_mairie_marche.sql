-- Starovka : rue Blizzard vers place mairie et marché, même socle de navigation.
DO $starovka$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
      AND noeud='starovka-rue-blizzard'
      AND directions->'liens'->>'toutDroit'='starovka-rue-restaurant-boutique'
  ) THEN RAISE EXCEPTION 'starovka_blizzard_socle_absent'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_a','starovka-rue-blizzard',
      ARRAY['starovka-rue-restaurant-boutique','starovka-rue-mairie-marche']::text[],
      '{"liens":{"toutDroit":"starovka-rue-restaurant-boutique","arriere":"starovka-rue-mairie-marche"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-mairie-marche',
      ARRAY['starovka-rue-blizzard']::text[],
      '{"liens":{"toutDroit":"starovka-rue-blizzard"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

  IF (SELECT count(*) FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
    AND ((noeud='starovka-rue-blizzard'
      AND directions->'liens'='{"toutDroit":"starovka-rue-restaurant-boutique","arriere":"starovka-rue-mairie-marche"}'::jsonb)
      OR (noeud='starovka-rue-mairie-marche'
      AND directions->'liens'='{"toutDroit":"starovka-rue-blizzard"}'::jsonb)))<>2
  THEN RAISE EXCEPTION 'starovka_mairie_marche_liens_invalides'; END IF;
END $starovka$;
