-- A jouer APRES le corps de la migration 20261107001000, dans la meme transaction annulee.
-- BANC (annule) : un PJ reel achete 1 unite a l'entrepot de Luthecia ; la recette doit
-- entrer dans caisses_batiments, aucune cle 'caisse' ne doit reapparaitre dans le blob.
DO $$
DECLARE n text; u uuid; r jsonb; q uuid := gen_random_uuid(); bid text; cle text;
  c0 numeric; c1 numeric; liq0 numeric; liq1 numeric; nat0 numeric; nat1 numeric; blob_caisse boolean;
BEGIN
  SELECT building_id INTO bid FROM public.batiments_etat
   WHERE id LIKE 'republic\_capitale\_entrepot-logistique-%' LIMIT 1;
  SELECT s.key INTO cle FROM public.batiments_etat b,
         jsonb_each_text(public.batiment_etat_lire(b.data)->'entrepot'->'stock') s
   WHERE b.id = 'republic_capitale_' || bid AND s.value::numeric >= 5
     AND EXISTS (SELECT 1 FROM public.ressources_economie r WHERE r.cle = s.key)
   LIMIT 1;
  IF cle IS NULL THEN RAISE EXCEPTION 'aucune ressource en stock a Luthecia'; END IF;
  SELECT name, user_id INTO n, u FROM public.personnages_donnees
   WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale',
    current_building=bid, pa = greatest(coalesce(pa,0),10), hospitalisation=NULL,
    liquide = greatest(coalesce(liquide,0), 5000) WHERE name = n;
  SELECT (data->>'solde')::numeric INTO c0 FROM public.caisses_batiments WHERE id='republic_entrepot_capitale';
  SELECT liquide INTO liq0 FROM public.personnages_donnees WHERE name = n;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/acheter_a_entrepot', true);
  SET LOCAL ROLE authenticated;
  r := public.acheter_a_entrepot(q, n, 'republic', 'capitale', bid, jsonb_build_object(cle, 1), 0, 0);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'achat refuse: %', r - 'inventory'; END IF;
  r := public.acheter_a_entrepot(q, n, 'republic', 'capitale', bid, jsonb_build_object(cle, 1), 0, 0); -- rejeu
  RESET ROLE;
  SELECT (data->>'solde')::numeric INTO c1 FROM public.caisses_batiments WHERE id='republic_entrepot_capitale';
  SELECT liquide INTO liq1 FROM public.personnages_donnees WHERE name = n;
  SELECT (public.batiment_etat_lire(data)->'entrepot') ? 'caisse' INTO blob_caisse
    FROM public.batiments_etat WHERE id = 'republic_capitale_' || bid;
  IF c1 - c0 <> (r->>'paye')::numeric OR liq0 - liq1 <> (r->>'paye')::numeric
     OR blob_caisse OR (r->>'caisse_entrepot')::numeric <> c1 THEN
    RAISE EXCEPTION 'ECHEC caisse % -> %, liquide % -> %, paye %, blob %, rendu %',
      c0, c1, liq0, liq1, r->>'paye', blob_caisse, r->>'caisse_entrepot';
  END IF;
  RAISE EXCEPTION 'BANC_OK % achete 1 %, paye %, caisse % -> %, rejeu sans double effet', n, cle, r->>'paye', c0, c1;
END $$;
