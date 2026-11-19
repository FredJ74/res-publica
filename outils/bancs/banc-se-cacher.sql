-- A jouer seul (transaction annulée par l'exception finale). Mis à jour le 20/11/2026 (criminalité lots 1, 5 et 6).
-- BANC (annulé) : deux PJ réels dans la même pièce ; l'empoisonnement n'exige plus de cachette (lot 5, § 9 : la cachette
-- est un bonus), la cachette n'est plus consommée par la tentative, et elle se perd en changeant de pièce (§ 1).
-- Jets imposés (rp.crim_jets, session postgres) pour que l'empoisonnement échoue sans échec critique.
DO $$
DECLARE a text; ua uuid; b text; r jsonb; pa0 integer; essais integer := 0;
BEGIN
  SELECT name, user_id INTO a, ua FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0
    AND NOT EXISTS (SELECT 1 FROM public.detention_active(name)) ORDER BY name LIMIT 1;
  SELECT name INTO b FROM public.personnages_donnees WHERE user_id IS NOT NULL AND name <> a ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale', current_building='bourse-commerce',
    current_room='hall', pa = 20, hospitalisation = NULL,
    resources = jsonb_set(coalesce(resources,'{}'::jsonb), '{dis}', '100'::jsonb),
    inventory = coalesce(inventory,'[]'::jsonb)
      || '[{"id":"banc-poison-1","type":"poison","name":"Poison","poisonType":"parapluie"},{"id":"banc-poison-2","type":"poison","name":"Poison","poisonType":"parapluie"}]'::jsonb
   WHERE name = a;
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale', current_building='bourse-commerce', current_room='hall' WHERE name = b;
  PERFORM set_config('rp.crim_jets', '{"reussite": 97}', true);   -- échec ordinaire (ni critique ni réussite)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);

  -- 1. Sans cachette : la tentative a lieu (plus de refus « pas_cache »).
  r := public.crime_empoisonner(b, gen_random_uuid());
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'raison' = 'pas_cache' THEN RAISE EXCEPTION 'sans cachette: %', r - 'inventory'; END IF;

  -- 2. Se cacher (1 PA par essai), puis empoisonner depuis la cachette : elle n'est pas consommée.
  LOOP
    essais := essais + 1;
    r := public.se_cacher();
    IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'se cacher: %', r; END IF;
    EXIT WHEN (r->>'cache')::boolean OR essais >= 8;
  END LOOP;
  IF NOT (r->>'cache')::boolean THEN RAISE EXCEPTION 'jamais cache en 8 essais: %', r; END IF;
  SELECT pa INTO pa0 FROM public.personnages_donnees WHERE name = a;
  IF pa0 <> 20 - essais THEN RAISE EXCEPTION 'PA: % apres % essais', pa0, essais; END IF;
  r := public.crime_empoisonner(b, gen_random_uuid());
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'avec cachette: %', r - 'inventory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.caches_pj WHERE personnage = a) THEN RAISE EXCEPTION 'cachette consommee par l''empoisonnement'; END IF;

  -- 3. Changer de pièce fait perdre la cachette.
  UPDATE public.personnages_donnees SET current_room = 'autre' WHERE name = a;
  IF EXISTS (SELECT 1 FROM public.caches_pj WHERE personnage = a) THEN RAISE EXCEPTION 'cachette gardee hors de la piece'; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (% sur %, % essai(s))', a, b, essais;
END $$;
