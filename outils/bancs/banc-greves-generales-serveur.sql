-- Banc annulé de 20261103112517_greves_generales_serveur : à jouer APRÈS la migration, dans la même
-- transaction ; l'exception finale annule tout. Trois syndicats créés pour le banc, dirigés par
-- Angie Porcelana (60 adhérents), Jean Jaaj (50) et Arnie (5).
DO $$
DECLARE ua uuid; uj uuid; ur uuid; r jsonb; v_gg text; n_part int; out text;
  m60 jsonb; m50 jsonb; m5 jsonb;
BEGIN
  PERFORM set_config('request.path', '/rpc/greve_generale', true);
  SELECT user_id INTO ua FROM public.personnages_donnees WHERE name = 'Angie Porcelana';
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = 'Jean Jaaj';
  SELECT user_id INTO ur FROM public.personnages_donnees WHERE name = 'Arnie';
  UPDATE public.personnages_donnees SET pa = 20, country = 'republic', updated_at = now()
   WHERE name IN ('Angie Porcelana', 'Jean Jaaj', 'Arnie');
  SELECT jsonb_agg(jsonb_build_object('nom', 'Banc A' || g)) INTO m60 FROM generate_series(1, 60) g;
  SELECT jsonb_agg(jsonb_build_object('nom', 'Banc B' || g)) INTO m50 FROM generate_series(1, 50) g;
  SELECT jsonb_agg(jsonb_build_object('nom', 'Banc C' || g)) INTO m5 FROM generate_series(1, 5) g;
  INSERT INTO public.organisations (id, country_origine, data) VALUES
    ('banc_syn_a', 'republic', jsonb_build_object('id', 'banc_syn_a', 'type', 'syndicale', 'nom', 'Syndicat A', 'chef', 'Angie Porcelana', 'country_origine', 'republic', 'membres', m60)::text),
    ('banc_syn_b', 'republic', jsonb_build_object('id', 'banc_syn_b', 'type', 'syndicale', 'nom', 'Syndicat B', 'chef', 'Jean Jaaj', 'country_origine', 'republic', 'membres', m50)::text),
    ('banc_syn_c', 'republic', jsonb_build_object('id', 'banc_syn_c', 'type', 'syndicale', 'nom', 'Syndicat C', 'chef', 'Arnie', 'country_origine', 'republic', 'membres', m5)::text);

  -- 1. Refus : pas le chef, écriture directe.
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  r := public.greve_generale_lancer('banc_syn_a', 'Banc');
  IF r->>'raison' IS DISTINCT FROM 'reserve_au_chef' THEN RAISE EXCEPTION 'banc 1a: %', r; END IF;
  BEGIN
    INSERT INTO public.greves_generales (id, country, statut, puissance_niveau) VALUES ('banc_faux', 'republic', 'active', 5);
    RAISE EXCEPTION 'banc 1b: écriture directe acceptée';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- 2. Angie lance : liste figée, A accepte d'office.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  r := public.greve_generale_lancer('banc_syn_a', '');
  IF r->>'raison' IS DISTINCT FROM 'revendications_requises' THEN RAISE EXCEPTION 'banc 2a: %', r; END IF;
  r := public.greve_generale_lancer('banc_syn_a', 'Banc : salaires');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'banc 2b: %', r; END IF;
  v_gg := r->>'id';
  n_part := jsonb_array_length(r->'participants');
  IF NOT (r->'participants' @> '[{"orgaId":"banc_syn_a","statut":"accepte"},{"orgaId":"banc_syn_b","statut":"en_discussion"},{"orgaId":"banc_syn_c","statut":"en_discussion"}]'::jsonb) THEN
    RAISE EXCEPTION 'banc 2c: participants %', r->'participants';
  END IF;
  r := public.greve_generale_lancer('banc_syn_a', 'Encore');
  IF r->>'raison' IS DISTINCT FROM 'deja_engage' THEN RAISE EXCEPTION 'banc 2d: %', r; END IF;
  r := public.greve_generale_repondre(v_gg, 'banc_syn_b', 'accepte');
  IF r->>'raison' IS DISTINCT FROM 'reserve_au_chef' THEN RAISE EXCEPTION 'banc 2e: %', r; END IF;
  RESET ROLE;
  IF (SELECT pa FROM public.personnages_donnees WHERE name = 'Angie Porcelana') <> 19 THEN RAISE EXCEPTION 'banc 2f: PA'; END IF;
  out := n_part || ' syndicats consultés';

  -- 3. Jean accepte (B) : adoption si 2/3 et 110 adhérents (seulement 3 éligibles en bêta).
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  r := public.greve_generale_repondre(v_gg, 'banc_syn_b', 'accepte');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'banc 3a: %', r; END IF;
  IF n_part = 3 AND (NOT (r->>'adoptee')::boolean OR (r->>'niveau')::int <> 1 OR (r->>'adherents')::int <> 110) THEN
    RAISE EXCEPTION 'banc 3b: %', r;
  END IF;
  r := public.greve_generale_repondre(v_gg, 'banc_syn_b', 'refuse');
  IF r->>'raison' NOT IN ('consultation_close', 'deja_repondu') THEN RAISE EXCEPTION 'banc 3c: %', r; END IF;
  RESET ROLE;
  IF n_part = 3 THEN
    IF (SELECT statut FROM public.greves_generales WHERE id = v_gg) <> 'active' THEN RAISE EXCEPTION 'banc 3d: non active'; END IF;
    IF (SELECT data::jsonb->>'greveGeneraleStatut' FROM public.organisations WHERE id = 'banc_syn_b') <> 'actif' THEN
      RAISE EXCEPTION 'banc 3e: syndicat B non synchronisé';
    END IF;
    out := out || ', adoptée niveau 1 (110 adhérents)';
    -- 4. Jean retire B : 60 adhérents restants, la grève s'effondre.
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
    r := public.greve_generale_retirer('banc_syn_b');
    RESET ROLE;
    IF (r->>'ok')::boolean IS NOT TRUE OR NOT (r->>'terminee')::boolean THEN RAISE EXCEPTION 'banc 4a: %', r; END IF;
    IF (SELECT statut FROM public.greves_generales WHERE id = v_gg) <> 'terminee' THEN RAISE EXCEPTION 'banc 4b'; END IF;
    out := out || ', retrait de B : effondrée';
  END IF;
  RAISE EXCEPTION 'BANC OK : %', out;
END $$;
