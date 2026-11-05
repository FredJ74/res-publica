-- Krasnov : rue de l'église, retour bas vers les terrains.
-- Flèche droite en attente : sans image, ni destination ni autorisation serveur.
DO $krasnov$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-eglise'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-terrains'
  ) THEN RAISE EXCEPTION 'krasnov_eglise_ou_terrains_absents'; END IF;

  UPDATE public.rue_noeuds_serveur
  SET voisins=ARRAY['krasnov-rue-terrains']::text[],
      directions='{"liens":{"arriere":"krasnov-rue-terrains"},"parArrivee":{}}'::jsonb
  WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-eglise';

  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-eglise'
      AND voisins=ARRAY['krasnov-rue-terrains']::text[]
      AND directions->'liens'='{"arriere":"krasnov-rue-terrains"}'::jsonb
  ) THEN RAISE EXCEPTION 'krasnov_eglise_retour_non_conforme'; END IF;
END $krasnov$;