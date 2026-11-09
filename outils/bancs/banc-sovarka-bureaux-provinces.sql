-- BANC ANNULE -- bureaux des centres d'affaires de Starovka et Krasnov (migration 20261109003000).
-- A concatener derriere la migration, dans une transaction qui finit par une exception : rien ne reste.
-- Acteurs : Jean Jaaj (Krasnov), Angie Porcelana (Starovka).
DO $$
DECLARE j text := 'Jean Jaaj'; g text := 'Angie Porcelana'; uj uuid; ug uuid; r jsonb; pa0 integer; pa1 integer;
BEGIN
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = j;
  SELECT user_id INTO ug FROM public.personnages_donnees WHERE name = g;
  PERFORM set_config('request.path', '/rpc/banc', true);
  UPDATE public.personnages_donnees SET country='soviet', current_street=NULL, pa=20, hp=greatest(coalesce(hp,0),50),
         current_building='centre-affaires' WHERE name IN (j, g);
  UPDATE public.personnages_donnees SET current_city='ville_b', current_room='bureau_standard' WHERE name = j;
  UPDATE public.personnages_donnees SET current_city='ville_a', current_room='open_space' WHERE name = g;
  DELETE FROM public.sovarka_demandes WHERE demandeur IN (j, g) AND statut IN ('en_attente','acceptee','attribuee');

  -- 1. Krasnov : le guichet privé est fermé, refus nommé, rien de payé.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  SELECT pa INTO pa0 FROM public.personnages_donnees WHERE name = j;
  SET LOCAL ROLE authenticated;
  r := public.local_louer(gen_random_uuid(), NULL);
  IF r->>'raison' IS DISTINCT FROM 'attribution_municipale' THEN RAISE EXCEPTION 'guichet Krasnov: %', r; END IF;
  -- 2. Demande de location depuis le bureau : acceptée, 1 PA, local nommé.
  r := public.sovarka_demande_location('centre-affaires', 'bureau_standard', '');
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'local' IS DISTINCT FROM 'Bureau standard' THEN RAISE EXCEPTION 'demande Krasnov: %', r; END IF;
  RESET ROLE;
  SELECT pa INTO pa1 FROM public.personnages_donnees WHERE name = j;
  IF pa1 <> pa0 - 1 THEN RAISE EXCEPTION 'PA Krasnov: % -> %', pa0, pa1; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sovarka_demandes WHERE demandeur = j AND ville = 'ville_b' AND statut = 'en_attente'
                  AND local_souhaite_piece = 'bureau_standard') THEN RAISE EXCEPTION 'dossier Krasnov absent'; END IF;

  -- 3. Starovka : même chose depuis l'open space.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ug, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.local_louer(gen_random_uuid(), NULL);
  IF r->>'raison' IS DISTINCT FROM 'attribution_municipale' THEN RAISE EXCEPTION 'guichet Starovka: %', r; END IF;
  r := public.sovarka_demande_location('centre-affaires', 'open_space', 'Un cabinet de traduction');
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'local' IS DISTINCT FROM 'Open space' THEN RAISE EXCEPTION 'demande Starovka: %', r; END IF;
  RESET ROLE;

  -- 4. Plafonds déclarés.
  IF (SELECT string_agg(piece||'='||plafond, ',' ORDER BY piece) FROM public.sovarka_locaux
        WHERE ville = 'ville_a' AND batiment = 'centre-affaires') <> 'bureau_prestige=100,bureau_standard=50,open_space=20' THEN
    RAISE EXCEPTION 'plafonds Starovka'; END IF;

  RAISE EXCEPTION 'BANC VERT : bureaux de province (rien ne reste)';
END $$;
