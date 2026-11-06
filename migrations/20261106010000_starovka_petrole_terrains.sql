-- Starovka : prolongation du carrefour pétrolier vers les terrains constructibles.
-- La flèche basse du carrefour n'a pas de destination définie : jamais de lien serveur fictif.
DO $starovka$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-petrole-ferme'
      AND directions->'liens'->>'toutDroit'='starovka-maisons-ferme'
  ) THEN RAISE EXCEPTION 'starovka_rue_petrole_ferme_absente'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_a','starovka-rue-petrole-ferme',
      ARRAY['starovka-maisons-ferme','starovka-rue-terrains']::text[],
      '{"liens":{"toutDroit":"starovka-maisons-ferme","droite":"starovka-rue-terrains"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-terrains',
      ARRAY['starovka-rue-petrole-ferme']::text[],
      '{"liens":{"gauche":"starovka-rue-petrole-ferme"},"parArrivee":{}}'::jsonb)
  ON CONFLICT (country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins, directions=EXCLUDED.directions;

  IF (SELECT count(*) FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
    AND ((noeud='starovka-rue-petrole-ferme'
      AND directions->'liens'='{"toutDroit":"starovka-maisons-ferme","droite":"starovka-rue-terrains"}'::jsonb
      AND voisins=ARRAY['starovka-maisons-ferme','starovka-rue-terrains']::text[])
      OR (noeud='starovka-rue-terrains'
      AND directions->'liens'='{"gauche":"starovka-rue-petrole-ferme"}'::jsonb
      AND voisins=ARRAY['starovka-rue-petrole-ferme']::text[]))) <> 2
  THEN RAISE EXCEPTION 'starovka_rue_terrains_navigation_non_conforme'; END IF;
END $starovka$;
