-- Starovka, décision Fred 15/11 : raffinerie entre rue pétrolière et terrains.
-- Préserve les sorties vers maisons/ferme et locaux à louer, sans changer leurs ordres.
DO $starovka$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
    AND noeud='starovka-rue-petrole-ferme'
    AND directions->'liens'->>'droite' IN ('starovka-rue-terrains','starovka-rue-raffinerie')
    AND directions->'liens'->>'toutDroit'='starovka-maisons-ferme'
    AND directions->'liens'->>'arriere'='starovka-rue-locaux-a-louer'
  ) THEN RAISE EXCEPTION 'starovka_carrefour_petrole_inattendu'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
    AND noeud='starovka-rue-terrains'
    AND directions->'liens'->>'gauche' IN ('starovka-rue-petrole-ferme','starovka-rue-raffinerie')
    AND directions->'liens'->>'droite'='starovka-rue-logements-collectifs'
  ) THEN RAISE EXCEPTION 'starovka_terrains_inattendu'; END IF;

  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
      WHERE pays='soviet' AND ville='ville_a' AND batiment='usine-principale')
  THEN RAISE EXCEPTION 'starovka_raffinerie_batiment_inconnu'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES ('soviet','ville_a','starovka-rue-raffinerie',
    ARRAY['starovka-rue-petrole-ferme','starovka-rue-terrains']::text[],
    '{"liens":{"gauche":"starovka-rue-petrole-ferme","droite":"starovka-rue-terrains"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO UPDATE
  SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

  UPDATE public.rue_noeuds_serveur
  SET voisins=array_replace(voisins,'starovka-rue-terrains','starovka-rue-raffinerie'),
      directions=jsonb_set(directions,'{liens,droite}','"starovka-rue-raffinerie"'::jsonb)
  WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-petrole-ferme';

  UPDATE public.rue_noeuds_serveur
  SET voisins=array_replace(voisins,'starovka-rue-petrole-ferme','starovka-rue-raffinerie'),
      directions=jsonb_set(directions,'{liens,gauche}','"starovka-rue-raffinerie"'::jsonb)
  WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-terrains';

  INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
  VALUES ('soviet','ville_a','starovka-rue-raffinerie','usine-principale')
  ON CONFLICT DO NOTHING;

  IF (SELECT count(*) FROM public.rue_noeuds_serveur
      WHERE country='soviet' AND city='ville_a' AND (
        (noeud='starovka-rue-petrole-ferme' AND directions->'liens'->>'droite'='starovka-rue-raffinerie')
        OR (noeud='starovka-rue-raffinerie'
          AND directions->'liens'='{"gauche":"starovka-rue-petrole-ferme","droite":"starovka-rue-terrains"}'::jsonb)
        OR (noeud='starovka-rue-terrains' AND directions->'liens'->>'gauche'='starovka-rue-raffinerie')
      ))<>3
    THEN RAISE EXCEPTION 'starovka_raffinerie_navigation_invalide'; END IF;
END $starovka$;