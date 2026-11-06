-- Krasnov : une seule direction depuis la gare (bas -> rue de l'entrepôt).
-- Aucun trajet retour, autre flèche, hotspot ou modification de personnage n'est ajouté.
DO $krasnov$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b'
      AND noeud='krasnov-rue-gare'
  ) THEN RAISE EXCEPTION 'krasnov_gare_absente'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES ('soviet','ville_b','krasnov-rue-entrepot','{}'::text[],
          '{"liens":{},"parArrivee":{}}'::jsonb)
  ON CONFLICT (country,city,noeud) DO NOTHING;

  UPDATE public.rue_noeuds_serveur
     SET voisins = ARRAY['krasnov-rue-entrepot']::text[],
         directions = '{"liens":{"arriere":"krasnov-rue-entrepot"},"parArrivee":{}}'::jsonb
   WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-gare';

  IF NOT EXISTS(
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-gare'
      AND voisins=ARRAY['krasnov-rue-entrepot']::text[]
      AND directions->'liens'='{"arriere":"krasnov-rue-entrepot"}'::jsonb
  ) THEN RAISE EXCEPTION 'krasnov_liaison_gare_entrepot_absente'; END IF;
END $krasnov$;