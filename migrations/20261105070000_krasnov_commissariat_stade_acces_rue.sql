-- Krasnov : accès aux deux bâtiments depuis la rue stade / commissariat.
-- Réutilise les gabarits et pièces existants : aucune création d'ordre métier.
DO $krasnov$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b'
      AND noeud='krasnov-rue-stade-commissariat'
  ) THEN RAISE EXCEPTION 'krasnov_rue_stade_commissariat_absente'; END IF;

  IF (
    SELECT count(*) FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='ville_b'
      AND ((batiment='commissariat-local' AND pieces @> '["accueil_loc","geoles","bureau_commissaire"]'::jsonb)
        OR (batiment='stade' AND pieces @> '["terrain","vestiaires","buvette","guichet_paris","siege_supporters","bureau_president"]'::jsonb))
  ) <> 2 THEN RAISE EXCEPTION 'krasnov_gabarits_commissariat_stade_non_references'; END IF;

  INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
  VALUES
    ('soviet','ville_b','krasnov-rue-stade-commissariat','commissariat-local'),
    ('soviet','ville_b','krasnov-rue-stade-commissariat','stade')
  ON CONFLICT DO NOTHING;

  IF (
    SELECT count(*) FROM public.rue_sorties_batiments
    WHERE country='soviet' AND city='ville_b'
      AND noeud='krasnov-rue-stade-commissariat'
      AND building IN ('commissariat-local','stade')
  ) <> 2 THEN RAISE EXCEPTION 'krasnov_entrees_ou_sorties_non_referencees'; END IF;
END $krasnov$;