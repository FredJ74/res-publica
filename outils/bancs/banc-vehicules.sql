-- BANC ANNULE -- vehicules personnels (GAME-DESIGN-VEHICULES.md). A jouer APRES les six
-- migrations 20261105222000 .. 20261105222300 (ou contre la production ou elles sont appliquees), dans une transaction, qui finit par une exception :
-- rien ne reste. Parcours complet de Jean Jaaj en Sovarka, comme le navigateur : achat d'une voiture au
-- garage de Novomirsk, rejeu, reservoir vide, plein en bidons, route absente vers Starovka, trajet vers
-- Krasnov, bidons a la station, chargement / dechargement, revision exigee, panne, depannage, revision.
DO $$
DECLARE j text := 'Jean Jaaj'; uj uuid; r jsonb; r2 jsonb; q uuid := gen_random_uuid(); vid uuid; arg0 numeric; arg1 numeric;
  pa0 integer; d record; pos integer; essais integer := 0; stock0 numeric;
BEGIN
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = j;
  PERFORM set_config('request.path', '/rpc/banc', true);
  UPDATE public.personnages_donnees SET pa = 30, country = 'soviet', current_city = 'capitale', current_building = 'garage-novomirsk',
         current_room = 'atelier_garage', current_street = NULL WHERE name = j;
  DELETE FROM public.groupes_pj_adhesions WHERE chef = j OR membre = j;
  SELECT arg INTO arg0 FROM public.personnages_donnees WHERE name = j;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;

  -- 1. Achat d'une voiture (42 000), rejeu sans second paiement, modele inconnu.
  r := public.vehicule_acte(q, 'acheter', '{"entreprise":"garage-soviet-capitale","modele":"voiture"}');
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'total')::numeric <> 42000 THEN RAISE EXCEPTION 'achat: %', r; END IF;
  vid := (r->>'vehicule')::uuid;
  r2 := public.vehicule_acte(q, 'acheter', '{"entreprise":"garage-soviet-capitale","modele":"voiture"}');
  IF r2->>'vehicule' IS DISTINCT FROM vid::text THEN RAISE EXCEPTION 'rejeu: %', r2; END IF;
  r2 := public.vehicule_acte(gen_random_uuid(), 'acheter', '{"entreprise":"garage-soviet-capitale","modele":"char"}');
  IF r2->>'raison' IS DISTINCT FROM 'produit_non_propose' THEN RAISE EXCEPTION 'modele: %', r2; END IF;
  RESET ROLE;
  SELECT arg INTO arg1 FROM public.personnages_donnees WHERE name = j;
  IF arg0 - arg1 <> 42000 THEN RAISE EXCEPTION 'debit % (attendu 42000)', arg0 - arg1; END IF;
  IF (SELECT (data->'stockProduits'->>'voiture')::int FROM public.entreprises WHERE id = 'garage-soviet-capitale') <> 2 THEN
    RAISE EXCEPTION 'stock garage'; END IF;
  IF NOT public.serrure_cle_detenue_interne(j, (SELECT serrure FROM public.vehicules WHERE id = vid)) THEN RAISE EXCEPTION 'cle absente'; END IF;

  -- 2. Reservoir vide ; bidons ; plein de 18, pas un de plus.
  SET LOCAL ROLE authenticated;
  r := public.vehicule_acte(gen_random_uuid(), 'trajet', jsonb_build_object('vehicule', vid, 'ville', 'ville_b'));
  IF r->>'raison' IS DISTINCT FROM 'carburant_insuffisant' THEN RAISE EXCEPTION 'vide: %', r; END IF;
  RESET ROLE;
  PERFORM public.inventaire_deposer_interne(j, '{"name":"carburant","stackKey":"carburant","stackable":true,"qty":20}'::jsonb);
  SET LOCAL ROLE authenticated;
  r := public.vehicule_acte(gen_random_uuid(), 'plein', jsonb_build_object('vehicule', vid, 'qte', 18));
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'carburant')::int <> 18 OR jsonb_typeof(r->'inventory') <> 'array' THEN RAISE EXCEPTION 'plein: %', r; END IF;
  r := public.vehicule_acte(gen_random_uuid(), 'plein', jsonb_build_object('vehicule', vid, 'qte', 1));
  IF r->>'raison' IS DISTINCT FROM 'reservoir_plein' THEN RAISE EXCEPTION 'trop plein: %', r; END IF;

  -- 3. Pas de route vers Starovka ; trajet vers Krasnov (10 unites, 1 PA), arrivee a la gare.
  r := public.vehicule_acte(gen_random_uuid(), 'trajet', jsonb_build_object('vehicule', vid, 'ville', 'ville_a'));
  IF r->>'raison' IS DISTINCT FROM 'pas_de_route' THEN RAISE EXCEPTION 'route: %', r; END IF;
  r := public.vehicule_acte(gen_random_uuid(), 'trajet', jsonb_build_object('vehicule', vid, 'ville', 'ville_b'));
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'panne')::boolean OR (r->>'carburant')::int <> 8 THEN RAISE EXCEPTION 'trajet: %', r; END IF;
  RESET ROLE;
  SELECT current_city, current_building, pa INTO d FROM public.personnages_donnees WHERE name = j;
  IF d.current_city <> 'ville_b' OR d.current_building NOT LIKE 'centre-multinodal-%' OR d.pa <> 29 THEN RAISE EXCEPTION 'arrivee: %', d; END IF;

  -- 4. Station de Krasnov : 10 bidons a 20 ; chargement de 5, dechargement de 2.
  UPDATE public.personnages_donnees SET current_building = 'station-service-krasnov', current_room = 'boutique_station' WHERE name = j;
  SET LOCAL ROLE authenticated;
  r := public.vehicule_acte(gen_random_uuid(), 'carburant', '{"entreprise":"station-soviet-ville_b","qte":10}');
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'total')::numeric <> 200 THEN RAISE EXCEPTION 'bidons: %', r; END IF;
  RESET ROLE;
  SELECT (o.ord - 1)::int INTO pos FROM public.personnages_donnees p, jsonb_array_elements(p.inventory) WITH ORDINALITY o(val, ord)
   WHERE p.name = j AND o.val->>'stackKey' = 'carburant';
  SET LOCAL ROLE authenticated;
  r := public.vehicule_acte(gen_random_uuid(), 'charger', jsonb_build_object('vehicule', vid, 'index', pos, 'qte', 5,
         'signature', '{"name":"carburant","stackKey":"carburant"}'::jsonb));
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->'cargaison'->0->>'qty')::int <> 5 THEN RAISE EXCEPTION 'charger: %', r; END IF;
  r := public.vehicule_acte(gen_random_uuid(), 'decharger', jsonb_build_object('vehicule', vid, 'position', 0, 'qte', 2));
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->'cargaison'->0->>'qty')::int <> 3 THEN RAISE EXCEPTION 'decharger: %', r; END IF;

  -- 5. Au 15e trajet le vehicule ne demarre plus.
  RESET ROLE;
  UPDATE public.vehicules SET trajets_depuis_revision = 14, carburant = 18 WHERE id = vid;
  SET LOCAL ROLE authenticated;
  r := public.vehicule_acte(gen_random_uuid(), 'trajet', jsonb_build_object('vehicule', vid, 'ville', 'capitale'));
  IF r->>'raison' IS DISTINCT FROM 'revision_requise' THEN RAISE EXCEPTION 'revision exigee: %', r; END IF;

  -- 6. Panne (14e trajet : 90 %), garages proposes, depannage a 450 vers Novomirsk.
  LOOP
    RESET ROLE;
    UPDATE public.vehicules SET trajets_depuis_revision = 13, carburant = 18, ville = 'ville_b', statut = 'pret', panne = NULL WHERE id = vid;
    UPDATE public.personnages_donnees SET current_city = 'ville_b', current_building = 'station-service-krasnov', current_room = 'boutique_station', pa = 30 WHERE name = j;
    SET LOCAL ROLE authenticated;
    r := public.vehicule_acte(gen_random_uuid(), 'trajet', jsonb_build_object('vehicule', vid, 'ville', 'capitale'));
    IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'trajet panne: %', r; END IF;
    EXIT WHEN (r->>'panne')::boolean;
    essais := essais + 1;
    IF essais > 20 THEN RAISE EXCEPTION 'aucune panne en 20 essais a 90 %%'; END IF;
  END LOOP;
  IF r->'garages'->0->>'id' IS DISTINCT FROM 'garage-soviet-capitale' OR (r->'garages'->0->>'prix')::int <> 450 THEN RAISE EXCEPTION 'garages: %', r; END IF;
  r := public.vehicule_acte(gen_random_uuid(), 'trajet', jsonb_build_object('vehicule', vid, 'ville', 'capitale'));
  IF r->>'raison' IS DISTINCT FROM 'vehicule_en_panne' THEN RAISE EXCEPTION 'repartir en panne: %', r; END IF;
  r := public.vehicule_acte(gen_random_uuid(), 'depanner', jsonb_build_object('vehicule', vid, 'garage', 'station-soviet-ville_b'));
  IF r->>'raison' IS DISTINCT FROM 'garage_non_propose' THEN RAISE EXCEPTION 'faux garage: %', r; END IF;
  RESET ROLE;
  SELECT arg INTO arg0 FROM public.personnages_donnees WHERE name = j;
  SET LOCAL ROLE authenticated;
  r := public.vehicule_acte(gen_random_uuid(), 'depanner', jsonb_build_object('vehicule', vid, 'garage', 'garage-soviet-capitale'));
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'building' IS DISTINCT FROM 'garage-novomirsk' THEN RAISE EXCEPTION 'depannage: %', r; END IF;
  RESET ROLE;
  SELECT arg, current_city, current_building INTO d FROM public.personnages_donnees WHERE name = j;
  IF arg0 - d.arg <> 450 OR d.current_city <> 'capitale' OR d.current_building <> 'garage-novomirsk' THEN RAISE EXCEPTION 'apres depannage: %', d; END IF;

  -- 7. La revision reste due ; revision 500 au garage PNJ, 10 derives sortis du stock.
  SELECT (data->'stockMatieres'->>'derives_petrochimiques')::numeric INTO stock0 FROM public.entreprises WHERE id = 'garage-soviet-capitale';
  SET LOCAL ROLE authenticated;
  r := public.vehicule_acte(gen_random_uuid(), 'trajet', jsonb_build_object('vehicule', vid, 'ville', 'ville_b'));
  IF r->>'raison' IS DISTINCT FROM 'revision_requise' THEN RAISE EXCEPTION 'apres depannage, revision: %', r; END IF;
  r := public.vehicule_acte(gen_random_uuid(), 'reviser', jsonb_build_object('vehicule', vid, 'entreprise', 'garage-soviet-capitale'));
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'prix')::int <> 500 THEN RAISE EXCEPTION 'revision: %', r; END IF;
  r := public.vehicules_lire();
  IF (r->'vehicules'->0->>'trajets')::int <> 0 OR r->'ici'->>'type' IS DISTINCT FROM 'garage' THEN RAISE EXCEPTION 'lecture: %', r; END IF;
  RESET ROLE;
  IF (SELECT (data->'stockMatieres'->>'derives_petrochimiques')::numeric FROM public.entreprises WHERE id = 'garage-soviet-capitale') <> stock0 - 10 THEN
    RAISE EXCEPTION 'pieces du garage'; END IF;

  -- 8. Un tiers sans cle ne voit ni ne conduit le vehicule.
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'capitale', current_building = 'garage-novomirsk' WHERE name = 'Angie Porcelana';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', (SELECT user_id FROM public.personnages_donnees WHERE name = 'Angie Porcelana'), 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.vehicule_acte(gen_random_uuid(), 'trajet', jsonb_build_object('vehicule', vid, 'ville', 'ville_b'));
  IF r->>'raison' IS DISTINCT FROM 'vehicule_hors_de_portee' THEN RAISE EXCEPTION 'tiers: %', r; END IF;
  IF jsonb_array_length(public.vehicules_lire()->'vehicules') <> 0 THEN RAISE EXCEPTION 'tiers voit le vehicule'; END IF;
  RESET ROLE;
  RAISE EXCEPTION 'BANC VEHICULES VERT (% essai(s) avant la panne)', essais + 1;
END $$;
