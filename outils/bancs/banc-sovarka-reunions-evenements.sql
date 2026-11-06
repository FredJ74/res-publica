-- A jouer APRES la migration 20261107020000, dans la meme transaction annulee.
-- A reserve la grande salle A, B y est present. Reseautage, seminaire, buffet, conference ;
-- rejeu de la meme requete sans double effet ; second reseautage refuse ; non-reservataire refuse.
DO $$
DECLARE a text; ua uuid; b text; ub uuid; r jsonb; q uuid := gen_random_uuid();
  infb0 numeric; infb1 numeric; pab0 int; pab1 int; popa0 numeric; popa1 numeric; liqa0 numeric; liqa1 numeric; effb jsonb;
BEGIN
  SELECT name, user_id INTO a, ua FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 ORDER BY name LIMIT 1;
  SELECT name, user_id INTO b, ub FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 AND name <> a ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET country='soviet', current_city='capitale', current_building='centre-affaires',
    current_room='reunion_grande_a', pa=10, hospitalisation=NULL, liquide=greatest(coalesce(liquide,0),1000),
    effets_actifs='[]'::jsonb, resources = jsonb_set(jsonb_set(coalesce(resources,'{}'::jsonb),'{pop}','50'),'{inf}','50')
   WHERE name IN (a, b);
  SELECT (resources->>'inf')::numeric, pa INTO infb0, pab0 FROM public.personnages_donnees WHERE name = b;
  SELECT (resources->>'pop')::numeric, liquide INTO popa0, liqa0 FROM public.personnages_donnees WHERE name = a;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_reunion_evenement(gen_random_uuid(), 'reunion_grande_a', 'reseautage');
  IF r->>'raison' IS DISTINCT FROM 'salle_non_reservee' THEN RAISE EXCEPTION 'non reservataire: %', r; END IF;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/sovarka_reunion_evenement', true);  -- sinon la fusion de POP ecarte l'ecriture
  SET LOCAL ROLE authenticated;
  r := public.sovarka_reunion_reserver('reunion_grande_a');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'reservation: %', r; END IF;
  r := public.sovarka_reunion_evenement(q, 'reunion_grande_a', 'reseautage');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'reseautage: %', r; END IF;
  r := public.sovarka_reunion_evenement(q, 'reunion_grande_a', 'reseautage');            -- rejeu
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'rejeu: %', r; END IF;
  r := public.sovarka_reunion_evenement(gen_random_uuid(), 'reunion_grande_a', 'reseautage');
  IF r->>'raison' IS DISTINCT FROM 'evenement_deja_tenu' THEN RAISE EXCEPTION 'second reseautage: %', r; END IF;
  r := public.sovarka_reunion_evenement(gen_random_uuid(), 'reunion_grande_a', 'seminaire', 'XXX');
  IF r->>'raison' IS DISTINCT FROM 'caracteristique_inconnue' THEN RAISE EXCEPTION 'carac: %', r; END IF;
  r := public.sovarka_reunion_evenement(gen_random_uuid(), 'reunion_grande_a', 'seminaire', 'INT');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'seminaire: %', r; END IF;
  r := public.sovarka_reunion_evenement(gen_random_uuid(), 'reunion_grande_a', 'buffet');
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'paye')::int <> 80 THEN RAISE EXCEPTION 'buffet: %', r; END IF;
  r := public.sovarka_reunion_evenement(gen_random_uuid(), 'reunion_grande_a', 'conference_presse');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'conference: %', r; END IF;
  RESET ROLE;
  SELECT (resources->>'inf')::numeric, pa, effets_actifs INTO infb1, pab1, effb FROM public.personnages_donnees WHERE name = b;
  SELECT (resources->>'pop')::numeric, liquide INTO popa1, liqa1 FROM public.personnages_donnees WHERE name = a;
  IF infb1 - infb0 <> 2 OR pab1 - pab0 <> 2 OR popa1 - popa0 <> 4
     OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(effb) e WHERE e->>'cle' = 'seminaire_int') THEN
    RAISE EXCEPTION 'ECHEC inf B % -> %, pa B % -> %, pop A % -> %, effets B %', infb0, infb1, pab0, pab1, popa0, popa1, effb;
  END IF;
  RAISE EXCEPTION 'BANC_OK A=% B=% : B +2 INF, +2 PA, INT+1 ; A +4 POP, liquide % -> % (150 salle + 80 buffet)', a, b, liqa0, liqa1;
END $$;
