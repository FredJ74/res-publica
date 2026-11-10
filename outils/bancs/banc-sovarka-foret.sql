-- Banc annule de la foret profonde de Krasnov (a jouer apres la migration 20261110124500). Se termine toujours par une
-- exception : rien ne reste (groupe d'Arnie, position, inventaire, creatures, bataille).
DO $banc$
DECLARE u uuid; g1 jsonb; a1 jsonb; a2 jsonb; c1 jsonb; c2 jsonb; c3 jsonb; g2 jsonb; o1 jsonb; o2 jsonb; t1 jsonb; t2 jsonb; t3 jsonb; f1 jsonb;
        k1 jsonb; k2 jsonb; cb jsonb; iss jsonb; s1 jsonb; s2 jsonb; s3 jsonb; b0 integer; v_bois integer; v_type text; inv jsonb;
BEGIN
  SELECT user_id INTO u FROM public.personnages WHERE name = 'Arnie';
  DELETE FROM public.groupes_pj_adhesions WHERE membre = 'Arnie' OR chef = 'Arnie';
  UPDATE public.pnj_membres SET leader_pj = NULL WHERE leader_pj = 'Arnie';
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'ville_b', current_building = 'zone-production', current_room = 'zone_recolte',
    current_street = NULL, pa = 30, hp = 100, inventory = '[]'::jsonb, hospitalisation = NULL WHERE name = 'Arnie';
  SELECT coalesce(bonus_pa_differe, 0) INTO b0 FROM public.personnages_donnees WHERE name = 'Arnie';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/sovarka_foret_couper', true);
  SET LOCAL ROLE authenticated;
  g1 := public.navigation_interieure('zone-production', 'foret_vue_1');
  a1 := public.sovarka_foret_aller('00000000-0000-4000-8000-0000000fa001', 'enfoncer');
  a2 := public.sovarka_foret_aller('00000000-0000-4000-8000-0000000fa001', 'enfoncer');
  RESET ROLE;
  IF g1->>'raison' IS DISTINCT FROM 'foret_chemin_aleatoire' THEN RAISE EXCEPTION 'garde entree: %', g1; END IF;
  IF (a1->>'ok')::boolean IS NOT TRUE OR (a1->>'vue')::int NOT BETWEEN 1 AND 4 OR (a2->>'rejeu')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'enfoncer: % / %', a1, a2; END IF;
  IF (SELECT current_room FROM public.personnages_donnees WHERE name = 'Arnie') <> a1->>'room' THEN RAISE EXCEPTION 'position apres enfoncer'; END IF;
  -- Vue 1 : deux coupes, puis plus rien ; on ne ressort pas par la navigation libre.
  UPDATE public.personnages_donnees SET current_room = 'foret_vue_1' WHERE name = 'Arnie';
  DELETE FROM public.sovarka_foret_visites WHERE bucheron = 'Arnie';
  SET LOCAL ROLE authenticated;
  c1 := public.sovarka_foret_couper('00000000-0000-4000-8000-0000000fc001');
  c2 := public.sovarka_foret_couper('00000000-0000-4000-8000-0000000fc002');
  c3 := public.sovarka_foret_couper('00000000-0000-4000-8000-0000000fc003');
  g2 := public.navigation_interieure('zone-production', 'zone_recolte');
  RESET ROLE;
  IF (c1->>'ok')::boolean IS NOT TRUE OR (c1->>'quantite')::int NOT IN (2, 4) OR (c2->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'coupes vue 1: % / %', c1, c2; END IF;
  IF c3->>'raison' IS DISTINCT FROM 'coupes_epuisees' THEN RAISE EXCEPTION 'troisieme coupe: %', c3; END IF;
  IF g2->>'raison' IS DISTINCT FROM 'foret_perdu' THEN RAISE EXCEPTION 'garde sortie: %', g2; END IF;
  -- Vue 4 : une coupe, puis Olga.
  UPDATE public.personnages_donnees SET current_room = 'foret_vue_4' WHERE name = 'Arnie';
  SET LOCAL ROLE authenticated;
  o1 := public.sovarka_foret_couper('00000000-0000-4000-8000-0000000fc004');
  o2 := public.sovarka_foret_couper('00000000-0000-4000-8000-0000000fc005');
  RESET ROLE;
  IF (o1->>'quantite') IS NULL OR o2->>'rencontre' IS DISTINCT FROM 'olga' THEN RAISE EXCEPTION 'vue 4: % / %', o1, o2; END IF;
  IF (SELECT bonus_pa_differe FROM public.personnages_donnees WHERE name = 'Arnie') <> least(30, b0 + 2) THEN RAISE EXCEPTION 'repas Olga'; END IF;
  -- Vue 3 : une coupe, puis l'attaquant ; fuir lache le bois de la vue et ramene a l'entree.
  UPDATE public.personnages_donnees SET current_room = 'foret_vue_3' WHERE name = 'Arnie';
  SET LOCAL ROLE authenticated;
  t1 := public.sovarka_foret_couper('00000000-0000-4000-8000-0000000fc006');
  t2 := public.sovarka_foret_couper('00000000-0000-4000-8000-0000000fc007');
  t3 := public.sovarka_foret_aller('00000000-0000-4000-8000-0000000fa002', 'revenir');
  RESET ROLE;
  IF t2->>'rencontre' IS DISTINCT FROM 'attaque' OR NOT EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = t2->>'pnj' AND statut = 'actif' AND room_id = 'foret_vue_3') THEN RAISE EXCEPTION 'attaque: %', t2; END IF;
  IF t3->>'raison' IS DISTINCT FROM 'rencontre_en_cours' THEN RAISE EXCEPTION 'partir pendant la rencontre: %', t3; END IF;
  SELECT public.inventaire_quantite(inventory, 'bois')::int INTO v_bois FROM public.personnages_donnees WHERE name = 'Arnie';
  SET LOCAL ROLE authenticated;
  f1 := public.sovarka_foret_rencontre('00000000-0000-4000-8000-0000000fr001', 'fuir');
  RESET ROLE;
  IF (f1->>'ok')::boolean IS NOT TRUE OR (f1->>'bois_perdu')::int <> (t1->>'quantite')::int THEN RAISE EXCEPTION 'fuite: % (coupe %)', f1, t1; END IF;
  IF (SELECT current_room FROM public.personnages_donnees WHERE name = 'Arnie') <> 'zone_recolte'
     OR (SELECT public.inventaire_quantite(inventory, 'bois')::int FROM public.personnages_donnees WHERE name = 'Arnie') <> v_bois - (t1->>'quantite')::int THEN RAISE EXCEPTION 'apres fuite'; END IF;
  -- Combattre : la bataille est de type faune ; une victoire donne le butin au leader.
  UPDATE public.personnages_donnees SET current_room = 'foret_vue_3', pa = 30 WHERE name = 'Arnie';
  SET LOCAL ROLE authenticated;
  k1 := public.sovarka_foret_couper('00000000-0000-4000-8000-0000000fc008');
  k2 := public.sovarka_foret_couper('00000000-0000-4000-8000-0000000fc009');
  cb := public.combat_ouvrir(k2->>'pnj', 'mains', '00000000-0000-4000-8000-0000000fb001');
  RESET ROLE;
  IF (cb->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'combat_ouvrir: %', cb; END IF;
  IF (SELECT contexte->>'type' FROM public.batailles WHERE id = (cb->>'bataille')::bigint) <> 'faune' THEN RAISE EXCEPTION 'type de bataille'; END IF;
  iss := public.sovarka_foret_issue_combat_interne(k2->>'pnj', 'Arnie', 'neutralises');
  v_type := k2->>'creature';
  SELECT inventory INTO inv FROM public.personnages_donnees WHERE name = 'Arnie';
  IF public.inventaire_quantite(inv, 'viande') <> (CASE v_type WHEN 'loup' THEN 3 WHEN 'meute' THEN 6 ELSE 9 END)
     OR public.inventaire_quantite(inv, 'dent_ours') <> (CASE v_type WHEN 'ours' THEN 2 ELSE 0 END) THEN RAISE EXCEPTION 'butin %: %', v_type, inv; END IF;
  -- Ne pas se defendre : PA a 0 (l'hospitalisation suit a la validation de la transaction).
  UPDATE public.batailles SET statut = 'terminee' WHERE id = (cb->>'bataille')::bigint;
  UPDATE public.personnages_donnees SET current_room = 'foret_vue_3', pa = 30 WHERE name = 'Arnie';
  DELETE FROM public.sovarka_foret_visites WHERE bucheron = 'Arnie';
  SET LOCAL ROLE authenticated;
  s1 := public.sovarka_foret_couper('00000000-0000-4000-8000-0000000fc010');
  s2 := public.sovarka_foret_couper('00000000-0000-4000-8000-0000000fc011');
  s3 := public.sovarka_foret_rencontre('00000000-0000-4000-8000-0000000fr002', 'subir');
  RESET ROLE;
  IF (s3->>'ok')::boolean IS NOT TRUE OR (SELECT pa FROM public.personnages_donnees WHERE name = 'Arnie') <> 0 THEN RAISE EXCEPTION 'subir: % / %', s2, s3; END IF;
  RAISE EXCEPTION 'banc_ok vue_tiree=% coupes=%+% creature=% alerte=% butin=%', a1->>'vue', c1->>'quantite', c2->>'quantite', v_type, c2->>'fausse_alerte', iss->'butin';
END $banc$;
