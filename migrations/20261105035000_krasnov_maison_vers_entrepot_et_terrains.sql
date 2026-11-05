-- Krasnov : rue des maisons, flèche gauche vers l'entrepôt et droite vers les terrains.
-- La nouvelle vue des terrains n'a aucune sortie, en attente de l'arbitrage du game designer.
DO $krasnov$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
                WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-maison')
     OR NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
                WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-entrepot')
  THEN RAISE EXCEPTION 'krasnov_maison_entrepot_manquants'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES ('soviet','ville_b','krasnov-rue-terrains','{}'::text[],
          '{"liens":{},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO NOTHING;

  UPDATE public.rue_noeuds_serveur
  SET voisins=ARRAY['krasnov-rue-entrepot','krasnov-rue-terrains']::text[],
      directions='{"liens":{"gauche":"krasnov-rue-entrepot","droite":"krasnov-rue-terrains"},"parArrivee":{}}'::jsonb
  WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-maison';

  IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
     WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-maison'
       AND voisins=ARRAY['krasnov-rue-entrepot','krasnov-rue-terrains']::text[]
       AND directions->'liens'='{"gauche":"krasnov-rue-entrepot","droite":"krasnov-rue-terrains"}'::jsonb)
  THEN RAISE EXCEPTION 'krasnov_liens_maison_non_conformes'; END IF;

  IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
     WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-terrains'
       AND cardinality(voisins)=0 AND coalesce(directions->'liens','{}'::jsonb)='{}'::jsonb)
  THEN RAISE EXCEPTION 'krasnov_terrains_direction_non_validee'; END IF;
END $krasnov$;