-- A jouer APRES le corps de la migration 20261104123000, dans la meme transaction annulee.
-- L'amende reste due sur la caisse (pas de prelevement d'office), l'expediteur peut la payer,
-- sinon le destinataire la paie au dedouanement ; vente au profit du Tresor (structurel).
DO $$
DECLARE n text := 'Jean Jaaj'; d text := 'Angie Porcelana'; u uuid; ud uuid; r jsonb; c uuid; l_med uuid;
  t0 numeric; t1 numeric; t2 numeric;
BEGIN
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;
  SELECT user_id INTO ud FROM public.personnages_donnees WHERE name = d;
  UPDATE public.personnages_donnees SET pa = greatest(coalesce(pa, 0), 10), liquide = greatest(coalesce(liquide, 0), 1000),
    country = 'republic', current_city = 'ville_a', current_building = 'port-sainte-marie', current_room = 'entrepot',
    current_street = NULL WHERE name = n;
  UPDATE public.personnages_donnees SET liquide = greatest(coalesce(liquide, 0), 1000) WHERE name = d;
  SELECT coalesce((data->>'reserveJour')::numeric, 0) INTO t0 FROM public.budgets_nationaux WHERE id = 'republic';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/fret_caisse_commande', true);
  SET LOCAL ROLE authenticated;
  r := public.fret_caisse_commande('reserver', NULL, '{}', gen_random_uuid());
  c := (r->>'caisse')::uuid;
  RESET ROLE;
  INSERT INTO public.contenu_caisses_fret(caisse_id, deposant, objet, quantite) VALUES
    (c, n, '{"name":"Métal","stackKey":"metal","stackable":true}', 10),
    (c, n, '{"name":"Médicaments","stackKey":"medicaments","stackable":true}', 5);
  SELECT id INTO l_med FROM public.contenu_caisses_fret WHERE caisse_id = c AND objet->>'stackKey' = 'medicaments';
  SET LOCAL ROLE authenticated;
  r := public.fret_caisse_commande('fermer', c, jsonb_build_object('nom', d, 'declaration', 'Métal', 'valeur', 150,
    'non_declares', jsonb_build_array(l_med)), gen_random_uuid());
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'fermer: %', r; END IF;
  RESET ROLE;
  r := public.fret_inspecter_interne(c, 'banc');
  IF (r->>'amende')::integer <> 22 OR (SELECT amende_due FROM public.caisses_fret WHERE id = c) <> 22 THEN RAISE EXCEPTION 'amende due: %', r; END IF;
  IF EXISTS (SELECT 1 FROM public.amendes_tresor WHERE jugement_id = 'fret-' || c::text) THEN RAISE EXCEPTION 'prelevement d office'; END IF;

  -- 1. L'expediteur paie.
  SET LOCAL ROLE authenticated;
  r := public.fret_caisse_commande('amende_payer', c, '{}', gen_random_uuid());
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'amende_payer: %', r; END IF;
  RESET ROLE;
  SELECT coalesce((data->>'reserveJour')::numeric, 0) INTO t1 FROM public.budgets_nationaux WHERE id = 'republic';
  IF t1 <> t0 + 22 OR NOT (SELECT amende_payee FROM public.caisses_fret WHERE id = c) THEN RAISE EXCEPTION 'tresor % -> %', t0, t1; END IF;

  -- 2. Personne n'a paye : le destinataire paie avec le dedouanement (droits 15 + amende 22).
  UPDATE public.caisses_fret SET amende_payee = false, statut = 'arrivee', date_arrivee_reelle = now() WHERE id = c;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ud, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/fret_dedouaner', true);
  SET LOCAL ROLE authenticated;
  r := public.fret_dedouaner(c);
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'total')::numeric <> 37 OR (r->>'amende')::numeric <> 22 THEN RAISE EXCEPTION 'dedouaner: %', r; END IF;
  SELECT coalesce((data->>'reserveJour')::numeric, 0) INTO t2 FROM public.budgets_nationaux WHERE id = 'republic';
  IF t2 <> t1 + 22 THEN RAISE EXCEPTION 'tresor dedouanement % -> %', t1, t2; END IF;

  -- 3. Vente d'une caisse saisie : au Tresor (structurel).
  IF position('fret_tresor_crediter_interne' IN pg_get_functiondef('public.fret_objet_agir(uuid,uuid,text,uuid,integer,integer,bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'vente non raccordee'; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (amende due 22, payee par l expediteur, puis au dedouanement : total 37)';
END $$;
