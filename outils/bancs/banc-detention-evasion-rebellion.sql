-- Banc annulé de 20261103100000_detention_evasion_rebellion_serveur : à jouer APRÈS la migration,
-- dans la même transaction ; l'exception finale annule tout. Personnage d'essai : Angie Porcelana.
DO $$
DECLARE u uuid; n text := 'Angie Porcelana'; r jsonb; d record; fin0 int; liq0 numeric; arg0 numeric;
  echec_vu boolean := false; reussite_vue boolean := false; i int; out text := '';
  qhs_vu boolean := false; rebel_ok_vu boolean := false; niv0 int; hp0 int;
BEGIN
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;
  UPDATE public.personnages_donnees SET pa = 200, liquide = 100000, arg = 100000, hp = 100, est_emprisonne = NULL,
         stats = coalesce(stats,'{}'::jsonb) || '{"DUP":25,"VOL":20}'::jsonb, country = 'republic', current_city = 'capitale'
   WHERE name = n;
  UPDATE public.detentions SET mode_fin = 'banc', jour_fin_effective = 0 WHERE nom = n AND mode_fin IS NULL;

  -- 1. Non détenu : refus nommés.
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  r := public.detention_tenter_evasion(3, 0, false);
  IF r->>'raison' IS DISTINCT FROM 'non_detenu' THEN RAISE EXCEPTION 'banc 1a: %', r; END IF;
  r := public.detention_se_rebeller(2, 0);
  IF r->>'raison' IS DISTINCT FROM 'non_detenu' THEN RAISE EXCEPTION 'banc 1b: %', r; END IF;
  -- 2. Les anciennes portes et l'écriture des grilles sont fermées à l'écran.
  IF has_function_privilege('authenticated', 'public.detention_clore_evasion()', 'EXECUTE') THEN RAISE EXCEPTION 'banc 2a'; END IF;
  IF has_function_privilege('authenticated', 'public.detention_transferer_qhs(text,integer,text,jsonb)', 'EXECUTE') THEN RAISE EXCEPTION 'banc 2b'; END IF;
  IF has_function_privilege('authenticated', 'public.prison_grilles_endommager_interne(text,text,integer)', 'EXECUTE') THEN RAISE EXCEPTION 'banc 2c'; END IF;
  IF has_table_privilege('authenticated', 'public.niveaux_prison', 'INSERT') OR has_table_privilege('authenticated', 'public.niveaux_prison', 'UPDATE') THEN RAISE EXCEPTION 'banc 2d'; END IF;
  RESET ROLE;

  -- 3. Évasion : échec puis réussite, une seule tentative par jour.
  r := public.detention_ouvrir_interne(n, 'Banc', 10, 'capitale', 'republic',
         '[{"type":"Vol","jours":10,"source":"banc"}]'::jsonb, NULL, NULL, '{}'::jsonb);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'banc 3 ouverture: %', r; END IF;
  FOR i IN 1..80 LOOP
    EXIT WHEN echec_vu AND reussite_vue;
    IF reussite_vue THEN  -- réincarcéré pour observer aussi l'échec
      UPDATE public.personnages_donnees SET recherche = '[]'::jsonb WHERE name = n;
      r := public.detention_ouvrir_interne(n, 'Banc', 10, 'capitale', 'republic', '[{"type":"Vol","jours":10}]'::jsonb, NULL, NULL, '{}'::jsonb);
    END IF;
    UPDATE public.detentions SET derniere_tentative_evasion = NULL WHERE nom = n AND mode_fin IS NULL;
    SELECT * INTO d FROM public.detention_active(n);
    SELECT liquide, arg INTO liq0, arg0 FROM public.personnages_donnees WHERE name = n;
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
    r := public.detention_tenter_evasion(3, 0, false);
    RESET ROLE;
    IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'banc 3 tentative: %', r; END IF;
    IF (r->>'reussi')::boolean THEN
      IF EXISTS (SELECT 1 FROM public.detention_active(n)) THEN RAISE EXCEPTION 'banc 3 encore detenu'; END IF;
      IF NOT EXISTS (SELECT 1 FROM public.detentions WHERE id = d.id AND mode_fin = 'evasion' AND jour_fin = d.jour_fin) THEN RAISE EXCEPTION 'banc 3 cloture'; END IF;
      IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees, jsonb_array_elements(recherche) e
                      WHERE name = n AND e->>'detention_precedente_id' = d.id
                        AND e->'motifs' @> '[{"type":"Évasion","jours":2}]' AND e->'motifs' @> '[{"type":"Vol"}]') THEN
        RAISE EXCEPTION 'banc 3 avis de recherche: %', r; END IF;
      IF (SELECT est_emprisonne FROM public.personnages_donnees WHERE name = n) IS NOT NULL THEN RAISE EXCEPTION 'banc 3 fiche'; END IF;
      reussite_vue := true;
    ELSE
      IF (r->>'jour_fin')::int <> d.jour_fin + 1 THEN RAISE EXCEPTION 'banc 3 +1 jour: %', r; END IF;
      IF (r->>'amende')::int <> 500 THEN RAISE EXCEPTION 'banc 3 amende: %', r; END IF;
      IF (SELECT arg FROM public.personnages_donnees WHERE name = n) <> arg0 - 500 THEN RAISE EXCEPTION 'banc 3 arg'; END IF;
      SET LOCAL ROLE authenticated;
      r := public.detention_tenter_evasion(3, 0, false);
      RESET ROLE;
      IF r->>'raison' IS DISTINCT FROM 'une_tentative_par_jour' THEN RAISE EXCEPTION 'banc 3 second essai: %', r; END IF;
      echec_vu := true;
    END IF;
  END LOOP;
  IF NOT (echec_vu AND reussite_vue) THEN RAISE EXCEPTION 'banc 3 issues non observees (%/%)', echec_vu, reussite_vue; END IF;
  out := out || 'evasion ok; ';

  -- 4. Rébellion : réussite (+1 jour, PV −10, DIS +6) et échec (QHS 30 jours), grilles endommagées.
  UPDATE public.detentions SET mode_fin = 'banc', jour_fin_effective = 0 WHERE nom = n AND mode_fin IS NULL;
  UPDATE public.personnages_donnees SET est_emprisonne = NULL WHERE name = n;
  r := public.detention_ouvrir_interne(n, 'Banc', 10, 'capitale', 'republic', '[{"type":"Vol","jours":10}]'::jsonb, NULL, NULL, '{}'::jsonb);
  FOR i IN 1..60 LOOP
    EXIT WHEN qhs_vu AND rebel_ok_vu;
    UPDATE public.personnages_donnees SET hp = 100, resources = coalesce(resources,'{}'::jsonb) || '{"dis":50}' WHERE name = n;
    SELECT * INTO d FROM public.detention_active(n);
    SELECT coalesce((data->>'niveau')::int, 100) INTO niv0 FROM public.niveaux_prison WHERE id = 'republic_' || d.city;
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
    r := public.detention_se_rebeller(2, 0);
    RESET ROLE;
    IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'banc 4 rebellion: %', r; END IF;
    IF (r->'grilles'->>'degats')::int NOT BETWEEN 1 AND 10 THEN RAISE EXCEPTION 'banc 4 grilles: %', r; END IF;
    IF (r->>'reussi')::boolean THEN
      IF (r->>'jour_fin')::int <> d.jour_fin + 1 OR (r->>'hp')::int <> 90 OR (r->>'dis')::numeric <> 56 THEN RAISE EXCEPTION 'banc 4 reussite: %', r; END IF;
      rebel_ok_vu := true;
    ELSE
      IF (r->>'hp')::int <> 75 OR (r->>'dis')::numeric <> 35 THEN RAISE EXCEPTION 'banc 4 echec: %', r; END IF;
      IF NOT EXISTS (SELECT 1 FROM public.detentions WHERE id = d.id AND mode_fin = 'transfert_qhs') THEN RAISE EXCEPTION 'banc 4 ancienne ligne'; END IF;
      IF NOT EXISTS (SELECT 1 FROM public.detention_active(n) x WHERE x.qhs AND x.id = r->>'detention_id') THEN RAISE EXCEPTION 'banc 4 qhs: %', r; END IF;
      qhs_vu := true;
    END IF;
  END LOOP;
  IF NOT (qhs_vu AND rebel_ok_vu) THEN RAISE EXCEPTION 'banc 4 issues non observees (%/%)', qhs_vu, rebel_ok_vu; END IF;
  out := out || 'rebellion ok; ';
  RAISE EXCEPTION 'BANC OK : % rien ne doit rester', out;
END $$;
