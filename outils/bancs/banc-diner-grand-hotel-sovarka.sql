-- A jouer APRES la migration 20261107093000, dans la meme transaction annulee.
-- A invite B (PJ) au restaurant du Grand Hotel de Sovarka : B accepte, A sert. Attendu : 100 PSK
-- payes par A, caisse du commerce +100, 2 menus imperiaux et 1 vin sortis du stock, +5 INF pour
-- chacun ; rejeu du service sans double effet ; hors du restaurant refus pas_sur_place.
DO $$
DECLARE a text; ua uuid; b text; ub uuid; r jsonb; inv bigint; q text := 'diner-'||gen_random_uuid()::text;
  liq0 numeric; liq1 numeric; s0 jsonb; s1 jsonb; inf0 numeric; inf1 numeric;
BEGIN
  SELECT name, user_id INTO a, ua FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 ORDER BY name LIMIT 1;
  SELECT name, user_id INTO b, ub FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 AND name <> a ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET country='soviet', current_city='capitale', current_building='hotel-republica',
    current_room='restaurant', pa=10, hospitalisation=NULL, liquide=greatest(coalesce(liquide,0),1000),
    resources=jsonb_set(coalesce(resources,'{}'::jsonb),'{inf}','50') WHERE name IN (a, b);
  SELECT liquide INTO liq0 FROM public.personnages_donnees WHERE name=a;
  SELECT data INTO s0 FROM public.entreprises WHERE id='brasserie-soviet-capitale-hotel-republica';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.restaurant_diner_creer(q, b, false, 'test');
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'prix')::int <> 100 THEN RAISE EXCEPTION 'creer: %', r; END IF;
  inv := (r->>'id')::bigint;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.restaurant_diner_repondre(inv, true, 'oui');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'repondre: %', r; END IF;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/restaurant_diner_servir', true);  -- sinon la fusion des jauges ecarte l'INF
  SET LOCAL ROLE authenticated;
  r := public.restaurant_diner_servir(inv);
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'total')::int <> 100 THEN RAISE EXCEPTION 'servir: %', r; END IF;
  r := public.restaurant_diner_servir(inv);
  IF (r->>'rejeu')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'rejeu: %', r; END IF;
  RESET ROLE;
  SELECT liquide, (resources->>'inf')::numeric INTO liq1, inf1 FROM public.personnages_donnees WHERE name=a;
  SELECT data INTO s1 FROM public.entreprises WHERE id='brasserie-soviet-capitale-hotel-republica';
  IF liq0 - liq1 <> 100 THEN RAISE EXCEPTION 'debit % au lieu de 100', liq0 - liq1; END IF;
  IF inf1 <> 55 THEN RAISE EXCEPTION 'inf A %', inf1; END IF;
  SELECT (resources->>'inf')::numeric INTO inf1 FROM public.personnages_donnees WHERE name=b;
  IF inf1 <> 55 THEN RAISE EXCEPTION 'inf B %', inf1; END IF;
  IF (s0->'stockProduits'->>'menu_sovarka_imperial')::int - (s1->'stockProduits'->>'menu_sovarka_imperial')::int <> 2
     OR (s0->'stockProduits'->>'vin')::int - (s1->'stockProduits'->>'vin')::int <> 1 THEN RAISE EXCEPTION 'stock % -> %', s0->'stockProduits', s1->'stockProduits'; END IF;
  UPDATE public.personnages_donnees SET current_room='bar' WHERE name=a;
  SET LOCAL ROLE authenticated;
  r := public.restaurant_diner_creer('diner-'||gen_random_uuid()::text, b, false, '');
  IF r->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'hors restaurant: %', r; END IF;
  RESET ROLE;
  RAISE NOTICE 'BANC OK : debit 100, INF +5 x2, stock -2 menus -1 vin, rejeu, hors lieu refuse ; caisse % -> %',
    s0->>'caisse', s1->>'caisse';
END $$;
