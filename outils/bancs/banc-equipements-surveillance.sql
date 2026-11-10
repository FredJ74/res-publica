-- Banc annule (se termine par RAISE EXCEPTION 'BANC OK' : rien n'est conserve). A jouer sur la base apres la migration
-- 20261111000500_equipements_surveillance. A pose une camera dans un hall (bureau equipe et loue), B y passe, le rapport
-- le cite ; B fouille avec le Couinator et emporte la camera ; A recoit « Signal perdu ».
DO $$
DECLARE a text; ua uuid; b text; ub uuid; r jsonb; v_cam uuid; v_txt text; v_mails0 integer; v_mails1 integer; v_essais integer := 0;
BEGIN
  SELECT name, user_id INTO a, ua FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 ORDER BY name LIMIT 1;
  SELECT name, user_id INTO b, ub FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 AND name <> a ORDER BY name LIMIT 1;
  INSERT INTO public.locations_actives (id, country, data) VALUES ('republic:banc-bureau:bureau_banc:capitale', 'republic', jsonb_build_object('locataire', 'pj:' || a))
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data;
  DELETE FROM public.cameras_posees WHERE proprietaire = a;
  INSERT INTO public.equipements_installes (proprietaire, pays, ville, batiment, piece, generique_id, objet) VALUES
    (a, 'republic', 'capitale', 'banc-bureau', 'bureau_banc', 'ordinateur-complet', '{"generique_id":"ordinateur-complet"}'),
    (a, 'republic', 'capitale', 'banc-bureau', 'bureau_banc', 'box-internet', '{"generique_id":"box-internet"}');
  IF public.equipements_ordinateurs_connectes_interne(a) < 1 THEN RAISE EXCEPTION 'ordinateur connecte absent'; END IF;
  UPDATE public.actes_illegaux SET detect_rate = 0 WHERE fn = 'poser_camera';
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale', current_building = 'banc-hall', current_room = 'hall',
    current_street = NULL, pa = 20, est_emprisonne = NULL, resources = jsonb_set(coalesce(resources, '{}'::jsonb), '{dis}', '100'),
    inventory = '[{"id":"obj-cam-banc","type":"camera_surveillance_commerce","generique_id":"camera-de-surveillance","name":"Caméra de surveillance"}]'::jsonb
   WHERE name = a;
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale', current_building = 'banc-hall', current_room = 'hall',
    current_street = NULL, pa = 20, est_emprisonne = NULL, stats = jsonb_set(coalesce(stats, '{}'::jsonb), '{PER}', '30'),
    inventory = '[{"id":"obj-couin-banc","type":"couinator_3000_commerce","generique_id":"couinator-3000","name":"Couinator 3000"}]'::jsonb
   WHERE name = b;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/camera_poser', true);  -- sinon le garde d'inventaire ignore l'ecriture
  SET LOCAL ROLE authenticated;
  r := public.camera_poser('Hall du banc');
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'legale')::boolean OR (r->>'repere')::boolean THEN RAISE EXCEPTION 'poser: %', r; END IF;
  v_cam := (r->>'camera')::uuid;
  IF (SELECT pa FROM public.personnages_donnees WHERE name = a) <> 19 THEN RAISE EXCEPTION 'PA de pose'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees, jsonb_array_elements(historique_crimes) t WHERE name = a AND t->>'acte' = 'poser_camera') THEN
    RAISE EXCEPTION 'trace de pose absente'; END IF;
  -- Passage de B : entree il y a 30 min, sortie il y a 10 min.
  INSERT INTO public.historique_deplacements (name, country, city, building_id, room_id, jour, heure, created_at) VALUES
    (b, 'republic', 'capitale', 'banc-hall', 'hall', 1, '00:00', now() - interval '30 minutes'),
    (b, 'republic', 'capitale', 'banc-ailleurs', 'salle', 1, '00:20', now() - interval '10 minutes');
  UPDATE public.cameras_posees SET dernier_rapport = now() - interval '2 hours', frequence_h = 1 WHERE id = v_cam;
  IF NOT public.camera_operationnelle_interne(v_cam) THEN RAISE EXCEPTION 'camera non operationnelle'; END IF;
  v_txt := public.camera_rapport_texte_interne((SELECT c FROM public.cameras_posees c WHERE id = v_cam), now() - interval '2 hours', now());
  IF v_txt IS NULL OR position(b IN v_txt) = 0 OR position('sortie' IN v_txt) = 0 THEN RAISE EXCEPTION 'rapport: %', v_txt; END IF;
  SELECT count(*) INTO v_mails0 FROM public.mails WHERE to_player = a;
  r := public.cameras_rapports_passe();
  SELECT count(*) INTO v_mails1 FROM public.mails WHERE to_player = a;
  IF v_mails1 <> v_mails0 + 1 THEN RAISE EXCEPTION 'mail de rapport absent (% -> %)', v_mails0, v_mails1; END IF;
  -- B fouille (PER 30 + Couinator : 95 %) jusqu'a trouver.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/fouiller_lieux', true);
  SET LOCAL ROLE authenticated;
  LOOP
    v_essais := v_essais + 1;
    r := public.fouiller_lieux();
    EXIT WHEN (r->>'nb')::int = 1 OR v_essais >= 5;
  END LOOP;
  IF (r->>'couinator')::boolean IS NOT TRUE OR (r->>'nb')::int <> 1 THEN RESET ROLE; RAISE EXCEPTION 'fouille: %', r; END IF;
  r := public.camera_trouvee_traiter(v_cam, 'emporter');
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'emporter: %', r; END IF;
  IF EXISTS (SELECT 1 FROM public.cameras_posees WHERE id = v_cam) THEN RAISE EXCEPTION 'camera encore posee'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees, jsonb_array_elements(inventory) o WHERE name = b AND o->>'generique_id' = 'camera-de-surveillance') THEN
    RAISE EXCEPTION 'camera absente de l''inventaire de B'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.mails WHERE to_player = a AND subject LIKE 'Signal perdu%') THEN RAISE EXCEPTION 'signal perdu absent'; END IF;
  RAISE EXCEPTION 'BANC OK : pose illegale tracee (1 PA), rapport (% essais de fouille), camera emportee, signal perdu', v_essais;
END $$;
