-- BANC ANNULE -- salon de coiffure de Novomirsk (GAME-DESIGN-SALON-COIFFURE.md). A jouer APRES la
-- migration 20261106001000 (ou contre la production ou elle est appliquee), dans une transaction qui
-- finit par une exception : rien ne reste. Jean Jaaj au salon : refus sans prix, puis prix TEMOIN
-- (pose ici seulement, le vrai prix reste a decider par Fred), coupe +5 POP, CHA +1 jusqu'a minuit,
-- rejeu sans second paiement, deuxieme coupe refusee avant 3 jours, acceptee au 3e jour sans cumul du
-- CHA, refus hors du salon.
DO $$
DECLARE j text := 'Jean Jaaj'; uj uuid; r jsonb; r2 jsonb; q uuid := gen_random_uuid();
  arg0 numeric; arg1 numeric; pop0 numeric; pop1 numeric; caisse0 numeric; jr integer; n integer;
BEGIN
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = j;
  PERFORM set_config('request.path', '/rpc/banc', true);
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'capitale',
         current_building = 'salon-coiffure-novomirsk', current_room = 'salon_coiffure', current_street = NULL,
         resources = jsonb_set(coalesce(resources, '{}'::jsonb), '{pop}', '50'),
         effets_actifs = '[]'::jsonb WHERE name = j;
  DELETE FROM public.salon_coupes WHERE acteur = j;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);

  -- 1. Sans prix : refus nomme, rien debite.
  SELECT arg INTO arg0 FROM public.personnages_donnees WHERE name = j;
  SET LOCAL ROLE authenticated;
  r := public.salon_coupe(gen_random_uuid(), 'salon-soviet-capitale');
  IF r->>'raison' IS DISTINCT FROM 'prix_non_fixe' THEN RAISE EXCEPTION 'sans prix: %', r; END IF;
  r := public.salon_lire();
  IF r->'salon'->>'id' IS DISTINCT FROM 'salon-soviet-capitale' THEN RAISE EXCEPTION 'lecture: %', r; END IF;
  RESET ROLE;
  IF (SELECT arg FROM public.personnages_donnees WHERE name = j) <> arg0 THEN RAISE EXCEPTION 'debit sans prix'; END IF;

  -- 2. Prix temoin de 30, coupe : +5 POP, CHA +1, debit 30, caisse creditee.
  UPDATE public.entreprises SET data = jsonb_set(data, '{prestations,coupe,prixVente}', '30')
   WHERE id = 'salon-soviet-capitale';
  SELECT (data->>'caisse')::numeric INTO caisse0 FROM public.entreprises WHERE id = 'salon-soviet-capitale';
  SELECT (resources->>'pop')::numeric INTO pop0 FROM public.personnages_donnees WHERE name = j;
  SET LOCAL ROLE authenticated;
  r := public.salon_coupe(q, 'salon-soviet-capitale');
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'bonusCha')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'coupe: %', r; END IF;
  r2 := public.salon_coupe(q, 'salon-soviet-capitale');
  IF (r2->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'rejeu: %', r2; END IF;
  r2 := public.salon_coupe(gen_random_uuid(), 'salon-soviet-capitale');
  IF r2->>'raison' IS DISTINCT FROM 'cheveux_pas_repousses' THEN RAISE EXCEPTION 'delai: %', r2; END IF;
  RESET ROLE;
  SELECT arg, (resources->>'pop')::numeric INTO arg1, pop1 FROM public.personnages_donnees WHERE name = j;
  IF arg0 - arg1 <> 30 THEN RAISE EXCEPTION 'debit % (attendu 30, un seul paiement)', arg0 - arg1; END IF;
  IF pop1 - pop0 <> 5 THEN RAISE EXCEPTION 'pop +% (attendu 5)', pop1 - pop0; END IF;
  IF (SELECT (data->>'caisse')::numeric FROM public.entreprises WHERE id = 'salon-soviet-capitale') <= caisse0 THEN
    RAISE EXCEPTION 'caisse non creditee'; END IF;
  SELECT count(*) INTO n FROM public.personnages_donnees p, jsonb_array_elements(p.effets_actifs) e
   WHERE p.name = j AND e->>'cle' = 'coupe_cha' AND (e#>>'{deltas,CHA}')::int = 1;
  IF n <> 1 THEN RAISE EXCEPTION 'effet CHA: %', n; END IF;

  -- 3. Trois jours plus tard (derniere coupe reculee) : coupe acceptee, CHA toujours unique.
  SELECT jour_coupe INTO jr FROM public.salon_coupes WHERE acteur = j;
  UPDATE public.salon_coupes SET jour_coupe = jr - 3 WHERE acteur = j;
  SET LOCAL ROLE authenticated;
  r := public.salon_coupe(gen_random_uuid(), 'salon-soviet-capitale');
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'bonusCha')::boolean IS NOT FALSE THEN RAISE EXCEPTION '3e jour: %', r; END IF;
  RESET ROLE;
  SELECT count(*) INTO n FROM public.personnages_donnees p, jsonb_array_elements(p.effets_actifs) e
   WHERE p.name = j AND e->>'cle' = 'coupe_cha';
  IF n <> 1 THEN RAISE EXCEPTION 'cumul CHA: %', n; END IF;

  -- 4. Hors du salon : refus.
  UPDATE public.salon_coupes SET jour_coupe = jr - 3 WHERE acteur = j;
  UPDATE public.personnages_donnees SET current_building = 'garage-novomirsk' WHERE name = j;
  SET LOCAL ROLE authenticated;
  r := public.salon_coupe(gen_random_uuid(), 'salon-soviet-capitale');
  IF r->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'ailleurs: %', r; END IF;
  RESET ROLE;

  RAISE EXCEPTION 'banc_salon_coiffure_vert';
END $$;
