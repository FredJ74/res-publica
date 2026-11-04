-- A jouer APRES le corps de la migration 20261104110000, dans la meme transaction annulee.
-- Jean Jaaj lance une rumeur contre La Main Noire (chef : Angie Porcelana) ; jet force a reussir.
DO $$
DECLARE n text := 'Jean Jaaj'; u uuid; r jsonb; org text := 'orga_1792166277858'; m0 integer; m1 integer; corps text;
BEGIN
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;
  UPDATE public.personnages_donnees SET pa = greatest(coalesce(pa,0), 10) WHERE name = n;
  SELECT count(*) INTO m0 FROM public.mails WHERE to_player = 'Angie Porcelana';
  PERFORM setseed(0.1);  -- premier random() < 0.75 : rumeur reussie
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/rumeur_lancer', true);
  SET LOCAL ROLE authenticated;
  r := public.rumeur_lancer('organisation', org, 'Banc : texte de rumeur', 'La Main Noire', 1, 0);
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'reussi')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'rumeur: %', r; END IF;
  SELECT count(*) INTO m1 FROM public.mails WHERE to_player = 'Angie Porcelana';
  SELECT body INTO corps FROM public.mails WHERE to_player = 'Angie Porcelana' ORDER BY id DESC LIMIT 1;
  IF m1 <> m0 + 1 OR corps ILIKE '%' || n || '%' THEN RAISE EXCEPTION 'courrier: % -> %, corps %', m0, m1, corps; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (courrier au chef %->%, sans nom d auteur)', m0, m1;
END $$;
