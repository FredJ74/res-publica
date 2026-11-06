-- Krasnov : centre artisanal -> stade/commissariat -> école/forêt -> distillerie/radar.
-- Ne modifie aucun autre noeud ni les destinations encore non définies.
DO $krasnov$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-centre-artisanal'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-marche-ferme'
  ) THEN RAISE EXCEPTION 'krasnov_artisanal_ou_marche_absent'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_b','krasnov-rue-stade-commissariat',
      ARRAY['krasnov-centre-artisanal','krasnov-rue-ecole-foret']::text[],
      '{"liens":{"arriere":"krasnov-centre-artisanal","toutDroit":"krasnov-rue-ecole-foret"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_b','krasnov-rue-ecole-foret',
      ARRAY['krasnov-rue-stade-commissariat','krasnov-rue-distillerie-radar']::text[],
      '{"liens":{"arriere":"krasnov-rue-stade-commissariat","toutDroit":"krasnov-rue-distillerie-radar"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_b','krasnov-rue-distillerie-radar',
      '{}'::text[],'{"liens":{},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

  UPDATE public.rue_noeuds_serveur
     SET voisins=ARRAY['krasnov-rue-marche-ferme','krasnov-rue-stade-commissariat']::text[],
         directions='{"liens":{"gauche":"krasnov-rue-marche-ferme","toutDroit":"krasnov-rue-stade-commissariat"},"parArrivee":{}}'::jsonb
   WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-centre-artisanal';

  IF (
    SELECT COUNT(*)
    FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b'
      AND (
       (noeud='krasnov-centre-artisanal' AND voisins=ARRAY['krasnov-rue-marche-ferme','krasnov-rue-stade-commissariat']::text[] AND directions->'liens'='{"gauche":"krasnov-rue-marche-ferme","toutDroit":"krasnov-rue-stade-commissariat"}'::jsonb)
       OR (noeud='krasnov-rue-stade-commissariat' AND voisins=ARRAY['krasnov-centre-artisanal','krasnov-rue-ecole-foret']::text[] AND directions->'liens'='{"arriere":"krasnov-centre-artisanal","toutDroit":"krasnov-rue-ecole-foret"}'::jsonb)
       OR (noeud='krasnov-rue-ecole-foret' AND voisins=ARRAY['krasnov-rue-stade-commissariat','krasnov-rue-distillerie-radar']::text[] AND directions->'liens'='{"arriere":"krasnov-rue-stade-commissariat","toutDroit":"krasnov-rue-distillerie-radar"}'::jsonb)
       OR (noeud='krasnov-rue-distillerie-radar' AND cardinality(voisins)=0 AND coalesce(directions->'liens','{}'::jsonb)='{}'::jsonb)
      )
  ) <> 4 THEN RAISE EXCEPTION 'krasnov_quatre_noeuds_non_conformes'; END IF;
END $krasnov$;