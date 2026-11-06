-- Krasnov : terrains -> maisons (gauche), terrains -> église (haut).
-- Marché fermé : emplacement préparé côté client, mais aucune entrée serveur
-- avant la livraison de son image. Ne pas exposer une destination cassée.
DO $krasnov$
BEGIN
  IF NOT EXISTS(
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-terrains'
  ) OR NOT EXISTS(
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-maison'
  ) THEN RAISE EXCEPTION 'krasnov_terrains_ou_maisons_absents'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES ('soviet','ville_b','krasnov-rue-eglise','{}'::text[],
          '{"liens":{},"parArrivee":{}}'::jsonb)
  ON CONFLICT (country,city,noeud) DO NOTHING;

  UPDATE public.rue_noeuds_serveur
  SET voisins=ARRAY['krasnov-rue-maison','krasnov-rue-eglise']::text[],
      directions='{"liens":{"gauche":"krasnov-rue-maison","toutDroit":"krasnov-rue-eglise"},"parArrivee":{}}'::jsonb
  WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-terrains';

  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-terrains'
      AND voisins=ARRAY['krasnov-rue-maison','krasnov-rue-eglise']::text[]
      AND directions->'liens'='{"gauche":"krasnov-rue-maison","toutDroit":"krasnov-rue-eglise"}'::jsonb
  ) THEN RAISE EXCEPTION 'krasnov_terrains_liens_invalides'; END IF;

  IF EXISTS(
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-marche-ferme'
  ) THEN RAISE EXCEPTION 'krasnov_marche_ferme_non_livre'; END IF;
END $krasnov$;