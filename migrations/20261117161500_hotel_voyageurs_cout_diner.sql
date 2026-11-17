-- Hôtel des Voyageurs de Starovka (17/11/2026) : tarif serveur du dîner d'affaires à 40 PSK (2 PA),
-- même ordre que les dîners existants (100, 150, 300). Miroir : baseline/seeds/95_a-regenerer/ordres_couts.sql.
BEGIN;
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'diner_affaires', 2, 40
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn='diner_affaires' AND pa=2 AND cost=40);
DO $$ BEGIN
  IF (SELECT count(*) FROM public.ordres_couts WHERE fn='diner_affaires' AND pa=2 AND cost=40) <> 1
  THEN RAISE EXCEPTION 'hotel_voyageurs_cout_diner : tarif absent ou doublé'; END IF;
END $$;
COMMIT;
