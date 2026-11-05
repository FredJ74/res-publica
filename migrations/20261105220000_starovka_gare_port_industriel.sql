-- Starovka (Sovarka, ville_a) : gare de fret et terminus au port industriel.
-- La sortie basse de la gare n'a pas encore d'image : aucune destination serveur
-- n'est inventée, contrairement au lien explicite gare <-> port.
DO $starovka$
BEGIN
  INSERT INTO public.rue_noeuds_serveur(country, city, noeud, voisins, directions)
  VALUES
    ('soviet', 'ville_a', 'starovka-rue-gare',
      ARRAY['starovka-rue-port-industriel']::text[],
      '{"liens":{"toutDroit":"starovka-rue-port-industriel"},"parArrivee":{}}'::jsonb),
    ('soviet', 'ville_a', 'starovka-rue-port-industriel',
      ARRAY['starovka-rue-gare']::text[],
      '{"liens":{"arriere":"starovka-rue-gare"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO UPDATE
  SET voisins=EXCLUDED.voisins, directions=EXCLUDED.directions;

  IF (SELECT count(*) FROM public.rue_noeuds_serveur
      WHERE country='soviet' AND city='ville_a'
      AND ((noeud='starovka-rue-gare'
        AND voisins=ARRAY['starovka-rue-port-industriel']::text[]
        AND directions->'liens'='{"toutDroit":"starovka-rue-port-industriel"}'::jsonb)
      OR (noeud='starovka-rue-port-industriel'
        AND voisins=ARRAY['starovka-rue-gare']::text[]
        AND directions->'liens'='{"arriere":"starovka-rue-gare"}'::jsonb)))<>2
  THEN RAISE EXCEPTION 'starovka_gare_port_navigation_non_conforme'; END IF;
END $starovka$;
