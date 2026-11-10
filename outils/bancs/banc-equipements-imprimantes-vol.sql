-- Banc annule (RAISE EXCEPTION 'BANC OK' final). A imprime un faux, le reimprime, un couteau en plastique, achete un plan
-- et imprime le souvenir ; B vole l'ordinateur de A (detection neutralisee) et emporte ses dossiers.
DO $$
DECLARE a text; ua uuid; b text; ub uuid; r jsonb; v_essais integer := 0; v_doss uuid; v_plan text; v_ordi uuid;
BEGIN
  SELECT name, user_id INTO a, ua FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 ORDER BY name LIMIT 1;
  SELECT name, user_id INTO b, ub FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 AND name <> a ORDER BY name LIMIT 1;
  INSERT INTO public.locations_actives (id, country, data) VALUES ('republic:banc-bureau:bureau_banc:capitale', 'republic', jsonb_build_object('locataire', 'pj:' || a))
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data;
  INSERT INTO public.equipements_installes (proprietaire, pays, ville, batiment, piece, generique_id, objet) VALUES
    (a, 'republic', 'capitale', 'banc-bureau', 'bureau_banc', 'box-internet', '{"id":"obj-box-banc-a","generique_id":"box-internet"}'),
    (a, 'republic', 'capitale', 'banc-bureau', 'bureau_banc', 'imprimante-papier', '{"id":"obj-imp-banc-a","generique_id":"imprimante-papier"}'),
    (a, 'republic', 'capitale', 'banc-bureau', 'bureau_banc', 'imprimante-3d', '{"id":"obj-3d-banc-a","generique_id":"imprimante-3d"}');
  INSERT INTO public.equipements_installes (proprietaire, pays, ville, batiment, piece, generique_id, objet) VALUES
    (a, 'republic', 'capitale', 'banc-bureau', 'bureau_banc', 'ordinateur-complet', '{"id":"obj-ordi-banc-a","generique_id":"ordinateur-complet"}')
  RETURNING id INTO v_ordi;
  SELECT id INTO v_plan FROM public.recettes_commerce WHERE famille_produit_marche = 'carte_postale' ORDER BY id LIMIT 1;
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale', current_building = 'banc-bureau', current_room = 'bureau_banc',
    current_street = NULL, pa = 60, liquide = greatest(coalesce(liquide, 0), 5000),
    inventory = '[{"id":"cart","generique_id":"cartouche-encre","stackKey":"cartouche-encre","stackable":true,"qty":8},
                  {"id":"plast","stackKey":"derives_petrochimiques","stackable":true,"qty":4}]'::jsonb WHERE name = a;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/banc', true);
  SET LOCAL ROLE authenticated;
  LOOP v_essais := v_essais + 1; r := public.faux_document_imprimer('faux_contrat'); EXIT WHEN (r->>'reussi')::boolean OR v_essais >= 5; END LOOP;
  IF (r->>'reussi')::boolean IS NOT TRUE OR r->>'dossier' IS NULL THEN RESET ROLE; RAISE EXCEPTION 'faux: %', r; END IF;
  v_doss := (r->>'dossier')::uuid;
  r := public.dossier_imprimer(v_doss);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RESET ROLE; RAISE EXCEPTION 'reimpression: %', r; END IF;
  r := public.imprimer_couteau_plastique();
  IF (r->>'ok')::boolean IS NOT TRUE THEN RESET ROLE; RAISE EXCEPTION 'couteau: %', r; END IF;
  r := public.plans3d_lire();
  IF jsonb_array_length(r->'plans') < 1 THEN RESET ROLE; RAISE EXCEPTION 'plans: %', r; END IF;
  r := public.plan3d_obtenir(v_plan, 'acheter');
  IF (r->>'reussi')::boolean IS NOT TRUE THEN RESET ROLE; RAISE EXCEPTION 'plan: %', r; END IF;
  r := public.dossier_imprimer((r->>'dossier')::uuid);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RESET ROLE; RAISE EXCEPTION 'souvenir: %', r; END IF;
  r := public.organisation_materiel_lire();
  IF (r->>'ok')::boolean IS NOT TRUE THEN RESET ROLE; RAISE EXCEPTION 'orga: %', r; END IF;
  RESET ROLE;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees, jsonb_array_elements(inventory) o WHERE name = a AND o->>'type' = 'couteau_plastique')
     OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees, jsonb_array_elements(inventory) o WHERE name = a AND o->>'recette_id' = v_plan)
     OR (SELECT count(*) FROM public.personnages_donnees, jsonb_array_elements(inventory) o WHERE name = a AND o->>'type' = 'document_falsifie') < 2 THEN
    RAISE EXCEPTION 'objets imprimes absents'; END IF;
  -- B vole l'ordinateur.
  UPDATE public.actes_illegaux SET detect_rate = 0 WHERE fn = 'vol';
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale', current_building = 'banc-bureau', current_room = 'bureau_banc',
    current_street = NULL, pa = 30, inventory = '[]'::jsonb, stats = jsonb_set(coalesce(stats, '{}'::jsonb), '{DUP}', '80'),
    resources = jsonb_set(coalesce(resources, '{}'::jsonb), '{dis}', '100') WHERE name = b;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  v_essais := 0;
  LOOP v_essais := v_essais + 1; r := public.voler_materiel(v_ordi); EXIT WHEN (r->>'reussi')::boolean OR (r->>'repere')::boolean OR v_essais >= 4; END LOOP;
  RESET ROLE;
  IF (r->>'reussi')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'vol: %', r; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees, jsonb_array_elements(inventory) o WHERE name = b AND o->>'id' = 'obj-ordi-banc-a') THEN
    RAISE EXCEPTION 'ordinateur absent chez B'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.dossiers_informatiques WHERE objet_id = 'obj-ordi-banc-a') THEN RAISE EXCEPTION 'dossiers perdus'; END IF;
  RAISE EXCEPTION 'BANC OK : faux (% essais), reimpression, couteau, plan achete et imprime, vol de l''ordinateur avec ses dossiers', v_essais;
END $$;
