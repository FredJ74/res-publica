-- Banc annulé : terrains de PSM par onglets (migration 20261104190000). Joué le 04/11 avant application : BANC_VERT (1 PJ concerné).
BEGIN;
INSERT INTO public.rue_sorties_batiments(country,city,noeud,building) VALUES
  ('republic','ville_a','psm-terrains-vente','terrain-a-batir-8'),
  ('republic','ville_a','psm-terrains-vente','terrain-a-batir-9'),
  ('republic','ville_a','psm-terrains-vente','terrain-a-batir-10'),
  ('republic','ville_a','psm-terrains-vente','terrain-a-batir-11')
ON CONFLICT DO NOTHING;

DELETE FROM public.rue_sorties_batiments
WHERE country='republic' AND city='ville_a' AND noeud='psm-terrains-lots'
  AND building IN ('terrain-a-batir-8','terrain-a-batir-9','terrain-a-batir-10','terrain-a-batir-11');

DO $$
BEGIN
  IF (SELECT count(*) FROM public.rue_sorties_batiments WHERE country='republic' AND city='ville_a'
      AND building IN ('terrain-a-batir-8','terrain-a-batir-9','terrain-a-batir-10','terrain-a-batir-11')) <> 4
     OR EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country='republic' AND city='ville_a'
      AND building LIKE 'terrain-a-batir-%' AND noeud<>'psm-terrains-vente') THEN
    RAISE EXCEPTION 'psm_terrains_sorties_incoherentes';
  END IF;
END $$;
DO $$
DECLARE r jsonb;
BEGIN
  r := public.navigation_rue_trajet_interne('republic','ville_a','terrain-a-batir-9',NULL,'psm-terrains-vente');
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'sortie vente refusee %', r; END IF;
  r := public.navigation_rue_trajet_interne('republic','ville_a','terrain-a-batir-9',NULL,'psm-terrains-lots');
  IF coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'sortie lots acceptee %', r; END IF;
  r := public.navigation_rue_trajet_interne('republic','ville_a',NULL,'psm-terrains-lots','psm-terrains-vente');
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'retour lots->vente refuse %', r; END IF;
  RAISE EXCEPTION 'BANC_VERT';
END $$;
ROLLBACK;
