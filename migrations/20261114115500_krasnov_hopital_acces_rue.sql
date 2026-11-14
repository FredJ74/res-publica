-- Krasnov : rue propre à l'hôpital public, raccordée depuis la place de la mairie.
-- Cette migration doit être lancée uniquement après présence de la scène cliente et
-- de son image WebP, pour ne pas proposer une direction vers un décor introuvable.
-- Ne touche ni aux personnages ni aux chambres ni aux autres villes.
BEGIN;
DO $krasnov_hopital$
DECLARE v_mairie public.rue_noeuds_serveur%ROWTYPE;
BEGIN
 SELECT * INTO v_mairie FROM public.rue_noeuds_serveur
 WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-mairie-place' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Rue de la mairie de Krasnov absente'; END IF;
 IF NOT EXISTS (
   SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_b' AND batiment='dispensaire-public-v'
     AND NOT ferme AND pieces @> '["attente","ehpad","chambre"]'::jsonb
 ) THEN RAISE EXCEPTION 'Hôpital de Krasnov absent ou pièces incomplètes'; END IF;

 INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
 VALUES ('soviet','ville_b','krasnov-rue-hopital',
         ARRAY['krasnov-rue-mairie-place']::text[],
         '{"liens":{"arriere":"krasnov-rue-mairie-place"},"parArrivee":{}}'::jsonb)
 ON CONFLICT (country,city,noeud) DO UPDATE
   SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

 UPDATE public.rue_noeuds_serveur
 SET voisins = CASE WHEN voisins @> ARRAY['krasnov-rue-hopital']::text[] THEN voisins
                    ELSE array_append(voisins,'krasnov-rue-hopital') END,
     directions = jsonb_set(coalesce(directions,'{}'::jsonb),
               '{liens,gauche}','"krasnov-rue-hopital"'::jsonb,true)
 WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-mairie-place';

 INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
 VALUES ('soviet','ville_b','krasnov-rue-hopital','dispensaire-public-v')
 ON CONFLICT DO NOTHING;

 IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND city='ville_b'
      AND noeud='krasnov-rue-mairie-place' AND voisins @> ARRAY['krasnov-rue-hopital']::text[]
      AND directions->'liens'->>'gauche'='krasnov-rue-hopital')
 OR NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND city='ville_b'
      AND noeud='krasnov-rue-hopital' AND voisins=ARRAY['krasnov-rue-mairie-place']::text[]
      AND directions->'liens'->>'arriere'='krasnov-rue-mairie-place')
 OR (SELECT count(*) FROM public.rue_sorties_batiments WHERE country='soviet' AND city='ville_b'
      AND noeud='krasnov-rue-hopital' AND building='dispensaire-public-v')<>1
 THEN RAISE EXCEPTION 'Raccordement de la rue de l’hôpital de Krasnov incomplet'; END IF;
END
$krasnov_hopital$;
COMMIT;
