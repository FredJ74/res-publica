-- Starovka : depuis la place mairie-marché, flèche gauche basse vers lycée et commissariat.
-- Le graphe serveur reste autoritaire pour les deux directions.
DO $starovka$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
      AND noeud='starovka-rue-mairie-marche'
      AND directions->'liens'->>'toutDroit'='starovka-rue-blizzard'
  ) THEN RAISE EXCEPTION 'starovka_mairie_marche_socle_absent'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_a','starovka-rue-mairie-marche',
      ARRAY['starovka-rue-blizzard','starovka-rue-lycee-commissariat']::text[],
      '{"liens":{"toutDroit":"starovka-rue-blizzard","gauche":"starovka-rue-lycee-commissariat"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-lycee-commissariat',
      ARRAY['starovka-rue-mairie-marche']::text[],
      '{"liens":{"droite":"starovka-rue-mairie-marche"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

  IF (SELECT count(*) FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
    AND ((noeud='starovka-rue-mairie-marche'
      AND directions->'liens'='{"toutDroit":"starovka-rue-blizzard","gauche":"starovka-rue-lycee-commissariat"}'::jsonb)
      OR (noeud='starovka-rue-lycee-commissariat'
      AND directions->'liens'='{"droite":"starovka-rue-mairie-marche"}'::jsonb)))<>2
  THEN RAISE EXCEPTION 'starovka_lycee_commissariat_liens_invalides'; END IF;
END $starovka$;
