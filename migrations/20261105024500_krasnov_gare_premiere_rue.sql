-- Krasnov : première rue extérieure devant la gare. Aucun déplacement latéral déclaré.
-- Le serveur fait foi : sortie du hall -> krasnov-rue-gare, sans raccourci vers une autre ville.
DO $krasnov$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='ville_b'
      AND batiment='centre-multinodal-montrouge'
      AND pieces ? 'hall_gare_montrouge'
  ) THEN RAISE EXCEPTION 'krasnov_hall_gare_non_reference'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES ('soviet','ville_b','krasnov-rue-gare','{}'::text[],
          '{"liens":{},"parArrivee":{}}'::jsonb)
  ON CONFLICT (country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins,
        directions=EXCLUDED.directions;

  INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
  VALUES ('soviet','ville_b','krasnov-rue-gare','centre-multinodal-montrouge')
  ON CONFLICT DO NOTHING;

  IF NOT EXISTS (
    SELECT 1 FROM public.rue_sorties_batiments
    WHERE country='soviet' AND city='ville_b'
      AND noeud='krasnov-rue-gare'
      AND building='centre-multinodal-montrouge'
  ) THEN RAISE EXCEPTION 'krasnov_sortie_gare_non_referencee'; END IF;
END $krasnov$;