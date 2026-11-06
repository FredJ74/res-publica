-- Starovka: prolongation vers la rue pétrole-ferme, sans changer les autres rues.
-- Le mouvement de rue reste sous l'autorité de rue_noeuds_serveur.
DO $starovka$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a' AND noeud='starovka-maisons-ferme'
      AND directions->'liens'->>'toutDroit'='starovka-rue-hotel'
  ) THEN RAISE EXCEPTION 'starovka_maisons_ferme_socle_absent'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_a','starovka-maisons-ferme',
       ARRAY['starovka-rue-hotel','starovka-rue-petrole-ferme']::text[],
       '{"liens":{"toutDroit":"starovka-rue-hotel","arriere":"starovka-rue-petrole-ferme"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-petrole-ferme',
       ARRAY['starovka-maisons-ferme']::text[],
       '{"liens":{"toutDroit":"starovka-maisons-ferme"},"parArrivee":{}}'::jsonb)
  ON CONFLICT (country,city,noeud) DO UPDATE
  SET voisins=EXCLUDED.voisins, directions=EXCLUDED.directions;

  IF (SELECT count(*) FROM public.rue_noeuds_serveur
      WHERE country='soviet' AND city='ville_a'
      AND ((noeud='starovka-maisons-ferme' AND
        directions->'liens'='{"toutDroit":"starovka-rue-hotel","arriere":"starovka-rue-petrole-ferme"}'::jsonb)
       OR (noeud='starovka-rue-petrole-ferme' AND
        directions->'liens'='{"toutDroit":"starovka-maisons-ferme"}'::jsonb)))<>2
  THEN RAISE EXCEPTION 'starovka_petrole_ferme_navigation_incoherente'; END IF;
END $starovka$;
