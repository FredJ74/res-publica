-- Banc annule de 20261103090000_trading_option_premium_emplacements : a jouer APRES la migration, dans
-- la meme transaction ; l'exception finale annule tout. Jean Jaaj (bureau prestige loue).
DO $$
DECLARE uj uuid; ux uuid; nx text; r jsonb; out text := '';
BEGIN
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = 'Jean Jaaj';
  SELECT name, user_id INTO nx, ux FROM public.personnages_donnees WHERE user_id IS NOT NULL AND name <> 'Jean Jaaj' ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale', current_building='centre-affaires',
         current_room='bureau_prestige', current_street=NULL,
         inventory = coalesce(CASE WHEN jsonb_typeof(inventory)='array' THEN inventory END,'[]'::jsonb)
           || '[{"name":"Ordinateur","generique_id":"ordinateur-complet","icon":"ti-package"}]'::jsonb
   WHERE name = 'Jean Jaaj';
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale', current_building='centre-affaires',
         current_room='banc_bureau_sans_bail', current_street=NULL WHERE name = nx;
  DELETE FROM public.equipements_installes WHERE pays='republic' AND ville='capitale' AND batiment='centre-affaires' AND piece='bureau_prestige';
  INSERT INTO public.equipements_installes (proprietaire, pays, ville, batiment, piece, generique_id, objet)
  SELECT 'Banc ' || g, 'republic', 'capitale', 'centre-affaires', 'bureau_prestige', 'box-internet', '{"name":"Box banc"}'
    FROM generate_series(1, 3) g;
  IF public.equipements_emplacements_interne('republic','capitale','centre-affaires','bureau_prestige') <> 3 THEN RAISE EXCEPTION 'banc: gratuit <> 3'; END IF;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/equipement_installer', true);
  r := public.equipement_installer('ordinateur-complet');
  IF r->>'raison' IS DISTINCT FROM 'emplacements_pleins' OR (r->>'emplacements')::int <> 3 THEN RAISE EXCEPTION 'banc 1: %', r; END IF;
  r := public.equipement_option_premium_activer();
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'emplacements')::int <> 6 THEN RAISE EXCEPTION 'banc 2: %', r; END IF;
  r := public.equipement_option_premium_activer();
  IF r->>'raison' IS DISTINCT FROM 'option_deja_active' THEN RAISE EXCEPTION 'banc 3: %', r; END IF;
  r := public.equipement_installer('ordinateur-complet');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'banc 4: %', r; END IF;
  r := public.equipements_local_lire();
  IF (r->>'emplacements')::int <> 6 OR (r->>'option_premium')::boolean IS NOT TRUE OR jsonb_array_length(r->'installes') <> 4 THEN RAISE EXCEPTION 'banc 5: %', r; END IF;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ux, 'role', 'authenticated')::text, true);
  r := public.equipement_option_premium_activer();
  IF r->>'raison' IS DISTINCT FROM 'pas_de_jouissance' THEN RAISE EXCEPTION 'banc 6: %', r; END IF;
  RESET ROLE;
  -- Option d'un acheteur sans bail : sans effet, puis effacee par la passe de nuit.
  INSERT INTO public.bureaux_option_premium (acheteur, pays, ville, batiment, piece) VALUES (nx, 'republic', 'capitale', 'centre-affaires', 'banc_bureau_sans_bail');
  IF public.equipements_emplacements_interne('republic','capitale','centre-affaires','banc_bureau_sans_bail') <> 3 THEN RAISE EXCEPTION 'banc 7: option sans bail active'; END IF;
  r := public.equipements_jouissance_nuit();
  IF EXISTS (SELECT 1 FROM public.bureaux_option_premium WHERE acheteur = nx) THEN RAISE EXCEPTION 'banc 8: option non effacee'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.bureaux_option_premium WHERE acheteur = 'Jean Jaaj') THEN RAISE EXCEPTION 'banc 8: option valide effacee'; END IF;
  IF has_function_privilege('authenticated', 'public.equipements_emplacements_interne(text,text,text,text)', 'EXECUTE') THEN RAISE EXCEPTION 'banc 9: interne ouverte'; END IF;
  RAISE EXCEPTION 'BANC OK : rien ne doit rester';
END $$;
