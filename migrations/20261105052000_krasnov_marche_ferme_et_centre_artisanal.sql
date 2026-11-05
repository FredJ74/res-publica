-- Krasnov : trajet terrains -> marché fermé, retour et sortie vers centre artisanal.
-- Image du marché fermée présente en dépôt, aucune autre flèche inventée.
DO $krasnov$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-terrains')
 THEN RAISE EXCEPTION 'krasnov_terrains_introuvable'; END IF;

 INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
 VALUES ('soviet','ville_b','krasnov-rue-marche-ferme',
         ARRAY['krasnov-rue-terrains','krasnov-centre-artisanal']::text[],
         '{"liens":{"gauche":"krasnov-rue-terrains","droite":"krasnov-centre-artisanal"},"parArrivee":{}}'::jsonb)
 ON CONFLICT(country,city,noeud) DO UPDATE SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

 INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
 VALUES ('soviet','ville_b','krasnov-centre-artisanal','{}'::text[],
         '{"liens":{},"parArrivee":{}}'::jsonb)
 ON CONFLICT(country,city,noeud) DO NOTHING;

 UPDATE public.rue_noeuds_serveur
 SET voisins=ARRAY['krasnov-rue-maison','krasnov-rue-eglise','krasnov-rue-marche-ferme']::text[],
     directions='{"liens":{"gauche":"krasnov-rue-maison","toutDroit":"krasnov-rue-eglise","droite":"krasnov-rue-marche-ferme"},"parArrivee":{}}'::jsonb
 WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-terrains';

 IF NOT EXISTS(
   SELECT 1 FROM public.rue_noeuds_serveur
   WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-terrains'
     AND voisins=ARRAY['krasnov-rue-maison','krasnov-rue-eglise','krasnov-rue-marche-ferme']::text[]
     AND directions->'liens'='{"gauche":"krasnov-rue-maison","toutDroit":"krasnov-rue-eglise","droite":"krasnov-rue-marche-ferme"}'::jsonb
 ) THEN RAISE EXCEPTION 'krasnov_terrains_non_conformes'; END IF;
 IF NOT EXISTS(
   SELECT 1 FROM public.rue_noeuds_serveur
   WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-marche-ferme'
     AND voisins=ARRAY['krasnov-rue-terrains','krasnov-centre-artisanal']::text[]
     AND directions->'liens'='{"gauche":"krasnov-rue-terrains","droite":"krasnov-centre-artisanal"}'::jsonb
 ) THEN RAISE EXCEPTION 'krasnov_marche_non_conforme'; END IF;
 IF NOT EXISTS(
   SELECT 1 FROM public.rue_noeuds_serveur
   WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-centre-artisanal'
     AND cardinality(voisins)=0 AND coalesce(directions->'liens','{}'::jsonb)='{}'::jsonb
 ) THEN RAISE EXCEPTION 'krasnov_artisanal_non_conforme'; END IF;
END $krasnov$;