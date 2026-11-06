-- Banc annule de 20261103011000_agences_securite_pj (#135) : a jouer APRES la migration, dans la
-- meme transaction ; l'exception finale annule tout. PJ reels deplaces le temps de la transaction.
DO $$
DECLARE fonds text := 'fonds-republic-1791927686314-921164';  -- SLAVA, vitrine principale (Angie)
  ua uuid; uj uuid; ux uuid; nx text; r jsonb; ag text; c0 numeric; c1 numeric; out text := '';
BEGIN
  SELECT user_id INTO ua FROM public.personnages_donnees WHERE name = 'Angie Porcelana';
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = 'Jean Jaaj';
  SELECT name, user_id INTO nx, ux FROM public.personnages_donnees
   WHERE user_id IS NOT NULL AND name NOT IN ('Angie Porcelana','Jean Jaaj') ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale', current_building='centre-commercial',
         current_room='vitrine_principale', current_street=NULL, pa=greatest(coalesce(pa,0),10),
         liquide=greatest(coalesce(liquide,0),2000), arg=greatest(coalesce(arg,0),2000), hospitalisation=NULL
   WHERE name = 'Jean Jaaj';
  UPDATE public.personnages_donnees SET current_city='capitale', current_building='palais-gouvernement', current_room='hall',
         current_street=NULL, pa=greatest(coalesce(pa,0),10), liquide=greatest(coalesce(liquide,0),2000),
         arg=greatest(coalesce(arg,0),2000), hospitalisation=NULL WHERE name = nx;
  SELECT coalesce((data->>'caisse')::numeric,0) INTO c0 FROM public.entreprises WHERE id = fonds;
  SET LOCAL ROLE authenticated;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  r := public.agence_securite_ouvrir(fonds);
  out := out || 'ouvrir par un tiers=' || coalesce(r->>'raison','?');

  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  r := public.agence_securite_ouvrir(fonds);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'ouvrir: %', r; END IF;
  ag := r->>'employeur_id';
  out := out || ' | ouverte=' || ag;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  r := public.employeur_candidats(ag);
  out := out || ' | candidats=' || jsonb_array_length(r->'candidats') || ' (6)';
  r := public.employeur_embaucher_agence(ag, 'vivier-psm-as-01');
  out := out || ' | candidat d''un autre vivier=' || coalesce(r->>'raison','?');
  r := public.employeur_embaucher_agence(ag, 'vivier-lut-as-01');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'embaucher: %', r; END IF;
  SELECT coalesce((data->>'caisse')::numeric,0) INTO c1 FROM public.entreprises WHERE id = fonds;
  out := out || ' | embauche=' || (r->>'nom') || ', libelle=' || (r->>'role_libelle') || ', caisse +' || (c1 - c0) || ' (500)';
  out := out || ', pnj=' || (r->>'pnj_id');

  PERFORM set_config('request.jwt.claims', json_build_object('sub', ux, 'role', 'authenticated')::text, true);
  r := public.employeur_embaucher_agence(ag, 'vivier-lut-as-02');
  out := out || ' | absent du local=' || coalesce(r->>'raison','?');
  r := public.employeur_embaucher('vivier-lut-as-02');
  out := out || ' | embauche directe au vivier=' || coalesce(r->>'raison','?');

  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  r := public.agence_securite_fermer(fonds);
  out := out || ' | fermer par un tiers=' || coalesce(r->>'raison','?');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  r := public.agence_securite_fermer(fonds);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  r := public.employeur_embaucher_agence(ag, 'vivier-lut-as-03');
  out := out || ' | apres fermeture=' || coalesce(r->>'raison','?');
  out := out || ' | lire=' || public.agence_securite_lire(fonds)::text;
  RAISE EXCEPTION 'BANC (annule) : %', out;
END $$;
