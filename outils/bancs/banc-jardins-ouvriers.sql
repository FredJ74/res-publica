-- A jouer APRES le corps de la migration 20261101040000, dans la meme transaction annulee.
-- BANC (annulé) : un PJ réel placé aux jardins le temps de la transaction.
DO $$
DECLARE n text; u uuid; r jsonb; q1 uuid := gen_random_uuid(); q2 uuid := gen_random_uuid();
  q3 uuid := gen_random_uuid(); avant integer; l integer[];
BEGIN
  SELECT name, user_id INTO n, u FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0
    AND NOT EXISTS (SELECT 1 FROM public.detention_active(name)) ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET country='republic', current_city='ville_b',
    current_building='jardins-ouvriers-montrouge', pa = greatest(coalesce(pa,0), 10), hospitalisation = NULL WHERE name = n;
  avant := (public.jardins_ouvriers_ligne_legumes((SELECT inventory FROM public.personnages_donnees WHERE name=n)))[2];
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/jardins_travailler', true);
  SET LOCAL ROLE authenticated;
  r := public.jardins_travailler(q1);
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'quantite')::int <> 5 THEN RAISE EXCEPTION 'travail: %', r - 'inventory'; END IF;
  r := public.jardins_travailler(q1);  -- rejeu de la même demande
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'rejeu: %', r; END IF;
  r := public.jardins_travailler(gen_random_uuid());
  IF r->>'raison' IS DISTINCT FROM 'deja_fait_aujourdhui' THEN RAISE EXCEPTION 'plafond: %', r - 'inventory'; END IF;
  PERFORM set_config('request.path', '/rpc/jardins_laisser_legumes', true);
  r := public.jardins_laisser_legumes(q2, 3);
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'reserve')::int < 3 THEN RAISE EXCEPTION 'laisser: %', r - 'inventory'; END IF;
  r := public.jardins_laisser_legumes(gen_random_uuid(), 100000);
  IF r->>'raison' IS DISTINCT FROM 'stock_insuffisant' THEN RAISE EXCEPTION 'laisser trop: %', r; END IF;
  PERFORM set_config('request.path', '/rpc/jardins_prendre_legumes', true);
  r := public.jardins_prendre_legumes(q3, 2);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'prendre: %', r - 'inventory'; END IF;
  RESET ROLE;
  l := public.jardins_ouvriers_ligne_legumes((SELECT inventory FROM public.personnages_donnees WHERE name=n));
  IF l[2] <> avant + 5 - 3 + 2 THEN RAISE EXCEPTION 'bilan legumes: avant % apres %', avant, l[2]; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (PJ %, legumes % -> %)', n, avant, l[2];
END $$;
