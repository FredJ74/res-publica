-- Banc : combat contre une bête de la forêt de Krasnov (migration 20261114143000_combat_faune_hostilite).
-- Transaction toujours annulée : le banc se termine par une exception BANC_COMBAT_FAUNE_OK ou par l'échec constaté.
-- Joue le vrai chemin : rencontre ours, combat_ouvrir à mains nues, rounds du moteur, finalisation.
DO $banc$
DECLARE
  v_pj text; v_uid uuid; v_id bigint; v_pnj text; o jsonb; r jsonb; b record; i integer;
  v_pa_pj integer; v_pa_ours integer; v_coups integer := 0; v_inv jsonb; e jsonb; v_rid bigint;
BEGIN
  PERFORM setseed(0.42);
  SELECT p.name, p.user_id INTO v_pj, v_uid FROM public.personnages p JOIN public.personnages_donnees d ON d.name = p.name
   WHERE p.user_id IS NOT NULL AND d.country = 'soviet' AND NOT EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE membre = p.name OR chef = p.name)
   ORDER BY (p.name = 'Arnie') DESC, p.name LIMIT 1;
  IF v_pj IS NULL THEN
    SELECT p.name, p.user_id INTO v_pj, v_uid FROM public.personnages p WHERE p.user_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE membre = p.name OR chef = p.name) ORDER BY (p.name = 'Arnie') DESC LIMIT 1;
  END IF;
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
  IF public.mon_personnage() IS DISTINCT FROM v_pj THEN RAISE EXCEPTION 'BANC_ECHEC identite %', v_pj; END IF;

  -- Le bûcheron est dans le ravin, en forme, hors de tout combat.
  UPDATE public.batailles SET statut = 'terminee', fin_ts = now() WHERE statut = 'en_cours'
     AND id IN (SELECT bataille_id FROM public.batailles_engagements WHERE personnage = v_pj);
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'ville_b', current_building = 'zone-production',
         current_room = 'foret_vue_3', pa = 12, hp = 100, est_emprisonne = NULL, hospitalisation = NULL WHERE name = v_pj;
  DELETE FROM public.sovarka_foret_rencontres WHERE bucheron = v_pj AND statut = 'en_attente';
  INSERT INTO public.sovarka_foret_rencontres (bucheron, vue, creature, statut) VALUES (v_pj, 3, 'ours', 'en_attente') RETURNING id INTO v_rid;
  v_pnj := 'faune:krasnov:' || v_rid;
  INSERT INTO public.pnj_membres (id, famille, nom, pays, ville, building_id, room_id, classe, pa, proprietaire_institution, proprietaire_perimetre, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES (v_pnj, 'employe', 'Ours', 'soviet', 'ville_b', 'zone-production', 'foret_vue_3', 'beta', 36, 'faune', 'soviet:ville_b:foret', 4, 4, 26, 12, 12, 4);
  UPDATE public.sovarka_foret_rencontres SET pnj_id = v_pnj WHERE id = v_rid;

  o := public.combat_ouvrir(v_pnj, 'mains', gen_random_uuid());
  IF coalesce((o->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'BANC_ECHEC ouverture %', o; END IF;
  v_id := (o->>'bataille')::bigint;
  SELECT * INTO b FROM public.batailles WHERE id = v_id;
  IF b.contexte->>'type' <> 'faune' THEN RAISE EXCEPTION 'BANC_ECHEC type %', b.contexte->>'type'; END IF;
  IF coalesce(array_length(public.militaire_camps_hostiles(v_id, b.camp_a), 1), 0) <> 1 THEN RAISE EXCEPTION 'BANC_ECHEC camp hostile absent'; END IF;
  IF (SELECT count(*) FROM public.militaire_bataille_combattants(v_id, b.camp_b)) <> 1 THEN RAISE EXCEPTION 'BANC_ECHEC ours non combattant'; END IF;
  IF (SELECT bonus_arme FROM public.militaire_bataille_combattants(v_id, b.camp_b)) <> 12 THEN RAISE EXCEPTION 'BANC_ECHEC griffes absentes'; END IF;
  IF EXISTS (SELECT 1 FROM public.mails WHERE to_player = v_pj AND subject = 'Affrontement' AND body LIKE '%Référence : ' || v_id || '.%') THEN
    RAISE EXCEPTION 'BANC_ECHEC mail Affrontement envoye pour une bete'; END IF;
  e := public.militaire_bataille_etat(v_id);
  IF e->'bataille'->>'type' <> 'faune' OR e->'bataille'->>'adversaire_nom' <> 'Ours' THEN RAISE EXCEPTION 'BANC_ECHEC etat %', e; END IF;

  -- Rounds : des coups doivent être portés des deux côtés au fil du combat.
  FOR i IN 1..12 LOOP
    r := public.militaire_bataille_round(v_id);
    IF coalesce((r->>'ok')::boolean, false) IS NOT TRUE THEN EXIT; END IF;
    EXIT WHEN (r->>'terminee')::boolean;
  END LOOP;
  SELECT coalesce(sum((rapport->>'mes_pa_perdus')::integer), 0) INTO v_coups FROM public.batailles_rounds WHERE bataille_id = v_id;
  IF v_coups = 0 THEN RAISE EXCEPTION 'BANC_ECHEC aucun coup porte en % rounds', i; END IF;
  SELECT * INTO b FROM public.batailles WHERE id = v_id;
  IF b.statut <> 'terminee' THEN RAISE EXCEPTION 'BANC_ECHEC combat non termine'; END IF;
  IF b.contexte->'resultat_civil'->>'issue' NOT IN ('tues', 'fuite', 'defaite') THEN RAISE EXCEPTION 'BANC_ECHEC issue %', b.contexte->'resultat_civil'; END IF;
  -- Le PJ tombé ne part jamais à la caserne.
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_pj AND current_building = 'caserne-militaire') THEN RAISE EXCEPTION 'BANC_ECHEC PJ envoye a la caserne'; END IF;
  -- Butin seulement si l'ours est tué.
  IF b.contexte->'resultat_civil'->>'issue' <> 'tues' AND EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(b.contexte->'resultat_civil'->'butin', '[]')) x WHERE x->>'stackKey' IN ('viande', 'dent_ours')) THEN
    RAISE EXCEPTION 'BANC_ECHEC butin sans victoire'; END IF;
  RAISE NOTICE 'combat 1 : % rounds, % PA perdus au total, issue %', b.round_courant, v_coups, b.contexte->'resultat_civil'->>'issue';

  -- Fuite de la bête : finalisation directe sur un combat où l'ours a décroché.
  UPDATE public.batailles SET statut = 'terminee', issue = 'victoire_' || camp_a, contexte = contexte - 'resultat_civil' WHERE id = v_id;
  UPDATE public.batailles_engagements SET etat_final = 'replie', sorti_round = 5 WHERE bataille_id = v_id AND pnj_id IS NOT NULL;
  UPDATE public.sovarka_foret_rencontres SET statut = 'en_attente', clos_le = NULL WHERE id = v_rid;
  UPDATE public.personnages_donnees SET inventory = '[]'::jsonb WHERE name = v_pj;
  r := public.combat_finaliser_interne(v_id);
  IF r->>'issue' <> 'fuite' THEN RAISE EXCEPTION 'BANC_ECHEC fuite non reconnue %', r; END IF;
  SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name = v_pj;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) x WHERE x->>'stackKey' IN ('viande', 'textile', 'dent_ours')) THEN RAISE EXCEPTION 'BANC_ECHEC butin apres fuite %', v_inv; END IF;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) x WHERE x->>'stackKey' = 'bois') THEN RAISE EXCEPTION 'BANC_ECHEC bois absent apres fuite %', v_inv; END IF;
  IF (SELECT statut FROM public.sovarka_foret_rencontres WHERE id = v_rid) <> 'fuite' THEN RAISE EXCEPTION 'BANC_ECHEC statut rencontre'; END IF;

  -- Victoire réelle : ours tué, butin complet.
  UPDATE public.batailles SET contexte = contexte - 'resultat_civil' WHERE id = v_id;
  UPDATE public.batailles_engagements SET etat_final = 'mort' WHERE bataille_id = v_id AND pnj_id IS NOT NULL;
  UPDATE public.sovarka_foret_rencontres SET statut = 'en_attente', clos_le = NULL WHERE id = v_rid;
  UPDATE public.personnages_donnees SET inventory = '[]'::jsonb WHERE name = v_pj;
  r := public.combat_finaliser_interne(v_id);
  IF r->>'issue' <> 'tues' THEN RAISE EXCEPTION 'BANC_ECHEC victoire %', r; END IF;
  SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name = v_pj;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) x WHERE x->>'stackKey' = 'dent_ours') THEN RAISE EXCEPTION 'BANC_ECHEC trophee absent'; END IF;

  RAISE EXCEPTION 'BANC_COMBAT_FAUNE_OK';
END $banc$;
