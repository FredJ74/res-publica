-- Krasnov : de la distillerie/radar, flèche basse vers école/forêt,
-- flèche haute vers immeubles/centre commercial ; aucune flèche inventée aux immeubles.
DO $krasnov$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-distillerie-radar'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-ecole-foret'
  ) THEN
    RAISE EXCEPTION 'krasnov_distillerie_ou_ecole_absente';
  END IF;

  INSERT INTO public.rue_noeuds_serveur (country,city,noeud,voisins,directions)
  VALUES ('soviet','ville_b','krasnov-rue-immeubles-centre-commercial',
          '{}'::text[],'{"liens":{},"parArrivee":{}}'::jsonb)
  ON CONFLICT (country,city,noeud) DO NOTHING;

  UPDATE public.rue_noeuds_serveur
  SET voisins=ARRAY['krasnov-rue-ecole-foret','krasnov-rue-immeubles-centre-commercial']::text[],
      directions='{"liens":{"arriere":"krasnov-rue-ecole-foret","toutDroit":"krasnov-rue-immeubles-centre-commercial"},"parArrivee":{}}'::jsonb
  WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-distillerie-radar';

  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b'
      AND noeud='krasnov-rue-distillerie-radar'
      AND voisins=ARRAY['krasnov-rue-ecole-foret','krasnov-rue-immeubles-centre-commercial']::text[]
      AND directions->'liens'='{"arriere":"krasnov-rue-ecole-foret","toutDroit":"krasnov-rue-immeubles-centre-commercial"}'::jsonb
  ) THEN RAISE EXCEPTION 'krasnov_distillerie_liens_non_conformes'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b'
      AND noeud='krasnov-rue-immeubles-centre-commercial'
      AND cardinality(voisins)=0
      AND coalesce(directions->'liens','{}'::jsonb)='{}'::jsonb
  ) THEN RAISE EXCEPTION 'krasnov_immeubles_directions_non_validees'; END IF;
END $krasnov$;