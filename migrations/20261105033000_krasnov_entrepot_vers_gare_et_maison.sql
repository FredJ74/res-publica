-- Krasnov : rue de l'entrepôt : deux sorties uniquement.
-- Haut aux deux tiers -> gare ; droite tout en bas -> rue des maisons.
-- La rue des maisons ne reçoit aucune flèche tant que le game designer ne les a pas précisées.
DO $krasnov$
BEGIN
  IF NOT EXISTS(
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-entrepot'
  ) OR NOT EXISTS(
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-gare'
  ) THEN RAISE EXCEPTION 'krasnov_graphe_incomplet'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES ('soviet','ville_b','krasnov-rue-maison','{}'::text[],
          '{"liens":{},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO NOTHING;

  UPDATE public.rue_noeuds_serveur
  SET voisins=ARRAY['krasnov-rue-gare','krasnov-rue-maison']::text[],
      directions='{"liens":{"toutDroit":"krasnov-rue-gare","droite":"krasnov-rue-maison"},"parArrivee":{}}'::jsonb
  WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-entrepot';

  IF NOT EXISTS(
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-entrepot'
      AND voisins=ARRAY['krasnov-rue-gare','krasnov-rue-maison']::text[]
      AND directions->'liens'='{"toutDroit":"krasnov-rue-gare","droite":"krasnov-rue-maison"}'::jsonb
  ) THEN RAISE EXCEPTION 'krasnov_entrepot_liens_non_conformes'; END IF;

  IF NOT EXISTS(
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-maison'
      AND cardinality(voisins)=0 AND coalesce(directions->'liens','{}'::jsonb)='{}'::jsonb
  ) THEN RAISE EXCEPTION 'krasnov_rue_maison_direction_inattendue'; END IF;
END $krasnov$;