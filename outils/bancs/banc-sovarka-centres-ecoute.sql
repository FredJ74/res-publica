-- Banc annule des centres d'ecoute (a jouer concatene derriere la migration 20261110092000, sans BEGIN/COMMIT).
DO $banc$
DECLARE u uuid; pas jsonb; r jsonb; r2 jsonb; r3 jsonb; v_pa0 numeric;
BEGIN
  pas := public.sovarka_ecoutes_passe();
  IF (pas->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'passe: %', pas; END IF;
  IF (SELECT count(*) FROM public.sovarka_ecoutes_rapports WHERE jour = public.sovarka_jour_paris() - 1) <> 3 THEN RAISE EXCEPTION 'trois rapports attendus'; END IF;
  IF (public.sovarka_ecoutes_passe()->'interceptes') <> '{}'::jsonb THEN RAISE EXCEPTION 'double compilation'; END IF;
  INSERT INTO public.sovarka_ecoutes_rapports (centre, jour, mails, examines) VALUES ('starovka', public.sovarka_jour_paris() - 3,
    '[{"heure":"10h00","de":"A","a":"B","sujet":"Rendez-vous","texte":"Au port à minuit."}]', 4);
  SELECT user_id INTO u FROM public.personnages WHERE name = 'Arnie';
  UPDATE public.personnages_donnees SET current_city = 'ville_a', current_building = 'mairie', pa = 10 WHERE name = 'Arnie';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r3 := public.sovarka_ecoute_archives_voler('banc-vol-0');
  RESET ROLE;
  IF r3->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'hors centre: %', r3; END IF;
  UPDATE public.personnages_donnees SET current_building = 'poste-vigilance-glaciale', current_room = 'salle_ecoute' WHERE name = 'Arnie';
  SET LOCAL ROLE authenticated;
  r := public.sovarka_ecoute_archives_voler('banc-vol-1');
  r2 := public.sovarka_ecoute_archives_voler('banc-vol-1');
  r3 := public.sovarka_ecoutes_lire();
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE OR r->'reussi' IS NULL THEN RAISE EXCEPTION 'vol: %', r; END IF;
  IF (r2->>'rejeu')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'rejeu: %', r2; END IF;
  IF r3->>'raison' IS DISTINCT FROM 'pas_ministre_defense' AND public.sovarka_titulaire_interne('min_def') IS DISTINCT FROM 'Arnie' THEN RAISE EXCEPTION 'lecture: %', r3; END IF;
  IF (r->>'reussi')::boolean AND NOT EXISTS (SELECT 1 FROM public.mails WHERE to_player = 'Arnie' AND from_player = 'Archives volées') THEN RAISE EXCEPTION 'rapport non recu'; END IF;
  RAISE EXCEPTION 'banc_ok passe=% vol=%', pas->'interceptes', r - 'arrestation';
END $banc$;
