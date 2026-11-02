-- A jouer APRES le corps de la migration 20261102200000, dans la meme transaction annulee.
-- BANC (annule) : un PJ reel recoit deux boulettes le temps de la transaction et les fume.
DO $$
DECLARE n text; u uuid; r jsonb; av public.personnages_donnees%rowtype; ap public.personnages_donnees%rowtype;
  sig jsonb := jsonb_build_object('name','Boulette de shit','type','drogue'); nb_traces int; idx int;
BEGIN
  SELECT name, user_id INTO n, u FROM public.personnages_donnees
   WHERE user_id IS NOT NULL AND coalesce(hp,0) > 10 AND coalesce(moral,0) <= 80 ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET pa = greatest(coalesce(pa,0), 5), effets_actifs = '[]'::jsonb,
    inventory = coalesce(inventory,'[]'::jsonb) || jsonb_build_array(
      jsonb_build_object('id','banc-b1','type','drogue','name','Boulette de shit','legal',false,'stackable',false,'encombrement',1),
      jsonb_build_object('id','banc-b2','type','drogue','name','Boulette de shit','legal',false,'stackable',false,'encombrement',1))
   WHERE name = n;
  SELECT * INTO av FROM public.personnages_donnees WHERE name = n;
  SELECT count(*) INTO nb_traces FROM public.actions_tracables WHERE auteur = n AND type_action = 'consommation_drogue';
  idx := jsonb_array_length(av.inventory) - 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/inventaire_consommer', true);
  SET LOCAL ROLE authenticated;
  r := public.inventaire_consommer(n, idx, sig);
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'drogue')::boolean IS NOT TRUE OR (r->>'bonus_ent')::boolean IS NOT TRUE
    THEN RAISE EXCEPTION 'premiere: %', r - 'inventory'; END IF;
  r := public.inventaire_consommer(n, idx - 1, sig);
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'bonus_ent')::boolean IS NOT FALSE
    THEN RAISE EXCEPTION 'seconde (non-cumul ENT): %', r - 'inventory'; END IF;
  RESET ROLE;
  SELECT * INTO ap FROM public.personnages_donnees WHERE name = n;
  IF ap.pa <> av.pa - 2 THEN RAISE EXCEPTION 'PA % -> %', av.pa, ap.pa; END IF;
  IF ap.hp <> greatest(1, av.hp - 10) THEN RAISE EXCEPTION 'sante % -> %', av.hp, ap.hp; END IF;
  IF ap.moral <> least(100, av.moral + 20) THEN RAISE EXCEPTION 'moral % -> %', av.moral, ap.moral; END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(ap.effets_actifs) e WHERE e->>'cle'='boulette_ent' AND (e#>>'{deltas,ENT}')::int = 2) <> 1
    THEN RAISE EXCEPTION 'effet ENT: %', ap.effets_actifs; END IF;
  IF jsonb_array_length(ap.inventory) <> jsonb_array_length(av.inventory) - 2 THEN RAISE EXCEPTION 'inventaire'; END IF;
  IF (SELECT count(*) FROM public.actions_tracables WHERE auteur = n AND type_action = 'consommation_drogue') <> nb_traces + 2
    THEN RAISE EXCEPTION 'traces'; END IF;
  RAISE NOTICE 'BANC_OK % : PA % -> %, sante % -> %, moral % -> %', n, av.pa, ap.pa, av.hp, ap.hp, av.moral, ap.moral;
END $$;
