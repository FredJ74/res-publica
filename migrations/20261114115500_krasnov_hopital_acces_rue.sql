-- Krasnov : nouvelle rue de l'hôpital reliée à la rue des bureaux.
-- Déployer avec l'image Krasnov_hopital_rue.webp et le code client correspondant.
BEGIN;
DO $krasnov_hopital$
DECLARE v_source public.rue_noeuds_serveur%ROWTYPE;
BEGIN
 SELECT * INTO v_source FROM public.rue_noeuds_serveur
 WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-bureaux' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Rue du centre d’affaires de Krasnov absente'; END IF;
 IF NOT EXISTS (
   SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_b' AND batiment='dispensaire-public-v'
     AND NOT ferme AND pieces @> '["attente","ehpad","chambre"]'::jsonb
 ) THEN RAISE EXCEPTION 'Hôpital de Krasnov absent ou pièces incomplètes'; END IF;
 IF coalesce(v_source.directions->'liens'->>'droite','') NOT IN ('','krasnov-rue-hopital') THEN
   RAISE EXCEPTION 'Flèche droite de la rue des bureaux déjà occupée'; END IF;

 INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
 VALUES ('soviet','ville_b','krasnov-rue-hopital',ARRAY['krasnov-rue-bureaux']::text[],
    '{"liens":{"arriere":"krasnov-rue-bureaux"},"parArrivee":{}}'::jsonb)
 ON CONFLICT (country,city,noeud) DO UPDATE
 SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

 UPDATE public.rue_noeuds_serveur
 SET voisins=CASE WHEN voisins @> ARRAY['krasnov-rue-hopital']::text[] THEN voisins
                  ELSE array_append(voisins,'krasnov-rue-hopital') END,
     directions=jsonb_set(coalesce(directions,'{"liens":{}}'::jsonb),
                 '{liens,droite}','"krasnov-rue-hopital"'::jsonb,true)
 WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-bureaux';

 INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
 VALUES ('soviet','ville_b','krasnov-rue-hopital','dispensaire-public-v')
 ON CONFLICT DO NOTHING;

 IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND city='ville_b'
      AND noeud='krasnov-rue-bureaux' AND voisins @> ARRAY['krasnov-rue-hopital']::text[]
      AND directions->'liens'->>'droite'='krasnov-rue-hopital')
 OR NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND city='ville_b'
      AND noeud='krasnov-rue-hopital' AND voisins=ARRAY['krasnov-rue-bureaux']::text[]
      AND directions->'liens'->>'arriere'='krasnov-rue-bureaux')
 OR (SELECT count(*) FROM public.rue_sorties_batiments WHERE country='soviet' AND city='ville_b'
      AND noeud='krasnov-rue-hopital' AND building='dispensaire-public-v')<>1
 THEN RAISE EXCEPTION 'Raccordement de la rue hospitalière incomplet'; END IF;
END
$krasnov_hopital$;
COMMIT;
