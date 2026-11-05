-- A jouer APRES le corps de la migration 20261105113000, dans la meme transaction annulee.
-- BANC (annulé) : B emploie un PNJ témoin ; A tente de le débaucher jusqu'à réussite.
DO $$
DECLARE a text; ua uuid; b text; r jsonb; i integer; liq0 numeric; liq1 numeric; paye integer := 0; refuse boolean := false;
BEGIN
  SELECT name, user_id INTO a, ua FROM public.personnages_donnees WHERE user_id IS NOT NULL ORDER BY name LIMIT 1;
  SELECT name INTO b FROM public.personnages_donnees WHERE user_id IS NOT NULL AND name <> a ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET liquide = 100000 WHERE name = a;
  UPDATE public.personnages_donnees SET employes = coalesce(employes, '[]'::jsonb) || '[{"nom":"Banc Témoin (PNJ)","job":"serveur"}]'::jsonb WHERE name = b;
  SELECT liquide INTO liq0 FROM public.personnages_donnees WHERE name = a;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.pnj_debaucher(b, 'Banc Témoin (PNJ)', 'serveur', 50, 50);
  IF r->>'raison' IS DISTINCT FROM 'montant_insuffisant' THEN RAISE EXCEPTION 'minimum: %', r; END IF;
  BEGIN
    PERFORM public.pnj_employe_debaucher(b, 'Banc Témoin (PNJ)', 'serveur');
  EXCEPTION WHEN insufficient_privilege THEN refuse := true;
  END;
  IF NOT refuse THEN RAISE EXCEPTION 'retrait direct encore possible'; END IF;
  FOR i IN 1..40 LOOP
    r := public.pnj_debaucher(b, 'Banc Témoin (PNJ)', 'serveur', 3000, 0);
    IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'tentative: %', r; END IF;
    IF (r->>'deja_parti')::boolean THEN RAISE EXCEPTION 'parti sans reussite: %', r; END IF;
    paye := paye + 3000;
    IF (r->>'taux')::int > 85 OR (r->>'taux')::int < 5 THEN RAISE EXCEPTION 'taux: %', r; END IF;
    EXIT WHEN (r->>'reussi')::boolean;
  END LOOP;
  IF NOT (r->>'reussi')::boolean THEN RAISE EXCEPTION 'jamais reussi: %', r; END IF;
  r := public.pnj_debaucher(b, 'Banc Témoin (PNJ)', 'serveur', 3000, 50);
  RESET ROLE;
  IF (r->>'deja_parti')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'apres reussite: %', r; END IF;
  IF EXISTS (SELECT 1 FROM public.personnages_donnees, jsonb_array_elements(employes) e WHERE name = b AND e->>'nom' = 'Banc Témoin (PNJ)') THEN
    RAISE EXCEPTION 'PNJ encore chez B'; END IF;
  SELECT liquide INTO liq1 FROM public.personnages_donnees WHERE name = a;
  IF liq0 - liq1 <> paye THEN RAISE EXCEPTION 'paiement: % preleve, % attendu', liq0 - liq1, paye; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (% debauche chez %, % FR, taux %)', a, b, paye, r;
END $$;
