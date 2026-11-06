-- Grand Hôtel de Sovarka : stock de départ du restaurant (Claude, 06/11/2026). Le commerce n'avait
-- aucun produit prêt (rien à commander tant qu'un PJ n'avait pas cuisiné). Comme à Luthécia :
-- 10 de chaque menu russe, 15 de chaque boisson et du snack. Ne touche qu'un stock encore vide.
UPDATE public.entreprises SET data = jsonb_set(data, '{stockProduits}',
  '{"menu_sovarka_imperial": 10, "menu_sovarka_tsars": 10, "menu_sovarka_plan": 10, "vin": 15, "cafe_boisson": 15, "biere_pression": 15, "snack_buvette": 15}'::jsonb, true)
WHERE id = 'brasserie-soviet-capitale-hotel-republica'
  AND coalesce(data->'stockProduits', '{}'::jsonb) = '{}'::jsonb;

DO $$
BEGIN
  IF coalesce((SELECT (data#>>'{stockProduits,menu_sovarka_imperial}')::int FROM public.entreprises
               WHERE id = 'brasserie-soviet-capitale-hotel-republica'), 0) <= 0 THEN
    RAISE EXCEPTION 'grand_hotel_sovarka_stock_absent';
  END IF;
END $$;
