-- Starovka : liens tenus par le serveur et sortie du hall de gare.
DO $starovka$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
      WHERE pays='soviet' AND ville='ville_a'
        AND batiment='centre-multinodal-montrouge'
        AND pieces ? 'hall_gare_montrouge')
  THEN RAISE EXCEPTION 'starovka_hall_gare_non_reference'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_a','starovka-rue-gare',
      ARRAY['starovka-rue-port-industriel','starovka-rue-hotel']::text[],
      '{"liens":{"toutDroit":"starovka-rue-port-industriel","arriere":"starovka-rue-hotel"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-hotel',
      ARRAY['starovka-rue-gare','starovka-maisons-ferme']::text[],
      '{"liens":{"toutDroit":"starovka-rue-gare","arriere":"starovka-maisons-ferme"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-maisons-ferme',
      ARRAY['starovka-rue-hotel']::text[],
      '{"liens":{"toutDroit":"starovka-rue-hotel"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

  INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
  VALUES ('soviet','ville_a','starovka-rue-gare','centre-multinodal-montrouge')
  ON CONFLICT DO NOTHING;
  IF NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments
      WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-gare'
        AND building='centre-multinodal-montrouge')
  THEN RAISE EXCEPTION 'starovka_sortie_gare_non_referencee'; END IF;
END $starovka$;
