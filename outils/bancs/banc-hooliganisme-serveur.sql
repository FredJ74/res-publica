-- Banc annulé de 20261103103615_hooliganisme_serveur : à jouer APRÈS la migration, dans la même
-- transaction ; l'exception finale annule tout. Personnage d'essai : Angie Porcelana, dans une
-- organisation de supporters créée pour le banc (aucune n'existe en bêta).
DO $$
DECLARE u uuid; n text := 'Angie Porcelana'; r jsonb; pa0 int; pa1 int; isn0 int; soc0 int; isn1 int; soc1 int;
  nb0 int; nb1 int; t jsonb;
BEGIN
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;
  UPDATE public.personnages_donnees SET pa = 20, country = 'republic', current_city = 'ville_a',
         historique_crimes = '[]'::jsonb WHERE name = n;
  INSERT INTO public.organisations (id, country_origine, data) VALUES ('banc_supporters', 'republic', jsonb_build_object(
    'id', 'banc_supporters', 'type', 'supporters', 'nom', 'Banc', 'chef', n,
    'membres', jsonb_build_array(jsonb_build_object('nom', n, 'grade', 'Ultra', 'gradeIdx', 2))));
  INSERT INTO public.organisations (id, country_origine, data) VALUES ('banc_eco', 'republic', jsonb_build_object(
    'id', 'banc_eco', 'type', 'economique', 'nom', 'Banc', 'chef', n,
    'membres', jsonb_build_array(jsonb_build_object('nom', n, 'grade', 'Chef', 'gradeIdx', 3))));
  SELECT (data->>'isn')::int, (data->>'social')::int INTO isn0, soc0 FROM public.indices_villes WHERE id = 'republic_ville_a';

  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  -- 1. Grade insuffisant (Ultra), mauvais type, organisation inconnue : refus avant paiement.
  r := public.organisation_hooliganisme('banc_supporters');
  IF r->>'raison' IS DISTINCT FROM 'grade_insuffisant' THEN RAISE EXCEPTION 'banc 1a: %', r; END IF;
  r := public.organisation_hooliganisme('banc_eco');
  IF r->>'raison' IS DISTINCT FROM 'ordre_hors_type' THEN RAISE EXCEPTION 'banc 1b: %', r; END IF;
  r := public.organisation_hooliganisme('inconnue');
  IF r->>'raison' IS DISTINCT FROM 'organisation_introuvable' THEN RAISE EXCEPTION 'banc 1c: %', r; END IF;
  RESET ROLE;
  SELECT pa INTO pa0 FROM public.personnages_donnees WHERE name = n;
  IF pa0 <> 20 THEN RAISE EXCEPTION 'banc 1d: PA prélevés sur un refus (%)', pa0; END IF;

  -- 2. Meneur : payé 3 PA, −5 Sécurité et −5 Social à Montrouge, trace serveur posée.
  UPDATE public.organisations SET data = jsonb_set(data::jsonb, '{membres,0,gradeIdx}', '3') WHERE id = 'banc_supporters';
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  r := public.organisation_hooliganisme('banc_supporters');
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'banc 2a: %', r; END IF;
  SELECT pa, jsonb_array_length(historique_crimes) INTO pa1, nb1 FROM public.personnages_donnees WHERE name = n;
  IF pa1 <> 17 THEN RAISE EXCEPTION 'banc 2b: PA % au lieu de 17', pa1; END IF;
  SELECT (data->>'isn')::int, (data->>'social')::int INTO isn1, soc1 FROM public.indices_villes WHERE id = 'republic_ville_a';
  IF isn1 <> greatest(0, isn0 - 5) OR soc1 <> greatest(0, soc0 - 5) THEN
    RAISE EXCEPTION 'banc 2c: isn % -> %, social % -> %', isn0, isn1, soc0, soc1;
  END IF;
  IF (r->'indices'->>'isn')::int <> isn1 THEN RAISE EXCEPTION 'banc 2d: indices rendus %', r->'indices'; END IF;
  SELECT historique_crimes->0 INTO t FROM public.personnages_donnees WHERE name = n;
  IF nb1 <> 1 OR t->>'acte' <> 'hooliganisme' OR t->>'origine' <> 'serveur' OR t->>'expireTs' IS NULL THEN
    RAISE EXCEPTION 'banc 2e: trace %', t;
  END IF;

  -- 3. PA épuisés : refus nommé, rien d'autre ne bouge.
  UPDATE public.personnages_donnees SET pa = 1 WHERE name = n;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  r := public.organisation_hooliganisme('banc_supporters');
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT FALSE THEN RAISE EXCEPTION 'banc 3a: %', r; END IF;
  SELECT jsonb_array_length(historique_crimes) INTO nb1 FROM public.personnages_donnees WHERE name = n;
  IF nb1 <> 1 THEN RAISE EXCEPTION 'banc 3b: trace posée sans paiement'; END IF;

  -- 4. La découverte de minuit voit cette trace (acte découvrable, origine serveur).
  IF NOT EXISTS (SELECT 1 FROM public.actes_illegaux WHERE fn = 'hooliganisme' AND decouvrable) THEN
    RAISE EXCEPTION 'banc 4: hooliganisme non découvrable';
  END IF;

  RAISE EXCEPTION 'BANC OK : refus 1a-1d, Meneur −3 PA, isn % -> %, social % -> %, trace serveur, refus sans PA', isn0, isn1, soc0, soc1;
END $$;
