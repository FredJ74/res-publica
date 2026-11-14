-- Banc annulé : forêt profonde de Krasnov, s'enfoncer depuis une vue profonde, se perdre, retrouver son chemin
-- (migration 20261114120000). Se termine toujours par une exception : BANC_FORET_PERDU_OK si tout est conforme.
DO $banc$
DECLARE u uuid; r jsonb; v_prec integer; v_pa0 integer; v_pa1 integer; i integer; n integer := 0; egare boolean := false; sorti boolean := false;
        req text;
BEGIN
  SELECT user_id INTO u FROM public.personnages WHERE name = 'Arnie';
  DELETE FROM public.groupes_pj_adhesions WHERE membre = 'Arnie' OR chef = 'Arnie';
  DELETE FROM public.sovarka_foret_rencontres WHERE bucheron = 'Arnie' AND statut = 'en_attente';
  DELETE FROM public.sovarka_foret_perdus WHERE bucheron = 'Arnie';
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'ville_b', current_building = 'zone-production', current_room = 'zone_recolte',
    current_street = NULL, pa = 30, hp = 100, hospitalisation = NULL WHERE name = 'Arnie';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/sovarka_foret_aller', true);

  -- 1. S'enfoncer depuis l'entrée, puis depuis une vue profonde : toujours une autre vue, sans PA, sans se perdre.
  SET LOCAL ROLE authenticated;
  r := public.sovarka_foret_aller(gen_random_uuid(), 'enfoncer');
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'vue')::int NOT BETWEEN 1 AND 4 THEN RAISE EXCEPTION 'enfoncer entree: %', r; END IF;
  FOR i IN 1..12 LOOP
    v_prec := (r->>'vue')::int;
    SELECT pa INTO v_pa0 FROM public.personnages_donnees WHERE name = 'Arnie';
    SET LOCAL ROLE authenticated;
    r := public.sovarka_foret_aller(gen_random_uuid(), 'enfoncer');
    RESET ROLE;
    SELECT pa INTO v_pa1 FROM public.personnages_donnees WHERE name = 'Arnie';
    IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'vue')::int NOT BETWEEN 1 AND 4 OR (r->>'vue')::int = v_prec THEN RAISE EXCEPTION 'enfoncer profond: % (avant %)', r, v_prec; END IF;
    IF (r->>'perdu')::boolean OR v_pa1 <> v_pa0 THEN RAISE EXCEPTION 'enfoncer profond perdu ou payant: % (% -> % PA)', r, v_pa0, v_pa1; END IF;
    IF (SELECT current_room FROM public.personnages_donnees WHERE name = 'Arnie') <> r->>'room' THEN RAISE EXCEPTION 'position apres enfoncer profond'; END IF;
  END LOOP;

  -- 2. Pas perdu : « Retrouver son chemin » est refusé, sans PA.
  SET LOCAL ROLE authenticated;
  r := public.sovarka_foret_aller(gen_random_uuid(), 'retrouver');
  RESET ROLE;
  IF r->>'raison' IS DISTINCT FROM 'foret_pas_perdu' THEN RAISE EXCEPTION 'retrouver sans etre perdu: %', r; END IF;

  -- 3. Revenir jusqu'à s'égarer (1 fois sur 5 on sort : on s'enfonce de nouveau).
  FOR i IN 1..60 LOOP
    v_prec := public.sovarka_foret_vue_interne('Arnie');
    SET LOCAL ROLE authenticated;
    r := public.sovarka_foret_aller(gen_random_uuid(), CASE WHEN v_prec = 0 THEN 'enfoncer' ELSE 'revenir' END);
    RESET ROLE;
    IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'revenir: %', r; END IF;
    IF r->>'sens' = 'revenir' AND (r->>'vue')::int = 0 AND ((r->>'perdu')::boolean OR (r->>'egare')::boolean) THEN RAISE EXCEPTION 'sorti mais perdu: %', r; END IF;
    IF r->>'sens' = 'revenir' AND (r->>'vue')::int > 0 THEN
      IF NOT (r->>'perdu')::boolean OR NOT (r->>'egare')::boolean OR (r->>'vue')::int = v_prec THEN RAISE EXCEPTION 'egarement: % (avant %)', r, v_prec; END IF;
      egare := true; EXIT;
    END IF;
  END LOOP;
  IF NOT egare THEN RAISE EXCEPTION 'jamais egare en 60 essais'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sovarka_foret_perdus WHERE bucheron = 'Arnie') THEN RAISE EXCEPTION 'etat perdu absent'; END IF;

  -- 4. Perdu : Revenir refusé, lecture « perdu », s'enfoncer ne guérit pas.
  SET LOCAL ROLE authenticated;
  r := public.sovarka_foret_aller(gen_random_uuid(), 'revenir');
  IF r->>'raison' IS DISTINCT FROM 'foret_perdu' OR NOT (r->>'perdu')::boolean THEN RAISE EXCEPTION 'revenir perdu: %', r; END IF;
  r := public.sovarka_foret_lire();
  IF NOT (r->>'perdu')::boolean THEN RAISE EXCEPTION 'lire perdu: %', r; END IF;
  r := public.sovarka_foret_aller(gen_random_uuid(), 'enfoncer');
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE OR NOT (r->>'perdu')::boolean OR (r->>'egare')::boolean THEN RAISE EXCEPTION 'enfoncer perdu: %', r; END IF;

  -- 5. Retrouver son chemin : 1 PA à chaque essai, autre vue tant qu'on reste perdu, sortie = plus perdu. Rejeu sans double paiement.
  FOR i IN 1..40 LOOP
    v_prec := public.sovarka_foret_vue_interne('Arnie');
    SELECT pa INTO v_pa0 FROM public.personnages_donnees WHERE name = 'Arnie';
    req := gen_random_uuid()::text;
    SET LOCAL ROLE authenticated;
    r := public.sovarka_foret_aller(req::uuid, 'retrouver');
    PERFORM public.sovarka_foret_aller(req::uuid, 'retrouver');
    RESET ROLE;
    SELECT pa INTO v_pa1 FROM public.personnages_donnees WHERE name = 'Arnie';
    IF (r->>'ok')::boolean IS NOT TRUE OR v_pa1 <> v_pa0 - 1 THEN RAISE EXCEPTION 'retrouver paiement: % (% -> % PA)', r, v_pa0, v_pa1; END IF;
    n := n + 1;
    IF (r->>'vue')::int = 0 THEN
      IF (r->>'perdu')::boolean OR EXISTS (SELECT 1 FROM public.sovarka_foret_perdus WHERE bucheron = 'Arnie') THEN RAISE EXCEPTION 'sorti encore perdu: %', r; END IF;
      IF (SELECT current_room FROM public.personnages_donnees WHERE name = 'Arnie') <> 'zone_recolte' THEN RAISE EXCEPTION 'position apres sortie'; END IF;
      sorti := true; EXIT;
    END IF;
    IF NOT (r->>'perdu')::boolean OR NOT (r->>'egare')::boolean OR (r->>'vue')::int = v_prec THEN RAISE EXCEPTION 'retrouver rate: % (avant %)', r, v_prec; END IF;
    UPDATE public.personnages_donnees SET pa = 30 WHERE name = 'Arnie';
  END LOOP;
  IF NOT sorti THEN RAISE EXCEPTION 'jamais sorti en 40 essais'; END IF;

  -- 6. A l'entrée : retrouver refusé.
  SET LOCAL ROLE authenticated;
  r := public.sovarka_foret_aller(gen_random_uuid(), 'retrouver');
  RESET ROLE;
  IF r->>'raison' IS DISTINCT FROM 'deja_a_l_entree' THEN RAISE EXCEPTION 'retrouver a l entree: %', r; END IF;

  RAISE EXCEPTION 'BANC_FORET_PERDU_OK (% essais pour retrouver)', n;
END $banc$;
