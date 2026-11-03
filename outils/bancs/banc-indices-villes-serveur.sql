-- Banc annulé de 20261103104907 (manifestations) et 20261103105500 (indices de ville, subventions,
-- effort de guerre) : à jouer APRÈS les deux migrations, dans la même transaction ; l'exception
-- finale annule tout. Personnages d'essai : Angie Porcelana (ministre puis présidente le temps du
-- banc), Jean Jaaj (passant à Montrouge).
DO $$
DECLARE u uuid; n text := 'Angie Porcelana'; j text := 'Jean Jaaj'; r jsonb; s0 int; s1 int; i0 int; i1 int;
  hpj0 int; hpj1 int; cap0 int; cap1 int; out text := '';
BEGIN
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;
  UPDATE public.personnages_donnees SET pa = 50, country = 'republic', current_city = 'capitale', poste = NULL WHERE name = n;
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'ville_a', hp = 80,
         stats = coalesce(stats, '{}'::jsonb) || '{"VOL": 15}'::jsonb WHERE name = j;
  UPDATE public.organisations SET data = data::jsonb - 'greve' - 'greveGeneraleStatut'
   WHERE data::jsonb->>'corpsMetier' = 'police';
  UPDATE public.budgets_municipaux SET data = data - 'manifestationInterdite' WHERE id = 'republic_ville_a';

  -- 1. Sans le poste : refus nommés, aucun PA prélevé ; l'écran n'écrit plus indices_villes.
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  r := public.manifestation_interdire('ville_a', 'Banc');
  IF r->>'raison' IS DISTINCT FROM 'reserve_ministre_interieur' THEN RAISE EXCEPTION 'banc 1a: %', r; END IF;
  r := public.effort_guerre_renouveler();
  IF r->>'raison' IS DISTINCT FROM 'reserve_au_president' THEN RAISE EXCEPTION 'banc 1b: %', r; END IF;
  BEGIN
    UPDATE public.indices_villes SET data = data || '{"isn": 100}'::jsonb WHERE id = 'republic_ville_a';
    RAISE EXCEPTION 'banc 1c: écriture directe acceptée';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RESET ROLE;

  -- 2. Ministre de l'Intérieur : interdire (Social −5, 2 PA), puis réprimer avec interdiction (−8 / +8).
  UPDATE public.personnages_donnees SET poste = '{"id": "min_int"}'::jsonb WHERE name = n;
  SELECT (data->>'social')::int, (data->>'isn')::int INTO s0, i0 FROM public.indices_villes WHERE id = 'republic_ville_a';
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  r := public.manifestation_interdire('nulle_part', 'Banc');
  IF r->>'raison' IS DISTINCT FROM 'ville_inconnue' THEN RAISE EXCEPTION 'banc 2a: %', r; END IF;
  r := public.manifestation_interdire('ville_a', 'Banc');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'banc 2b: %', r; END IF;
  RESET ROLE;
  SELECT (data->>'social')::int INTO s1 FROM public.indices_villes WHERE id = 'republic_ville_a';
  IF s1 <> greatest(0, s0 - 5) THEN RAISE EXCEPTION 'banc 2c: social % -> %', s0, s1; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.budgets_municipaux WHERE id = 'republic_ville_a' AND data ? 'manifestationInterdite') THEN
    RAISE EXCEPTION 'banc 2d: interdiction non inscrite';
  END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE name = n) <> 48 THEN RAISE EXCEPTION 'banc 2e: PA'; END IF;
  out := out || 'interdire social ' || s0 || '->' || s1;

  SELECT hp INTO hpj0 FROM public.personnages_donnees WHERE name = j;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  r := public.manifestation_reprimer('ville_a', 'Banc');
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'baisse_social')::int <> 8 OR NOT (r->>'interdiction_recente')::boolean THEN
    RAISE EXCEPTION 'banc 2f: %', r;
  END IF;
  SELECT (data->>'social')::int, (data->>'isn')::int INTO s0, i1 FROM public.indices_villes WHERE id = 'republic_ville_a';
  IF s0 <> greatest(0, s1 - 8) OR i1 <> least(100, i0 + 8) THEN RAISE EXCEPTION 'banc 2g: social % isn % -> %', s0, i0, i1; END IF;
  SELECT hp INTO hpj1 FROM public.personnages_donnees WHERE name = j;
  IF hpj1 <> hpj0 - 10 OR (SELECT (stats->>'VOL')::int FROM public.personnages_donnees WHERE name = j) <> 5 THEN
    RAISE EXCEPTION 'banc 2h: Jean Jaaj non touché (% -> %)', hpj0, hpj1;
  END IF;
  IF EXISTS (SELECT 1 FROM public.budgets_municipaux WHERE id = 'republic_ville_a' AND data ? 'manifestationInterdite') THEN
    RAISE EXCEPTION 'banc 2i: interdiction non levée';
  END IF;
  out := out || ' ; reprimer -8/+8, ' || (r->>'touches') || ' PJ touchés';

  -- 3. Seconde répression sans interdiction : −5 / +5 ; police en grève : refus.
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  r := public.manifestation_reprimer('ville_a', 'Banc');
  RESET ROLE;
  IF (r->>'baisse_social')::int <> 5 THEN RAISE EXCEPTION 'banc 3a: %', r; END IF;
  INSERT INTO public.organisations (id, country_origine, data) VALUES ('banc_police', 'republic',
    '{"id":"banc_police","type":"syndicale","corpsMetier":"police","greve":{"actif":true},"membres":[]}'::jsonb);
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  r := public.manifestation_reprimer('ville_a', 'Banc');
  RESET ROLE;
  IF r->>'raison' IS DISTINCT FROM 'police_en_greve' THEN RAISE EXCEPTION 'banc 3b: %', r; END IF;

  -- 4. Effort de guerre : renouvellement préventif, −2 Social dans chaque ville, puis refus (2 périodes).
  UPDATE public.personnages_donnees SET poste = '{"id": "president"}'::jsonb WHERE name = n;
  UPDATE public.budgets_nationaux SET data = jsonb_set(data, '{effortGuerre}', jsonb_build_object('actif', true,
    'expireA', (extract(epoch FROM now()) * 1000)::bigint + 3600000, 'periodes', 1, 'periodesPreventives', 1))
   WHERE id = 'republic';
  SELECT (data->>'social')::int INTO cap0 FROM public.indices_villes WHERE id = 'republic_capitale';
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  r := public.effort_guerre_renouveler();
  IF (r->>'ok')::boolean IS NOT TRUE OR NOT (r->>'penalite_is')::boolean OR (r->'effort'->>'periodesPreventives')::int <> 2 THEN
    RAISE EXCEPTION 'banc 4a: %', r;
  END IF;
  r := public.effort_guerre_renouveler();
  IF r->>'raison' IS DISTINCT FROM 'prolongation_preventive_epuisee' THEN RAISE EXCEPTION 'banc 4b: %', r; END IF;
  RESET ROLE;
  SELECT (data->>'social')::int INTO cap1 FROM public.indices_villes WHERE id = 'republic_capitale';
  IF cap1 <> greatest(0, cap0 - 2) THEN RAISE EXCEPTION 'banc 4c: capitale % -> %', cap0, cap1; END IF;
  out := out || ' ; effort capitale ' || cap0 || '->' || cap1;

  -- 5. Subventions : les trois portes appellent le moteur Social +3.
  IF position('subvention_effet_social_interne' IN pg_get_functiondef('public.subvention_citoyen_verser(text,integer)'::regprocedure)) = 0
     OR position('subvention_effet_social_interne' IN pg_get_functiondef('public.subvention_collective_verser(text,text,text,integer)'::regprocedure)) = 0
     OR position('subvention_effet_social_interne' IN pg_get_functiondef('public.subvention_entreprise_verser(text,integer,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'banc 5a: subvention sans effet Social';
  END IF;
  UPDATE public.personnages_donnees SET poste = '{"id": "min_fin"}'::jsonb, current_city = 'ville_b' WHERE name = n;
  SELECT (data->>'social')::int INTO s0 FROM public.indices_villes WHERE id = 'republic_ville_b';
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  r := public.subvention_citoyen_verser(j, 10);
  RESET ROLE;
  SELECT (data->>'social')::int INTO s1 FROM public.indices_villes WHERE id = 'republic_ville_b';
  IF (r->>'ok')::boolean IS TRUE AND s1 <> least(100, s0 + 3) THEN RAISE EXCEPTION 'banc 5b: % -> %', s0, s1; END IF;
  IF (r->>'ok')::boolean IS NOT TRUE AND s1 <> s0 THEN RAISE EXCEPTION 'banc 5c: effet sans versement'; END IF;
  out := out || ' ; subvention citoyen ' || coalesce(r->>'ok', '?') || ' ' || coalesce(r->>'raison', '') || ' social PSM ' || s0 || '->' || s1;

  RAISE EXCEPTION 'BANC OK : %', out;
END $$;
