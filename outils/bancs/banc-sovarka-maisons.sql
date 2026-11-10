-- Banc annule des maisons de Starovka et Krasnov (a jouer concatene derriere la migration 20261110094500, sans BEGIN/COMMIT).
DO $banc$
DECLARE u uuid; lu jsonb; s jsonb; r1 jsonb; r2 jsonb; r3 jsonb; r4 jsonb; r5 jsonb; r6 jsonb; b0 integer; b1 integer; pa0 integer; n int;
BEGIN
  SELECT user_id INTO u FROM public.personnages WHERE name = 'Arnie';
  UPDATE public.personnages_donnees SET current_city = 'ville_a', current_building = 'maison-starovka', current_room = 'piece_maison', pa = 20,
    inventory = coalesce(inventory, '[]'::jsonb) || '[{"name":"Bois","stackable":true,"stackKey":"bois","qty":5},{"name":"Poisson","stackable":true,"stackKey":"poisson","qty":3},{"name":"Carburant","stackable":true,"stackKey":"carburant","qty":2}]'::jsonb
   WHERE name = 'Arnie';
  SELECT bonus_pa_differe, pa INTO b0, pa0 FROM public.personnages_donnees WHERE name = 'Arnie';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/sovarka_maison_agir', true);
  SET LOCAL ROLE authenticated;
  lu := public.sovarka_maison_lire();
  r1 := public.sovarka_maison_agir('banc-m-1', 'manger');
  r2 := public.sovarka_maison_agir('banc-m-2', 'service');
  r3 := public.sovarka_maison_agir('banc-m-2', 'service');
  r4 := public.sovarka_maison_agir('banc-m-3', 'manger');
  r5 := public.sovarka_maison_agir('banc-m-4', 'trinquer');
  RESET ROLE;
  IF (lu->>'ok')::boolean IS NOT TRUE OR lu->'service' IS NULL THEN RAISE EXCEPTION 'lecture: %', lu; END IF;
  IF lu->'service'->>'cle' NOT IN ('bois', 'poisson', 'carburant') THEN RAISE EXCEPTION 'service inexistant tire: %', lu->'service'; END IF;
  IF r1->>'raison' IS DISTINCT FROM 'service_non_rendu' THEN RAISE EXCEPTION 'manger avant service: %', r1; END IF;
  IF (r2->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'service: %', r2; END IF;
  IF (r3->>'rejeu')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'rejeu: %', r3; END IF;
  IF (r4->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'manger: %', r4; END IF;
  SELECT bonus_pa_differe INTO b1 FROM public.personnages_donnees WHERE name = 'Arnie';
  IF b1 - coalesce(b0, 0) <> 2 THEN RAISE EXCEPTION 'repas: % -> %', b0, b1; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.hotel_nuitees n JOIN public.personnages_donnees d ON d.id = n.personnage_id
                  WHERE d.name = 'Arnie' AND n.building_id = 'maison-starovka' AND n.consommee_le IS NULL) THEN RAISE EXCEPTION 'nuitee absente'; END IF;
  IF (r5->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'trinquer: %', r5; END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE name = 'Arnie') <> pa0 - 3 THEN RAISE EXCEPTION 'pa trinquer'; END IF;
  SELECT count(*) INTO n FROM public.sovarka_maisons_ragots WHERE maison = 'maison-starovka' AND sujet = 'Arnie';
  IF n <> 1 THEN RAISE EXCEPTION 'ragot non retenu'; END IF;
  -- Krasnov, le meme jour : une seule hospitalite par jour
  UPDATE public.personnages_donnees SET current_city = 'ville_b', current_building = 'maison-krasnov' WHERE name = 'Arnie';
  SET LOCAL ROLE authenticated;
  r6 := public.sovarka_maison_agir('banc-m-5', 'service');
  RESET ROLE;
  IF r6->>'raison' IS DISTINCT FROM 'heberge_ailleurs' THEN RAISE EXCEPTION 'deux hospitalites: %', r6; END IF;
  RAISE EXCEPTION 'banc_ok service=% reaction=% livre=% recu=%', lu->'service'->>'label', r5->>'reaction', r5->>'secret_livre', r5->>'secret_recu';
END $banc$;
