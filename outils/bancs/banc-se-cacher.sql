-- A jouer APRES le corps de la migration 20261105103000, dans la meme transaction annulee.
-- BANC (annulé) : deux PJ réels dans la même pièce ; l'empoisonnement est refusé sans cachette,
-- la cachette est perdue en changeant de pièce, puis acceptée et consommée.
DO $$
DECLARE a text; ua uuid; b text; r jsonb; pa0 integer; essais integer := 0;
BEGIN
  SELECT name, user_id INTO a, ua FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0
    AND NOT EXISTS (SELECT 1 FROM public.detention_active(name)) ORDER BY name LIMIT 1;
  SELECT name INTO b FROM public.personnages_donnees WHERE user_id IS NOT NULL AND name <> a ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale', current_building='bourse-commerce',
    current_room='hall', pa = 20, hospitalisation = NULL,
    resources = jsonb_set(coalesce(resources,'{}'::jsonb), '{dis}', '100'::jsonb),
    inventory = coalesce(inventory,'[]'::jsonb) || '[{"id":"banc-poison","type":"poison","name":"Poison","poisonType":"parapluie"}]'::jsonb
   WHERE name = a;
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale', current_building='bourse-commerce', current_room='hall' WHERE name = b;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/crime_empoisonner', true);
  SET LOCAL ROLE authenticated;
  r := public.crime_empoisonner(b);
  IF r->>'raison' IS DISTINCT FROM 'pas_cache' THEN RAISE EXCEPTION 'sans cachette: %', r - 'inventory' - 'inventaire'; END IF;
  PERFORM set_config('request.path', '/rpc/se_cacher', true);
  LOOP
    essais := essais + 1;
    r := public.se_cacher();
    IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'se cacher: %', r; END IF;
    EXIT WHEN (r->>'cache')::boolean OR essais >= 8;
  END LOOP;
  IF NOT (r->>'cache')::boolean THEN RAISE EXCEPTION 'jamais cache en 8 essais: %', r; END IF;
  RESET ROLE;
  SELECT pa INTO pa0 FROM public.personnages_donnees WHERE name = a;
  IF pa0 <> 20 - essais THEN RAISE EXCEPTION 'PA: % apres % essais', pa0, essais; END IF;
  -- changer de pièce fait perdre la cachette
  UPDATE public.personnages_donnees SET current_room = 'autre' WHERE name = a;
  UPDATE public.personnages_donnees SET current_room = 'autre' WHERE name = b;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.path', '/rpc/crime_empoisonner', true);
  r := public.crime_empoisonner(b);
  IF r->>'raison' IS DISTINCT FROM 'pas_cache' THEN RAISE EXCEPTION 'autre piece: %', r - 'inventory' - 'inventaire'; END IF;
  RESET ROLE;
  UPDATE public.caches_pj SET piece = 'autre' WHERE personnage = a;
  SET LOCAL ROLE authenticated;
  r := public.crime_empoisonner(b);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'avec cachette: %', r - 'inventory' - 'inventaire'; END IF;
  RESET ROLE;
  IF EXISTS (SELECT 1 FROM public.caches_pj WHERE personnage = a) THEN RAISE EXCEPTION 'cachette non consommee'; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (% sur %, % essai(s))', a, b, essais;
END $$;
