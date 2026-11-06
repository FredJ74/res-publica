-- A jouer APRES le corps de la migration 20261106172000, dans la meme transaction annulee.
-- BANC (annulé) : un PJ réel placé chez la marchande de poissons le temps de la transaction.
DO $$
DECLARE n text; u uuid; r jsonb; q1 uuid := gen_random_uuid(); caisse0 numeric; caisse1 numeric;
  liq0 numeric; liq1 numeric; rech0 int; rech1 int; ok_det boolean;
BEGIN
  SELECT name, user_id INTO n, u FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0
    AND NOT EXISTS (SELECT 1 FROM public.detention_active(name)) ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET country='soviet', current_city='capitale',
    current_building='poissonniere-novomirsk', pa = greatest(coalesce(pa,0), 10), hospitalisation = NULL,
    liquide = greatest(coalesce(liquide,0), 1000) WHERE name = n;
  SELECT (data->>'caisse')::numeric INTO caisse0 FROM public.entreprises WHERE id = 'poissonniere-soviet-capitale';
  SELECT liquide, coalesce(jsonb_array_length(recherche),0) INTO liq0, rech0 FROM public.personnages_donnees WHERE name = n;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/poissonniere_acheter_poisson', true);
  SET LOCAL ROLE authenticated;
  r := public.poissonniere_etat();
  IF (r->>'poisson_restant')::int <> 12 OR (r->>'prix_poisson')::int <> 3 THEN RAISE EXCEPTION 'etat: %', r; END IF;
  r := public.poissonniere_acheter_poisson(q1, 5);
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'paye')::int <> 15 OR (r->>'restant')::int <> 7 THEN RAISE EXCEPTION 'achat: %', r - 'inventory' - 'inventaire'; END IF;
  r := public.poissonniere_acheter_poisson(q1, 5);  -- rejeu : aucun second achat
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'rejeu: %', r - 'inventory' - 'inventaire'; END IF;
  r := public.poissonniere_acheter_poisson(gen_random_uuid(), 8);
  IF r->>'raison' IS DISTINCT FROM 'quota_insuffisant' OR (r->>'restant')::int <> 7 THEN RAISE EXCEPTION 'quota partiel: %', r; END IF;
  r := public.poissonniere_acheter_poisson(gen_random_uuid(), 7);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'fin du quota: %', r - 'inventory' - 'inventaire'; END IF;
  r := public.poissonniere_acheter_poisson(gen_random_uuid(), 1);
  IF r->>'raison' IS DISTINCT FROM 'quota_epuise' THEN RAISE EXCEPTION 'quota epuise: %', r; END IF;
  PERFORM set_config('request.path', '/rpc/poissonniere_acheter_contrebande', true);
  r := public.poissonniere_acheter_contrebande(gen_random_uuid(), 'tabac', 1);
  IF r->>'raison' IS DISTINCT FROM 'ressource_inconnue' THEN RAISE EXCEPTION 'cle: %', r; END IF;
  r := public.poissonniere_acheter_contrebande(gen_random_uuid(), 'medicaments', 4);
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'paye')::int <> 72 OR (r->>'restant')::int <> 6 THEN RAISE EXCEPTION 'contrebande: %', r - 'inventory' - 'inventaire'; END IF;
  ok_det := (r->>'detecte')::boolean;
  r := public.poissonniere_acheter_contrebande(gen_random_uuid(), 'alcool', 7);
  IF r->>'raison' IS DISTINCT FROM 'arrivage_insuffisant' THEN RAISE EXCEPTION 'arrivage: %', r; END IF;
  RESET ROLE;
  SELECT (data->>'caisse')::numeric INTO caisse1 FROM public.entreprises WHERE id = 'poissonniere-soviet-capitale';
  SELECT liquide, coalesce(jsonb_array_length(recherche),0) INTO liq1, rech1 FROM public.personnages_donnees WHERE name = n;
  IF caisse1 - caisse0 <> 36 THEN RAISE EXCEPTION 'caisse: % -> %', caisse0, caisse1; END IF;
  IF liq0 - liq1 <> 36 + 72 THEN RAISE EXCEPTION 'liquide: % -> %', liq0, liq1; END IF;
  IF ok_det AND rech1 <> rech0 + 1 THEN RAISE EXCEPTION 'recherche: % -> %', rech0, rech1; END IF;
  -- Hors de l'etal : refus nomme.
  UPDATE public.personnages_donnees SET current_building = 'marche' WHERE name = n;
  r := public.poissonniere_poisson_interne(n, 1);
  IF r->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'presence: %', r; END IF;
  RAISE EXCEPTION 'BANC_VERT detecte=% (% PJ)', ok_det, n;
END $$;
