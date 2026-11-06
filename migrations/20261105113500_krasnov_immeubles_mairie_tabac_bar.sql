-- Krasnov : immeubles/centre commercial -> mairie -> tabac-bar, avec retours.
-- Les directions de la rue tabac-bar restent volontairement vides.
DO $krasnov$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-immeubles-centre-commercial'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-distillerie-radar'
  ) THEN RAISE EXCEPTION 'krasnov_rues_immeubles_ou_distillerie_absentes'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_b','krasnov-rue-mairie-place',
      ARRAY['krasnov-rue-immeubles-centre-commercial','krasnov-rue-tabac-bar']::text[],
      '{"liens":{"arriere":"krasnov-rue-immeubles-centre-commercial","toutDroit":"krasnov-rue-tabac-bar"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_b','krasnov-rue-tabac-bar','{}'::text[],
      '{"liens":{},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO NOTHING;

  UPDATE public.rue_noeuds_serveur
  SET voisins=ARRAY['krasnov-rue-distillerie-radar','krasnov-rue-mairie-place']::text[],
      directions='{"liens":{"arriere":"krasnov-rue-distillerie-radar","toutDroit":"krasnov-rue-mairie-place"},"parArrivee":{}}'::jsonb
  WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-immeubles-centre-commercial';

  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-immeubles-centre-commercial'
      AND voisins=ARRAY['krasnov-rue-distillerie-radar','krasnov-rue-mairie-place']::text[]
      AND directions->'liens'='{"arriere":"krasnov-rue-distillerie-radar","toutDroit":"krasnov-rue-mairie-place"}'::jsonb
  ) THEN RAISE EXCEPTION 'krasnov_immeubles_liens_invalides'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-mairie-place'
      AND voisins=ARRAY['krasnov-rue-immeubles-centre-commercial','krasnov-rue-tabac-bar']::text[]
      AND directions->'liens'='{"arriere":"krasnov-rue-immeubles-centre-commercial","toutDroit":"krasnov-rue-tabac-bar"}'::jsonb
  ) THEN RAISE EXCEPTION 'krasnov_mairie_liens_invalides'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-tabac-bar'
      AND cardinality(voisins)=0 AND coalesce(directions->'liens','{}'::jsonb)='{}'::jsonb
  ) THEN RAISE EXCEPTION 'krasnov_tabac_directions_non_validees'; END IF;
END $krasnov$;