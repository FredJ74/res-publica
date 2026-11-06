-- Starovka : prolonger la rue des terrains vers les logements collectifs.
DO $starovka$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
      AND noeud='starovka-rue-terrains'
      AND directions->'liens'->>'gauche'='starovka-rue-petrole-ferme'
  ) THEN RAISE EXCEPTION 'starovka_terrains_socle_absent'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_a','starovka-rue-terrains',
      ARRAY['starovka-rue-petrole-ferme','starovka-rue-logements-collectifs']::text[],
      '{"liens":{"gauche":"starovka-rue-petrole-ferme","droite":"starovka-rue-logements-collectifs"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-logements-collectifs',
      ARRAY['starovka-rue-terrains']::text[],
      '{"liens":{"gauche":"starovka-rue-terrains"},"parArrivee":{}}'::jsonb)
  ON CONFLICT (country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

  IF (SELECT count(*) FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
    AND ((noeud='starovka-rue-terrains'
      AND directions->'liens'='{"gauche":"starovka-rue-petrole-ferme","droite":"starovka-rue-logements-collectifs"}'::jsonb)
      OR (noeud='starovka-rue-logements-collectifs'
      AND directions->'liens'='{"gauche":"starovka-rue-terrains"}'::jsonb)))<>2
  THEN RAISE EXCEPTION 'starovka_logements_liens_invalides'; END IF;
END $starovka$;
