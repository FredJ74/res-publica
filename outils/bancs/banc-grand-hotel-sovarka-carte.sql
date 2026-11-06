-- Banc annulé de la migration 20261106213500 (carte du Grand Hôtel de Sovarka). Attendu : erreur 'banc_ok'.
BEGIN;
INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, prix_fixe, categorie,
  types_autorises, pays_autorises, villes_autorisees, buildings_autorises, effets, image, intermediaires) VALUES
  ('menu_sovarka_imperial', 'alimentaire',
   'Menu Impérial — Caviar Beluga sur blinis et crème fraîche, Esturgeon braisé au champagne, Charlotte russe',
   3, 5, '{"poisson": 2, "cereales": 1}'::jsonb, 40, 'menu',
   '["brasserie"]'::jsonb, '["soviet"]'::jsonb, '["capitale"]'::jsonb, '["hotel-republica"]'::jsonb,
   '{"hp": 10, "moral": 1, "paDiffere": 3}'::jsonb, NULL, '{}'::jsonb),
  ('menu_sovarka_tsars', 'alimentaire',
   'Menu des Tsars — Bortsch impérial et ses pirojki, Bœuf Stroganoff, Pavlova aux fruits rouges',
   3, 5, '{"viande": 1, "fruits_legumes": 1, "cereales": 1}'::jsonb, 40, 'menu',
   '["brasserie"]'::jsonb, '["soviet"]'::jsonb, '["capitale"]'::jsonb, '["hotel-republica"]'::jsonb,
   '{"hp": 10, "moral": 1, "paDiffere": 3}'::jsonb, NULL, '{}'::jsonb),
  ('menu_sovarka_plan', 'alimentaire',
   'Menu du Plan — Salade Olivier des banquets officiels, Pelmenis fabriqués selon les quotas, Paskha au fromage blanc',
   3, 5, '{"viande": 1, "cereales": 1, "fruits_legumes": 1}'::jsonb, 40, 'menu',
   '["brasserie"]'::jsonb, '["soviet"]'::jsonb, '["capitale"]'::jsonb, '["hotel-republica"]'::jsonb,
   '{"hp": 10, "moral": 1, "paDiffere": 3}'::jsonb, NULL, '{}'::jsonb)
ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, pa = EXCLUDED.pa, portions = EXCLUDED.portions,
  materiaux = EXCLUDED.materiaux, prix_fixe = EXCLUDED.prix_fixe, categorie = EXCLUDED.categorie,
  types_autorises = EXCLUDED.types_autorises, pays_autorises = EXCLUDED.pays_autorises,
  villes_autorisees = EXCLUDED.villes_autorisees, buildings_autorises = EXCLUDED.buildings_autorises,
  effets = EXCLUDED.effets;

-- Le restaurant du Grand Hôtel : les trois menus russes remplacent les trois menus de Républia
-- (carte, plafonds de stock, prix), le reste de la carte et l'état du commerce sont conservés.
UPDATE public.entreprises e SET data = jsonb_set(jsonb_set(jsonb_set(e.data,
    '{carte}', (SELECT jsonb_agg(CASE x WHEN 'menu_gastronomique_1' THEN 'menu_sovarka_imperial'
                                         WHEN 'menu_gastronomique_2' THEN 'menu_sovarka_tsars'
                                         WHEN 'menu_gastronomique_3' THEN 'menu_sovarka_plan' ELSE x END ORDER BY o)
                FROM jsonb_array_elements_text(e.data->'carte') WITH ORDINALITY t(x, o))),
    '{parametres,stockMax}', (coalesce(e.data#>'{parametres,stockMax}', '{}'::jsonb)
       - 'menu_gastronomique_1' - 'menu_gastronomique_2' - 'menu_gastronomique_3')
       || '{"menu_sovarka_imperial": 20, "menu_sovarka_tsars": 20, "menu_sovarka_plan": 20}'::jsonb, true),
    '{parametres,prixVente}', (coalesce(e.data#>'{parametres,prixVente}', '{}'::jsonb)
       - 'menu_gastronomique_1' - 'menu_gastronomique_2' - 'menu_gastronomique_3')
       || '{"menu_sovarka_imperial": 40, "menu_sovarka_tsars": 40, "menu_sovarka_plan": 40}'::jsonb, true)
WHERE e.id = 'brasserie-soviet-capitale-hotel-republica';

DO $$
DECLARE d jsonb;
BEGIN
  SELECT data INTO d FROM public.entreprises WHERE id = 'brasserie-soviet-capitale-hotel-republica';
  IF (SELECT count(*) FROM public.recettes_commerce WHERE id LIKE 'menu_sovarka_%' AND pays_autorises = '["soviet"]'::jsonb) <> 3
     OR d IS NULL OR d->'carte' ?| ARRAY['menu_gastronomique_1','menu_gastronomique_2','menu_gastronomique_3']
     OR NOT d->'carte' ?& ARRAY['menu_sovarka_imperial','menu_sovarka_tsars','menu_sovarka_plan']
     OR (d#>>'{parametres,prixVente,menu_sovarka_plan}')::int <> 40
     OR (SELECT pays_autorises FROM public.recettes_commerce WHERE id = 'menu_gastronomique_1') <> '["republic"]'::jsonb THEN
    RAISE EXCEPTION 'grand_hotel_sovarka_carte_incomplete';
  END IF;
END $$;
DO $$ BEGIN RAISE EXCEPTION 'banc_ok'; END $$;
ROLLBACK;
