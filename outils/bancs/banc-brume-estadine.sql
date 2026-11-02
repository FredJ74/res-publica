-- A jouer APRES les corps des migrations 20261102210000 et 20261102211000, dans la meme
-- transaction annulee. Un PJ reel est place aux travees de Montrouge le temps de la transaction.
DO $$
DECLARE n text; u uuid; r jsonb; av public.personnages_donnees%rowtype; ap public.personnages_donnees%rowtype;
  idx int;
BEGIN
  SELECT name, user_id INTO n, u FROM public.personnages_donnees
   WHERE user_id IS NOT NULL AND coalesce(hp,0) > 30 AND coalesce(moral,0) BETWEEN 30 AND 80
     AND public.inventaire_place_restante(inventory) >= 3 ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET country='republic', current_city='ville_b', current_building='centre-artisanal',
    current_room='travees', pa = 10, liquide = greatest(coalesce(liquide,0), 1000), effets_actifs='[]'::jsonb,
    bonus_pa_differe = 0 WHERE name = n;
  PERFORM public.drogue_stock_courant('Jojo Laferraille','estadine');
  UPDATE public.drogues_stocks_dealers SET stock = 1, jour = public.jour_de_jeu_pays('republic')
   WHERE dealer = 'Jojo Laferraille' AND produit = 'estadine';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/dealer_acheter', true);
  SET LOCAL ROLE authenticated;
  r := public.dealer_stocks_lire();
  IF r->>'dealer' IS DISTINCT FROM 'Jojo Laferraille' OR (r#>>'{estadine,stock}')::int <> 1 THEN RAISE EXCEPTION 'stocks: %', r; END IF;
  r := public.dealer_acheter(gen_random_uuid(), 'estadine');
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'stock')::int <> 0 OR r->>'nom' <> 'Pochon d''Estadine'
    THEN RAISE EXCEPTION 'achat estadine: %', r - 'inventory'; END IF;
  r := public.dealer_acheter(gen_random_uuid(), 'estadine');
  IF r->>'raison' IS DISTINCT FROM 'rupture_stock' THEN RAISE EXCEPTION 'rupture: %', r - 'inventory'; END IF;
  r := public.pnj_ced_acheter(gen_random_uuid());
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'produit' <> 'brume' THEN RAISE EXCEPTION 'ancien ecran: %', r - 'inventory'; END IF;
  RESET ROLE;
  SELECT * INTO av FROM public.personnages_donnees WHERE name = n;
  SELECT (o - 1)::int INTO idx FROM jsonb_array_elements(av.inventory) WITH ORDINALITY t(e, o)
   WHERE e->>'drogue' = 'estadine' LIMIT 1;
  PERFORM set_config('request.path', '/rpc/inventaire_consommer', true);
  SET LOCAL ROLE authenticated;
  r := public.inventaire_consommer(n, idx, jsonb_build_object('name','Pochon d''Estadine','type','drogue'));
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'produit' <> 'estadine' OR (r->>'montee_nouvelle')::boolean IS NOT TRUE
    THEN RAISE EXCEPTION 'conso estadine: %', r - 'inventory'; END IF;
  RESET ROLE;
  SELECT * INTO ap FROM public.personnages_donnees WHERE name = n;
  IF ap.pa <> least(30, av.pa + 3) OR ap.moral <> least(100, av.moral + 15) THEN
    RAISE EXCEPTION 'montee PA % -> %, moral % -> %', av.pa, ap.pa, av.moral, ap.moral; END IF;
  -- La descente n'est pas encore due.
  SET LOCAL ROLE authenticated;
  r := public.drogues_descentes_appliquer();
  IF (r->>'appliquees')::int <> 0 THEN RAISE EXCEPTION 'descente prematuree: %', r; END IF;
  RESET ROLE;
  -- On avance l'horloge de la descente.
  UPDATE public.personnages_donnees SET effets_actifs = (SELECT jsonb_agg(CASE WHEN e ? 'descente'
     THEN e || jsonb_build_object('descenteA', 0) ELSE e END) FROM jsonb_array_elements(effets_actifs) e) WHERE name = n;
  SELECT * INTO av FROM public.personnages_donnees WHERE name = n;
  r := public.drogues_descentes_nuit();
  IF (r->>'appliquees')::int < 1 THEN RAISE EXCEPTION 'nuit: %', r; END IF;
  SELECT * INTO ap FROM public.personnages_donnees WHERE name = n;
  IF ap.moral <> greatest(0, av.moral - 25) OR ap.hp <> greatest(1, av.hp - 10) OR ap.bonus_pa_differe <> -3 THEN
    RAISE EXCEPTION 'descente moral % -> %, sante % -> %, differe %', av.moral, ap.moral, av.hp, ap.hp, ap.bonus_pa_differe; END IF;
  SET LOCAL ROLE authenticated;
  r := public.drogues_descentes_appliquer();
  IF (r->>'appliquees')::int <> 0 THEN RAISE EXCEPTION 'double descente: %', r; END IF;
  RESET ROLE;
  IF (SELECT count(*) FROM jsonb_array_elements(ap.effets_actifs) e WHERE (e#>>'{deltas,INT}')::numeric = -0.1) <> 1
    THEN RAISE EXCEPTION 'usure INT: %', ap.effets_actifs; END IF;
  RAISE EXCEPTION 'BANC_OK % : montee puis descente moral % -> %, sante % -> %, PA differes %',
    n, av.moral, ap.moral, av.hp, ap.hp, ap.bonus_pa_differe;
END $$;
