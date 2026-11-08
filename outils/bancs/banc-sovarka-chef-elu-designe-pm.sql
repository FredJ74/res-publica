-- A jouer APRES la migration 20261108001500, dans la meme transaction annulee (rien ne reste).
-- A fonde un parti, B en est membre, le parti a gagne la semaine a la gloire. A president :
-- « peut_designer_pm » vrai, desigation de B acceptee (B pm) ; A redevient sans poste : refus
-- chef_pm_d_office ; le president ne peut toujours pas nommer le pm (pm_impose_par_le_parti).
DO $$
DECLARE a text; ua uuid; b text; r jsonb; v_parti text; t text;
BEGIN
  SELECT name, user_id INTO a, ua FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 ORDER BY name LIMIT 1;
  SELECT name INTO b FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 AND name <> a ORDER BY name LIMIT 1;
  DELETE FROM public.organisations WHERE data IS JSON OBJECT AND public.sovarka_est_parti_interne(data::jsonb);
  UPDATE public.personnages_donnees SET country='soviet', current_city='capitale', current_building='mairie-capitale',
    current_room='salle_partis', pa=20, hospitalisation=NULL, liquide=greatest(coalesce(liquide,0),1000), poste=NULL
   WHERE name IN (a, b);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'fonder', NULL, '{"nom":"Parti du Banc"}');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'fonder: %', r; END IF;
  v_parti := r->>'parti';
  RESET ROLE;
  UPDATE public.organisations SET data = jsonb_set(data::jsonb, '{membres}', data::jsonb->'membres'
      || jsonb_build_array(jsonb_build_object('nom', b, 'grade', 'Membre', 'gradeIdx', 0)))::text WHERE id = v_parti;
  UPDATE public.cycles_electoraux SET data = jsonb_set(coalesce(data::jsonb, '{}'), '{gloire}',
      coalesce(data::jsonb->'gloire', '{}') || jsonb_build_object('vainqueur', v_parti))::text WHERE id = 'soviet_gloire_partis';
  IF public.sovarka_gloire_vainqueur() IS DISTINCT FROM v_parti THEN RAISE EXCEPTION 'vainqueur non pose'; END IF;
  UPDATE public.personnages_donnees SET poste = '{"id":"president"}'::jsonb WHERE name = a;
  SET LOCAL ROLE authenticated;
  r := public.sovarka_partis_liste();
  IF (r->'mon_parti'->>'peut_designer_pm')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'drapeau: %', r->'mon_parti'; END IF;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'designer_pm', v_parti, jsonb_build_object('nom', a));
  IF r->>'raison' IS DISTINCT FROM 'membre_absent' THEN RAISE EXCEPTION 'soi-meme: %', r; END IF;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'designer_pm', v_parti, jsonb_build_object('nom', b));
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'designer: %', r; END IF;
  RESET ROLE;
  SELECT titulaire INTO t FROM public.postes_attribues WHERE id = 'soviet_pm_national';
  IF t IS DISTINCT FROM b THEN RAISE EXCEPTION 'pm attendu %, obtenu %', b, t; END IF;
  IF public.sovarka_nomination_refus('pm', a, 'joueur') IS DISTINCT FROM 'pm_impose_par_le_parti' THEN RAISE EXCEPTION 'garde pm'; END IF;
  UPDATE public.personnages_donnees SET poste = NULL WHERE name = a;
  SET LOCAL ROLE authenticated;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'designer_pm', v_parti, jsonb_build_object('nom', b));
  IF r->>'raison' IS DISTINCT FROM 'chef_pm_d_office' THEN RAISE EXCEPTION 'chef sans poste: %', r; END IF;
  RESET ROLE;
  RAISE EXCEPTION 'BANC_OK A=% B=% pm=%', a, b, t;
END $$;
