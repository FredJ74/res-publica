-- BANC ANNULE -- fabrication des vehicules au garage (decision de Fred du 06/11/2026). A jouer contre la
-- production (migrations 20261105233000 et 20261105233100 appliquees) : il finit par une exception, rien ne
-- reste. Deux-roues : 5 jours, 95 PA (19 par jour), 150 metal, 100 textile, 150 derives.
DO $$
DECLARE j text := 'Jean Jaaj'; uj uuid; r jsonb; ent text := 'garage-soviet-capitale'; f public.garage_fabrications; liq0 numeric; c0 numeric; d record; i integer;
BEGIN
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = j;
  PERFORM set_config('request.path', '/rpc/banc', true);
  UPDATE public.personnages_donnees SET pa = 30, country = 'soviet', current_city = 'capitale', current_building = 'garage-novomirsk',
         current_room = 'atelier_garage', current_street = NULL WHERE name = j;
  UPDATE public.entreprises SET data = jsonb_set(data, '{stockMatieres}', '{"metal":0,"textile":0,"derives_petrochimiques":100}') WHERE id = ent;
  SELECT liquide INTO liq0 FROM public.personnages_donnees WHERE name = j;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.vehicule_acte(gen_random_uuid(), 'travailler', jsonb_build_object('entreprise', ent, 'pa', 5));
  IF r->>'raison' IS DISTINCT FROM 'aucune_fabrication' THEN RAISE EXCEPTION 'sans fabrication: %', r; END IF;
  r := public.vehicule_acte(gen_random_uuid(), 'fabriquer', jsonb_build_object('entreprise', ent, 'modele', 'deux-roues'));
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'jours')::int <> 5 OR (r->>'besoin_jour')::int <> 19 THEN RAISE EXCEPTION 'lancer: %', r; END IF;
  r := public.vehicule_acte(gen_random_uuid(), 'fabriquer', jsonb_build_object('entreprise', ent, 'modele', 'voiture'));
  IF r->>'raison' IS DISTINCT FROM 'fabrication_en_cours' THEN RAISE EXCEPTION 'une a la fois: %', r; END IF;
  r := public.vehicule_acte(gen_random_uuid(), 'travailler', jsonb_build_object('entreprise', ent, 'pa', 10));
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'salaire')::numeric <> 500 OR (r->>'reste_jour')::int <> 9 THEN RAISE EXCEPTION 'travail: %', r; END IF;
  r := public.vehicule_acte(gen_random_uuid(), 'travailler', jsonb_build_object('entreprise', ent, 'pa', 10));
  IF r->>'raison' IS DISTINCT FROM 'quantite_invalide' THEN RAISE EXCEPTION 'au-dela du besoin: %', r; END IF;
  r := public.vehicules_lire();
  IF (r->'ici'->'fabrication'->>'pa_pj')::int <> 10 OR (r->'ici'->'fabrication'->'matieres_jour'->>'metal')::int <> 30 THEN RAISE EXCEPTION 'lecture: %', r; END IF;
  RESET ROLE;
  SELECT liquide, pa INTO d FROM public.personnages_donnees WHERE name = j;
  IF d.liquide - liq0 <> 500 OR d.pa <> 20 THEN RAISE EXCEPTION 'salaire PJ: %', d; END IF;

  -- Nuit sans matieres : attente, rien ne bouge, le travail du PJ reste acquis.
  r := public.garage_fabrication_avancer_interne((SELECT id FROM public.garage_fabrications WHERE entreprise = ent AND etat <> 'achevee'));
  IF r->>'raison' IS DISTINCT FROM 'attente_matieres' THEN RAISE EXCEPTION 'attente: %', r; END IF;
  SELECT * INTO f FROM public.garage_fabrications WHERE entreprise = ent AND etat <> 'achevee';
  IF f.jours_faits <> 0 OR f.pa_pj <> 10 THEN RAISE EXCEPTION 'apres attente: %', row_to_json(f); END IF;

  -- Matieres livrees : cinq nuits, les PNJ completent (9 PA la premiere, 19 ensuite), puis le vehicule entre en vitrine.
  UPDATE public.entreprises SET data = jsonb_set(data, '{stockMatieres}', '{"metal":150,"textile":100,"derives_petrochimiques":250}') WHERE id = ent;
  SELECT (data->>'caisse')::numeric INTO c0 FROM public.entreprises WHERE id = ent;
  FOR i IN 1..5 LOOP
    UPDATE public.garage_fabrications SET dernier_jour = NULL WHERE id = f.id;
    r := public.garage_fabrication_avancer_interne(f.id);
    IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'jours')::int <> i THEN RAISE EXCEPTION 'nuit %: %', i, r; END IF;
    IF i = 1 AND (r->>'pa_pnj')::int <> 9 THEN RAISE EXCEPTION 'complement PNJ: %', r; END IF;
  END LOOP;
  r := public.garage_fabrication_avancer_interne(f.id);
  IF r->>'ignore' IS NULL THEN RAISE EXCEPTION 'apres achevement: %', r; END IF;
  SELECT data INTO r FROM public.entreprises WHERE id = ent;
  IF (r->'stockProduits'->>'deux-roues')::int <> 4 OR (r->'stockMatieres'->>'metal')::int <> 0 OR (r->'stockMatieres'->>'derives_petrochimiques')::int <> 100
     OR c0 - (r->>'caisse')::numeric <> 85 * 50 THEN
    RAISE EXCEPTION 'vitrine / matieres / caisse: % (caisse -%)', r->'stockProduits', c0 - (r->>'caisse')::numeric; END IF;
  RAISE EXCEPTION 'BANC FABRICATION VERT';
END $$;
