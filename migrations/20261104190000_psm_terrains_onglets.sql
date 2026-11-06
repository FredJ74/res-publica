-- Terrains à bâtir de Port-Sainte-Marie par onglets (Claude, 04/11/2026, décision de Fred).
-- Les quatre terrains (-8 à -11) ne s'ouvrent plus depuis la sous-scène psm-terrains-lots
-- (sélection sur l'image) mais par onglets depuis psm-terrains-vente, comme à Montrouge.
-- Entrée et sortie des terrains déplacées sur ce nœud. Idempotente ; ne déplace personne :
-- un PJ resté sur psm-terrains-lots revient en arrière par la flèche existante.
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
