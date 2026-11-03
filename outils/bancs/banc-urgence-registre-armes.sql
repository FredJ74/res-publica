-- Banc annulé de 20261103111212_etat_urgence_registre_armes_serveur : à jouer APRÈS la migration,
-- dans la même transaction ; l'exception finale annule tout. Personnage d'essai : Angie Porcelana.
DO $$
DECLARE u uuid; n text := 'Angie Porcelana'; r jsonb; p0 numeric; i0 numeric; p1 numeric; i1 numeric; out text;
BEGIN
  -- Comme un appel réel (/rpc/...) : sinon le déclencheur personnages_fusionner_pop prend
  -- l'écriture serveur de POP/INF pour une sauvegarde de l'écran et la neutralise.
  PERFORM set_config('request.path', '/rpc/etat_urgence_decider', true);
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;
  DELETE FROM public.etats_urgence WHERE country = 'republic';
  UPDATE public.personnages_donnees SET pa = 20, country = 'republic', poste = NULL,
         resources = coalesce(resources, '{}'::jsonb) || '{"pop": 50, "inf": 20}'::jsonb WHERE name = n;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  r := public.etat_urgence_decider(true);
  IF r->>'raison' IS DISTINCT FROM 'reserve_au_president' THEN RAISE EXCEPTION 'banc 1a: %', r; END IF;
  BEGIN
    INSERT INTO public.etats_urgence (country, actif, active_par, jour_debut) VALUES ('republic', true, n, 1);
    RAISE EXCEPTION 'banc 1b: écriture directe acceptée';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.registre_ventes_armes (joueur, arme, prix, pays, city, jour, heure) VALUES ('X', 'Y', 1, 'republic', 'capitale', 1, 8);
    RAISE EXCEPTION 'banc 1c: registre écrit par l''écran';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RESET ROLE;

  UPDATE public.personnages_donnees SET poste = '{"id": "president"}'::jsonb WHERE name = n;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  r := public.etat_urgence_decider(false);
  IF r->>'raison' IS DISTINCT FROM 'pas_en_vigueur' THEN RAISE EXCEPTION 'banc 2a: %', r; END IF;
  r := public.etat_urgence_decider(true);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'banc 2b: %', r; END IF;
  RESET ROLE;
  SELECT (resources->>'pop')::numeric, (resources->>'inf')::numeric INTO p1, i1 FROM public.personnages_donnees WHERE name = n;
  IF p1 NOT BETWEEN 31 AND 45 OR i1 NOT BETWEEN 25 AND 34 OR p1 - 50 <> (r->>'delta_pop')::numeric THEN
    RAISE EXCEPTION 'banc 2c: pop % inf % (%)', p1, i1, r;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.etats_urgence WHERE country = 'republic' AND actif AND active_par = n) THEN
    RAISE EXCEPTION 'banc 2d: état non inscrit';
  END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE name = n) <> 17 THEN RAISE EXCEPTION 'banc 2e: PA'; END IF;
  out := 'déclaré pop 50->' || p1 || ' inf 20->' || i1;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  r := public.etat_urgence_decider(true);
  IF r->>'raison' IS DISTINCT FROM 'deja_en_vigueur' THEN RAISE EXCEPTION 'banc 3a: %', r; END IF;
  r := public.etat_urgence_decider(false);
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'delta_pop')::int <> 0 THEN RAISE EXCEPTION 'banc 3b: %', r; END IF;
  RESET ROLE;
  IF EXISTS (SELECT 1 FROM public.etats_urgence WHERE country = 'republic' AND actif) THEN RAISE EXCEPTION 'banc 3c: non levé'; END IF;

  IF position('RETURNING id INTO v_registre' IN pg_get_functiondef('public.arme_acheter(text,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'banc 4: arme_acheter n''inscrit pas au registre';
  END IF;
  RAISE EXCEPTION 'BANC OK : %, levé, refus doublon, registre fermé et tenu par arme_acheter', out;
END $$;
