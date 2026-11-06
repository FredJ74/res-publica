-- Krasnov : rue tabac-bar -> mairie (bas), station/musée (haut).
-- La vue station/musée n'a encore aucune direction validée.
DO $krasnov$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-tabac-bar'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-mairie-place'
  ) THEN RAISE EXCEPTION 'krasnov_tabac_ou_mairie_absents'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES ('soviet','ville_b','krasnov-rue-station-musee','{}'::text[],
          '{"liens":{},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO NOTHING;

  UPDATE public.rue_noeuds_serveur
  SET voisins=ARRAY['krasnov-rue-mairie-place','krasnov-rue-station-musee']::text[],
      directions='{"liens":{"arriere":"krasnov-rue-mairie-place","toutDroit":"krasnov-rue-station-musee"},"parArrivee":{}}'::jsonb
  WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-tabac-bar';

  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-tabac-bar'
      AND voisins=ARRAY['krasnov-rue-mairie-place','krasnov-rue-station-musee']::text[]
      AND directions->'liens'='{"arriere":"krasnov-rue-mairie-place","toutDroit":"krasnov-rue-station-musee"}'::jsonb
  ) THEN RAISE EXCEPTION 'krasnov_tabac_liens_invalides'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-station-musee'
      AND cardinality(voisins)=0 AND coalesce(directions->'liens','{}'::jsonb)='{}'::jsonb
  ) THEN RAISE EXCEPTION 'krasnov_station_musee_directions_non_validees'; END IF;
END $krasnov$;