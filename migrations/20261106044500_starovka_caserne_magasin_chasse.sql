-- Starovka : bureaux/caserne vers la rue du magasin de chasse.
-- La base valide les destinations, aucune navigation client autonome.
DO $starovka$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
      AND noeud='starovka-rue-bureaux-caserne'
      AND directions->'liens'->>'droite'='starovka-rue-lycee-commissariat'
  ) THEN RAISE EXCEPTION 'starovka_bureaux_caserne_socle_absent'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_a','starovka-rue-bureaux-caserne',
      ARRAY['starovka-rue-lycee-commissariat','starovka-rue-magasin-chasse']::text[],
      '{"liens":{"droite":"starovka-rue-lycee-commissariat","toutDroit":"starovka-rue-magasin-chasse"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-magasin-chasse',
      ARRAY['starovka-rue-bureaux-caserne']::text[],
      '{"liens":{"arriere":"starovka-rue-bureaux-caserne"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

  IF (SELECT count(*) FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
    AND ((noeud='starovka-rue-bureaux-caserne'
      AND directions->'liens'='{"droite":"starovka-rue-lycee-commissariat","toutDroit":"starovka-rue-magasin-chasse"}'::jsonb)
      OR (noeud='starovka-rue-magasin-chasse'
      AND directions->'liens'='{"arriere":"starovka-rue-bureaux-caserne"}'::jsonb)))<>2
  THEN RAISE EXCEPTION 'starovka_magasin_chasse_liens_invalides'; END IF;
END $starovka$;
