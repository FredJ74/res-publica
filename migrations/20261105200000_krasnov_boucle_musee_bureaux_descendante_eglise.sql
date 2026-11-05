-- Krasnov : boucle musée -> bureaux -> rue descendante -> église.
-- Les flèches retour respectent les voies déjà validées, pas de déplacement libre.
DO $krasnov$
BEGIN
 IF NOT EXISTS (
   SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-station-musee'
 ) OR NOT EXISTS (
   SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-eglise'
 ) THEN RAISE EXCEPTION 'krasnov_musee_ou_eglise_absent'; END IF;
 INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
 VALUES
  ('soviet','ville_b','krasnov-rue-bureaux',
   ARRAY['krasnov-rue-station-musee','krasnov-rue-descendante']::text[],
   '{"liens":{"arriere":"krasnov-rue-station-musee","toutDroit":"krasnov-rue-descendante"},"parArrivee":{}}'::jsonb),
  ('soviet','ville_b','krasnov-rue-descendante',
   ARRAY['krasnov-rue-bureaux','krasnov-rue-eglise']::text[],
   '{"liens":{"arriere":"krasnov-rue-bureaux","toutDroit":"krasnov-rue-eglise"},"parArrivee":{}}'::jsonb)
 ON CONFLICT(country,city,noeud) DO UPDATE SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;
 UPDATE public.rue_noeuds_serveur
 SET voisins=ARRAY['krasnov-rue-tabac-bar','krasnov-rue-bureaux']::text[],
     directions='{"liens":{"arriere":"krasnov-rue-tabac-bar","toutDroit":"krasnov-rue-bureaux"},"parArrivee":{}}'::jsonb
 WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-station-musee';
 UPDATE public.rue_noeuds_serveur
 SET voisins=ARRAY['krasnov-rue-terrains','krasnov-rue-descendante']::text[],
     directions='{"liens":{"arriere":"krasnov-rue-terrains","droite":"krasnov-rue-descendante"},"parArrivee":{}}'::jsonb
 WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-eglise';
 IF (
   SELECT count(*) FROM public.rue_noeuds_serveur
   WHERE country='soviet' AND city='ville_b'
   AND (
     (noeud='krasnov-rue-station-musee'
      AND voisins=ARRAY['krasnov-rue-tabac-bar','krasnov-rue-bureaux']::text[]
      AND directions->'liens'='{"arriere":"krasnov-rue-tabac-bar","toutDroit":"krasnov-rue-bureaux"}'::jsonb)
     OR (noeud='krasnov-rue-bureaux'
      AND voisins=ARRAY['krasnov-rue-station-musee','krasnov-rue-descendante']::text[]
      AND directions->'liens'='{"arriere":"krasnov-rue-station-musee","toutDroit":"krasnov-rue-descendante"}'::jsonb)
     OR (noeud='krasnov-rue-descendante'
      AND voisins=ARRAY['krasnov-rue-bureaux','krasnov-rue-eglise']::text[]
      AND directions->'liens'='{"arriere":"krasnov-rue-bureaux","toutDroit":"krasnov-rue-eglise"}'::jsonb)
     OR (noeud='krasnov-rue-eglise'
      AND voisins=ARRAY['krasnov-rue-terrains','krasnov-rue-descendante']::text[]
      AND directions->'liens'='{"arriere":"krasnov-rue-terrains","droite":"krasnov-rue-descendante"}'::jsonb)
   )
 )<>4 THEN RAISE EXCEPTION 'krasnov_boucle_non_conforme'; END IF;
END $krasnov$;