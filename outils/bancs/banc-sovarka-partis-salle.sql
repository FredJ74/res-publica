-- A jouer APRES la migration 20261107184000, dans la meme transaction annulee (rien ne reste).
-- A fonde un parti dans la salle des partis de Novomirsk ; B demande, refus (-2 POP), redemande,
-- prix 30, acceptation payee ; C sans parti ne peut pas postuler ; ministres hors parti ; le chef
-- doit designer un successeur ; le dernier membre dissout le parti ; portes generiques fermees.
DO $$
DECLARE a text; ua uuid; b text; ub uuid; c text; uc uuid; r jsonb; q uuid := gen_random_uuid(); v_parti text; v_p2 text;
  liqb0 numeric; liqb1 numeric; pa_a0 int; pa_a1 int; d jsonb;
BEGIN
  SELECT name, user_id INTO a, ua FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 ORDER BY name LIMIT 1;
  SELECT name, user_id INTO b, ub FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 AND name <> a ORDER BY name LIMIT 1;
  SELECT name, user_id INTO c, uc FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 AND name NOT IN (a, b) ORDER BY name LIMIT 1;
  DELETE FROM public.organisations WHERE data IS JSON OBJECT AND public.sovarka_est_parti_interne(data::jsonb);
  UPDATE public.personnages_donnees SET country='soviet', current_city='capitale', current_building='mairie-capitale',
    current_room='salle_partis', pa=20, hospitalisation=NULL, liquide=greatest(coalesce(liquide,0),1000)
   WHERE name IN (a, b, c);
  SELECT pa INTO pa_a0 FROM public.personnages_donnees WHERE name = a;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_parti_commande(q, 'fonder', NULL, '{"nom":"Parti du Banc","desc":"essai"}');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'fonder: %', r; END IF;
  v_parti := r->>'parti';
  r := public.sovarka_parti_commande(q, 'fonder', NULL, '{"nom":"Parti du Banc","desc":"essai"}');   -- rejeu
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'parti' <> v_parti THEN RAISE EXCEPTION 'rejeu fonder: %', r; END IF;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'fonder', NULL, '{"nom":"Autre"}');
  IF r->>'raison' IS DISTINCT FROM 'deja_dans_un_parti' THEN RAISE EXCEPTION 'double fondation: %', r; END IF;
  r := public.organisation_vie_commande('orgcmd-banc-' || substr(md5(random()::text),1,10), NULL, 'fonder', '{"type":"politique","nom":"Generique"}');
  IF r->>'raison' IS DISTINCT FROM 'parti_sovarka_salle_des_partis' THEN RAISE EXCEPTION 'porte generique: %', r; END IF;
  RESET ROLE;
  SELECT pa INTO pa_a1 FROM public.personnages_donnees WHERE name = a;
  IF pa_a0 - pa_a1 <> 2 THEN RAISE EXCEPTION 'PA fondation % -> %', pa_a0, pa_a1; END IF;

  -- B demande, refus, redemande
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'demander', v_parti, '{}');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'demander: %', r; END IF;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'demander', v_parti, '{}');
  IF r->>'raison' IS DISTINCT FROM 'demande_en_cours' THEN RAISE EXCEPTION 'double demande: %', r; END IF;
  r := public.poste_postuler('juge', 'capitale');
  IF r->>'raison' IS DISTINCT FROM 'parti_requis' THEN RAISE EXCEPTION 'postuler sans parti: %', r; END IF;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'refuser', v_parti, jsonb_build_object('nom', b));
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'pop')::numeric <> 48 THEN RAISE EXCEPTION 'refuser: %', r; END IF;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'fixer_prix', v_parti, '{"prix":30}');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'prix: %', r; END IF;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'demander', v_parti, '{}');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'redemander: %', r; END IF;
  RESET ROLE;
  SELECT liquide INTO liqb0 FROM public.personnages_donnees WHERE name = b;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'accepter', v_parti, jsonb_build_object('nom', b));
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'accepter: %', r; END IF;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'quitter', v_parti, '{}');
  IF r->>'raison' IS DISTINCT FROM 'successeur_requis' THEN RAISE EXCEPTION 'chef quitte: %', r; END IF;
  RESET ROLE;
  SELECT liquide INTO liqb1 FROM public.personnages_donnees WHERE name = b;
  SELECT data::jsonb INTO d FROM public.organisations WHERE id = v_parti;
  IF liqb0 - liqb1 <> 30 OR (d->>'caisse')::numeric <> 30 OR jsonb_array_length(d->'membres') <> 2 THEN
    RAISE EXCEPTION 'paiement adhesion: liquide % -> %, parti %', liqb0, liqb1, d; END IF;

  -- Ministres : A est pm. C (autre parti) refuse tant que B est libre ; permis quand B est ministre.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uc, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'fonder', NULL, '{"nom":"Second Parti"}');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'fonder C: %', r; END IF;
  RESET ROLE;
  DELETE FROM public.postes_attribues WHERE country = 'soviet' AND poste_id IN ('pm','min_int') OR id IN ('soviet_pm_national','soviet_min_int_national');
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('soviet_pm_national', 'soviet', 'pm', NULL, a, 'banc');
  IF public.sovarka_nomination_refus('min_fin', c, NULL) IS DISTINCT FROM 'ministre_hors_parti' THEN
    RAISE EXCEPTION 'ministre hors parti avec membre libre: %', public.sovarka_nomination_refus('min_fin', c, NULL); END IF;
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('soviet_min_int_national', 'soviet', 'min_int', NULL, b, 'banc');
  IF public.sovarka_nomination_refus('min_fin', c, NULL) IS NOT NULL THEN
    RAISE EXCEPTION 'ministre hors parti sans membre libre: %', public.sovarka_nomination_refus('min_fin', c, NULL); END IF;
  UPDATE public.organisations SET data = (data::jsonb || jsonb_build_object('membres', '[]'::jsonb, 'chef', 'Personne'))::text
   WHERE data::jsonb->>'nom' = 'Second Parti';
  IF public.sovarka_nomination_refus('juge', c, NULL) IS DISTINCT FROM 'parti_requis' THEN
    RAISE EXCEPTION 'nomination sans parti: %', public.sovarka_nomination_refus('juge', c, NULL); END IF;

  -- Successeur, depart de A, dissolution par B
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'successeur', v_parti, jsonb_build_object('nom', b));
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'successeur: %', r; END IF;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'quitter', v_parti, '{}');
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'dissous')::boolean THEN RAISE EXCEPTION 'A quitte: %', r; END IF;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_partis_liste();
  IF (r->'mon_parti'->>'est_chef')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'liste B chef: %', r; END IF;
  r := public.sovarka_parti_commande(gen_random_uuid(), 'quitter', v_parti, '{}');
  IF (r->>'dissous')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'dissolution: %', r; END IF;
  RESET ROLE;
  IF EXISTS (SELECT 1 FROM public.organisations WHERE id = v_parti) THEN RAISE EXCEPTION 'parti non dissous'; END IF;
  RAISE EXCEPTION 'BANC_OK A=% B=% C=% : fondation 2 PA, refus -2 POP, adhesion 30 PSK en caisse, parti requis, ministres, successeur, dissolution', a, b, c;
END $$;
