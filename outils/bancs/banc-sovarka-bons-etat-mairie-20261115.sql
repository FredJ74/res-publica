-- Banc annule : bons d'Etat au guichet des mairies de Sovarka (a jouer concatene derriere la migration
-- 20261115170000, sans BEGIN/COMMIT). Arnie (PJ de Sovarka) est deplace le temps du banc ; tout est annule.
DO $banc$
DECLARE u uuid; r jsonb; t0 numeric; t1 numeric;
BEGIN
  SELECT user_id INTO u FROM public.personnages WHERE name = 'Arnie';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  -- Ancienne banque nationale de Novomirsk : refus
  UPDATE public.personnages_donnees SET current_city = 'capitale', current_building = 'banque-nationale', current_room = 'accueil_banque' WHERE name = 'Arnie';
  SET LOCAL ROLE authenticated; r := public.sovarka_bon_etat_souscrire('banc-mairie-0', 10); RESET ROLE;
  IF r->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'banque encore acceptee: %', r; END IF;
  -- Ancienne banque locale de Starovka : refus
  UPDATE public.personnages_donnees SET current_city = 'ville_a', current_building = 'banque-locale', current_room = 'guichet' WHERE name = 'Arnie';
  SET LOCAL ROLE authenticated; r := public.sovarka_bon_etat_souscrire('banc-mairie-00', 10); RESET ROLE;
  IF r->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'banque locale encore acceptee: %', r; END IF;
  -- Mairie de Novomirsk, de Starovka, de Krasnov : acceptee, Tresor credite
  SELECT coalesce((data->>'reserveJour')::numeric, 0) INTO t0 FROM public.budgets_nationaux WHERE id = 'soviet';
  UPDATE public.personnages_donnees SET current_city = 'capitale', current_building = 'mairie-capitale', current_room = 'hall_mairie' WHERE name = 'Arnie';
  SET LOCAL ROLE authenticated; r := public.sovarka_bon_etat_souscrire('banc-mairie-1', 10); RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'mairie de Novomirsk refusee: %', r; END IF;
  UPDATE public.personnages_donnees SET current_city = 'ville_a', current_building = 'mairie', current_room = 'accueil_mairie' WHERE name = 'Arnie';
  SET LOCAL ROLE authenticated; r := public.sovarka_bon_etat_souscrire('banc-mairie-2', 10); RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'mairie de Starovka refusee: %', r; END IF;
  UPDATE public.personnages_donnees SET current_city = 'ville_b' WHERE name = 'Arnie';
  SET LOCAL ROLE authenticated; r := public.sovarka_bon_etat_souscrire('banc-mairie-3', 10); RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'mairie de Krasnov refusee: %', r; END IF;
  SELECT coalesce((data->>'reserveJour')::numeric, 0) INTO t1 FROM public.budgets_nationaux WHERE id = 'soviet';
  IF t1 - t0 <> 30 THEN RAISE EXCEPTION 'tresor: % -> %', t0, t1; END IF;
  IF (SELECT array_agg(ville ORDER BY requete) FROM public.sovarka_bons_etat WHERE requete LIKE 'banc-mairie-%') <> ARRAY['capitale','ville_a','ville_b'] THEN RAISE EXCEPTION 'villes'; END IF;
  RAISE EXCEPTION 'banc_ok';
END $banc$;
