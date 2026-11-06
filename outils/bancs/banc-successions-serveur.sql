-- Banc annulé de 20261103110000_successions_ouverture_reponse_serveur : à jouer APRÈS la migration,
-- dans la même transaction ; l'exception finale annule tout. Défunt d'essai : Angie Porcelana ;
-- héritier et conjoint : Jean Jaaj.
DO $$
DECLARE ua uuid; ub uuid; a text := 'Angie Porcelana'; b text := 'Jean Jaaj'; r jsonb; v_id text;
  v_brut integer; v_net integer; v_refus boolean; d jsonb;
BEGIN
  SELECT user_id INTO ua FROM public.personnages_donnees WHERE name = a;
  SELECT user_id INTO ub FROM public.personnages_donnees WHERE name = b;
  UPDATE public.personnages_donnees SET country = 'republic' WHERE name IN (a, b);
  UPDATE public.mariages SET statut = 'banc' WHERE statut = 'actif' AND (conjoint1 IN (a, b) OR conjoint2 IN (a, b));
  INSERT INTO public.mariages (id, conjoint1, conjoint2, country, statut, jour_union) VALUES ('mariage-banc', a, b, 'republic', 'actif', 1);
  UPDATE public.testaments SET statut = 'banc' WHERE testateur = a AND statut = 'actif';
  INSERT INTO public.testaments (id, testateur, country, statut, contenu) VALUES ('testament-banc', a, 'republic', 'actif',
    jsonb_build_object('argent', jsonb_build_array(
      jsonb_build_object('beneficiaire', b, 'pourcentage', 60),
      jsonb_build_object('beneficiaire', 'Personne Inexistante', 'pourcentage', 40))));
  INSERT INTO public.comptes_bancaires (id, personnage, pays, banque, solde) VALUES ('compte-banc', a, 'republic', 'nationale', 10000)
  ON CONFLICT (personnage, banque) DO UPDATE SET solde = 10000;
  SELECT coalesce(sum(greatest(0, solde)), 0)::integer INTO v_brut FROM public.comptes_bancaires WHERE personnage = a;
  v_net := v_brut - floor(v_brut * 0.33)::integer;

  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  -- 1. Écritures directes refusées.
  v_refus := false;
  BEGIN INSERT INTO public.successions (id, defunt, country) VALUES ('succession-fausse', b, 'republic');
  EXCEPTION WHEN insufficient_privilege THEN v_refus := true; END;
  IF NOT v_refus THEN RAISE EXCEPTION 'banc 1: insertion directe acceptee'; END IF;
  -- 2. Ouverture au serveur.
  r := public.succession_ouvrir();
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'reprise')::boolean OR r->>'conjoint' IS DISTINCT FROM b THEN RAISE EXCEPTION 'banc 2: %', r; END IF;
  v_id := r->>'succession_id';
  IF (r->>'argent_brut_total')::int <> v_brut OR (r->>'argent_net_total')::int <> v_net THEN RAISE EXCEPTION 'banc 2 montants: % (brut %)', r, v_brut; END IF;
  SELECT e INTO d FROM jsonb_array_elements(r->'dispositions') e WHERE e->>'id' = 'argent-2';
  IF (d->>'part_nette')::int <> floor(v_net * 0.4)::int OR d->'chaine'->0->>'role' <> 'legal_conjoint' THEN RAISE EXCEPTION 'banc 2 part 2: %', d; END IF;
  SELECT e INTO d FROM jsonb_array_elements(r->'dispositions') e WHERE e->>'id' = 'argent-1';
  IF (d->>'part_nette')::int <> v_net - floor(v_net * 0.4)::int OR d->'chaine'->0->>'role' <> 'principal' OR d->'chaine'->0->>'beneficiaire' <> b THEN RAISE EXCEPTION 'banc 2 part 1: %', d; END IF;
  -- 3. Reprise stricte.
  r := public.succession_ouvrir();
  IF (r->>'reprise')::boolean IS NOT TRUE OR r->>'succession_id' <> v_id THEN RAISE EXCEPTION 'banc 3: %', r; END IF;
  -- 4. Modification directe refusée ; le défunt ne répond pas à la place de l'héritier.
  v_refus := false;
  BEGIN UPDATE public.successions SET dispositions = '[]' WHERE id = v_id;
  EXCEPTION WHEN insufficient_privilege THEN v_refus := true; END;
  IF NOT v_refus THEN RAISE EXCEPTION 'banc 4: modification directe acceptee'; END IF;
  r := public.succession_repondre(v_id, 'argent-1', 'accepte');
  IF r->>'raison' IS DISTINCT FROM 'pas_concerne' THEN RAISE EXCEPTION 'banc 4b: %', r; END IF;
  -- 5. L'héritier renonce : le conjoint légal est convoqué ; puis il accepte, une seule fois.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  r := public.succession_repondre(v_id, 'argent-1', 'peut-etre');
  IF r->>'raison' IS DISTINCT FROM 'reponse_invalide' THEN RAISE EXCEPTION 'banc 5a: %', r; END IF;
  r := public.succession_repondre(v_id, 'argent-1', 'renonce');
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'nouveau_convoque' IS DISTINCT FROM b THEN RAISE EXCEPTION 'banc 5b: %', r; END IF;
  r := public.succession_repondre(v_id, 'argent-1', 'accepte');
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'nouveau_convoque' IS NOT NULL THEN RAISE EXCEPTION 'banc 5c: %', r; END IF;
  r := public.succession_repondre(v_id, 'argent-1', 'accepte');
  IF r->>'raison' IS DISTINCT FROM 'pas_concerne' THEN RAISE EXCEPTION 'banc 5d: %', r; END IF;
  RESET ROLE;
  SELECT e INTO d FROM public.successions, jsonb_array_elements(dispositions) e WHERE id = v_id AND e->>'id' = 'argent-1';
  IF jsonb_array_length(d->'chaine') <> 2 OR d->'chaine'->0->>'reponse' <> 'renonce' OR d->'chaine'->1->>'reponse' <> 'accepte' THEN
    RAISE EXCEPTION 'banc 6 chaine: %', d; END IF;
  IF has_function_privilege('authenticated', 'public.succession_chaine_initiale_interne(text,text,text)', 'EXECUTE') THEN RAISE EXCEPTION 'banc 7'; END IF;
  RAISE EXCEPTION 'BANC OK : successions serveur, rien ne doit rester';
END $$;
