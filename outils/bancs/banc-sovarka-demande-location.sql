-- BANC ANNULE -- demande de location depuis le local (migration 20261106230000, GAME-DESIGN-NOVOMIRSK.md).
-- A jouer APRES la migration (ou concatene derriere elle), dans une transaction qui finit par une
-- exception : rien ne reste. Acteurs : Jean Jaaj (demandeur), Angie Porcelana (seconde demandeuse),
-- Arnie (ministre de l'Economie collective simule, accepte).
DO $$
DECLARE a text := 'Arnie'; j text := 'Jean Jaaj'; g text := 'Angie Porcelana'; ua uuid; uj uuid; ug uuid;
  r jsonb; d1 text; pa0 integer; pa1 integer; dem jsonb;
BEGIN
  SELECT user_id INTO ua FROM public.personnages_donnees WHERE name = a;
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = j;
  SELECT user_id INTO ug FROM public.personnages_donnees WHERE name = g;
  PERFORM set_config('request.path', '/rpc/banc', true);
  UPDATE public.personnages_donnees SET country='soviet', current_city='capitale', current_street=NULL, pa=20,
         hp=greatest(coalesce(hp,0),50), current_building='centre-commercial', current_room='hall' WHERE name IN (a, j, g);
  DELETE FROM public.sovarka_demandes WHERE demandeur IN (j, g) AND statut IN ('en_attente','acceptee','attribuee');
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, depuis, source, updated_at)
  VALUES ('soviet_min_fin_national', 'soviet', 'min_fin', NULL, a, now(), 'banc', now()) ON CONFLICT (id) DO UPDATE SET titulaire = a;

  -- 1. Depuis le hall : refus nommé, rien de payé.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_demande_location('centre-commercial', 'vitrine_principale', NULL);
  IF r->>'raison' IS DISTINCT FROM 'pas_dans_le_local' THEN RAISE EXCEPTION 'hors du local: %', r; END IF;
  RESET ROLE;

  -- 2. Dans le Grand local A : lettre envoyée, 1 PA, projet par défaut, local souhaité noté.
  UPDATE public.personnages_donnees SET current_room='vitrine_principale' WHERE name = j;
  SELECT pa INTO pa0 FROM public.personnages_donnees WHERE name = j;
  SET LOCAL ROLE authenticated;
  r := public.sovarka_demande_location('centre-commercial', 'vitrine_principale', '');
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'local' IS DISTINCT FROM 'Grand local A' THEN RAISE EXCEPTION 'envoi: %', r; END IF;
  d1 := r->>'demandeId';
  r := public.sovarka_demande_location('centre-commercial', 'vitrine_principale', NULL);
  IF r->>'raison' IS DISTINCT FROM 'demande_deja_en_cours' THEN RAISE EXCEPTION 'double demande: %', r; END IF;
  RESET ROLE;
  SELECT pa INTO pa1 FROM public.personnages_donnees WHERE name = j;
  IF pa1 <> pa0 - 1 THEN RAISE EXCEPTION 'PA: % -> %', pa0, pa1; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sovarka_demandes WHERE id = d1 AND demandeur = j AND statut = 'en_attente'
                  AND projet = 'Location du local : Grand local A' AND local_souhaite_piece = 'vitrine_principale') THEN
    RAISE EXCEPTION 'dossier mal enregistré'; END IF;

  -- 3. Angie demande le même local avec une activité : accepté (le maire choisira).
  UPDATE public.personnages_donnees SET current_room='vitrine_principale' WHERE name = g;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ug, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_demande_location('centre-commercial', 'vitrine_principale', 'Une librairie');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'seconde demande: %', r; END IF;
  RESET ROLE;

  -- 4. Arnie voit les deux dossiers avec nom et local souhaité, et attribue le local à Jean.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  dem := public.sovarka_droits_lire()->'demandes';
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(dem) e WHERE e->>'demandeur' = j AND e->>'local_souhaite_piece' = 'vitrine_principale')
     OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(dem) e WHERE e->>'demandeur' = g AND e->>'projet' = 'Une librairie') THEN
    RAISE EXCEPTION 'liste du maire: %', dem; END IF;
  r := public.sovarka_demande_accepter(d1, 'centre-commercial', 'vitrine_principale');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'acceptation: %', r; END IF;
  RESET ROLE;

  -- 5. Le local est réservé : une nouvelle lettre y est refusée.
  DELETE FROM public.sovarka_demandes WHERE demandeur = g AND statut = 'en_attente';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ug, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_demande_location('centre-commercial', 'vitrine_principale', NULL);
  IF r->>'raison' IS DISTINCT FROM 'local_non_libre' THEN RAISE EXCEPTION 'local réservé: %', r; END IF;
  RESET ROLE;

  RAISE NOTICE 'banc demande de location : OK';
END $$;
