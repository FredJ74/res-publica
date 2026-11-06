-- Starovka : fermeture de la boucle bureaux-caserne > chasse > locaux > pétrole-ferme.
-- Trois flèches fonctionnelles au carrefour pétrole-ferme, sans flèche d'attente.
DO $starovka$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
      AND noeud='starovka-rue-magasin-chasse'
      AND directions->'liens'->>'arriere'='starovka-rue-bureaux-caserne'
  ) THEN RAISE EXCEPTION 'starovka_magasin_chasse_socle_absent'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
      AND noeud='starovka-rue-petrole-ferme'
      AND directions->'liens'->>'toutDroit'='starovka-maisons-ferme'
      AND directions->'liens'->>'droite'='starovka-rue-terrains'
  ) THEN RAISE EXCEPTION 'starovka_petrole_ferme_socle_absent'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_a','starovka-rue-magasin-chasse',
      ARRAY['starovka-rue-bureaux-caserne','starovka-rue-locaux-a-louer']::text[],
      '{"liens":{"arriere":"starovka-rue-bureaux-caserne","toutDroit":"starovka-rue-locaux-a-louer"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-locaux-a-louer',
      ARRAY['starovka-rue-magasin-chasse','starovka-rue-petrole-ferme']::text[],
      '{"liens":{"arriere":"starovka-rue-magasin-chasse","toutDroit":"starovka-rue-petrole-ferme"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-petrole-ferme',
      ARRAY['starovka-maisons-ferme','starovka-rue-terrains','starovka-rue-locaux-a-louer']::text[],
      '{"liens":{"toutDroit":"starovka-maisons-ferme","droite":"starovka-rue-terrains","arriere":"starovka-rue-locaux-a-louer"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

  IF (SELECT count(*) FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
    AND ((noeud='starovka-rue-magasin-chasse'
      AND directions->'liens'='{"arriere":"starovka-rue-bureaux-caserne","toutDroit":"starovka-rue-locaux-a-louer"}'::jsonb)
      OR (noeud='starovka-rue-locaux-a-louer'
      AND directions->'liens'='{"arriere":"starovka-rue-magasin-chasse","toutDroit":"starovka-rue-petrole-ferme"}'::jsonb)
      OR (noeud='starovka-rue-petrole-ferme'
      AND directions->'liens'='{"toutDroit":"starovka-maisons-ferme","droite":"starovka-rue-terrains","arriere":"starovka-rue-locaux-a-louer"}'::jsonb)))<>3
  THEN RAISE EXCEPTION 'starovka_boucle_chasse_locaux_petrole_non_conforme'; END IF;
END $starovka$;
