-- Starovka : lycée/commissariat entre mairie/marché et bureaux/caserne.
-- Les deux flèches sont latérales ; leur position CSS reste à mi-hauteur.
DO $starovka$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
      AND noeud='starovka-rue-lycee-commissariat'
      AND directions->'liens'->>'droite'='starovka-rue-mairie-marche'
  ) THEN RAISE EXCEPTION 'starovka_lycee_socle_absent'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_a','starovka-rue-lycee-commissariat',
      ARRAY['starovka-rue-mairie-marche','starovka-rue-bureaux-caserne']::text[],
      '{"liens":{"droite":"starovka-rue-mairie-marche","gauche":"starovka-rue-bureaux-caserne"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-bureaux-caserne',
      ARRAY['starovka-rue-lycee-commissariat']::text[],
      '{"liens":{"droite":"starovka-rue-lycee-commissariat"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

  IF (SELECT count(*) FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
    AND ((noeud='starovka-rue-lycee-commissariat'
      AND directions->'liens'='{"droite":"starovka-rue-mairie-marche","gauche":"starovka-rue-bureaux-caserne"}'::jsonb)
      OR (noeud='starovka-rue-bureaux-caserne'
      AND directions->'liens'='{"droite":"starovka-rue-lycee-commissariat"}'::jsonb)))<>2
  THEN RAISE EXCEPTION 'starovka_bureaux_caserne_liens_invalides'; END IF;
END $starovka$;
