-- BANC ANNULE -- serrure d'un batiment entier (issue #434, decisions de Fred du 04/11 14 h 27).
-- A jouer APRES 20261104133000 et 20261104133100, dans la meme transaction annulee.
-- Un batiment construit est simule sur le terrain 5 de Luthecia (Jean Jaaj proprietaire) ; rien ne reste.
DO $$
DECLARE j text := 'Jean Jaaj'; a text := 'Angie Porcelana'; uj uuid; ua uuid; r jsonb; sid uuid; bat text := 'terrain-a-batir-5';
BEGIN
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = j;
  SELECT user_id INTO ua FROM public.personnages_donnees WHERE name = a;
  PERFORM set_config('request.path', '/rpc/banc', true);
  UPDATE public.terrains_etat SET proprietaire = j, niveau_construction = 'building' WHERE country = 'republic' AND building_id = bat;
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale', current_building = bat, current_room = 'terrain' WHERE name = j;
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale', current_building = NULL, current_room = NULL WHERE name = a;
  IF NOT public.batiment_jouissance_integrale_interne(j, 'republic', 'capitale', bat) THEN RAISE EXCEPTION 'Jaaj devrait avoir l''integralite'; END IF;
  IF public.batiment_jouissance_integrale_interne(a, 'republic', 'capitale', bat) THEN RAISE EXCEPTION 'Angie ne l''a pas'; END IF;
  INSERT INTO public.serrures (statut, achetee_par) VALUES ('neuve', j) RETURNING id INTO sid;
  PERFORM public.inventaire_deposer_interne(j, public.serrure_objet_interne(sid));
  PERFORM public.inventaire_deposer_interne(j, public.serrure_cle_objet_interne(sid, 1));
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.equipements_local_lire();
  IF (r->'serrures'->>'batiment_posable')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'batiment posable: %', r->'serrures'; END IF;
  r := public.serrure_poser(gen_random_uuid(), sid, 'batiment', NULL);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'pose batiment: %', r; END IF;
  r := public.serrures_portes_lire(bat);
  IF (r->'entree'->>'fermee')::boolean IS NOT FALSE THEN RAISE EXCEPTION 'entree ouverte attendue: %', r; END IF;
  r := public.serrure_basculer(sid, true);
  IF (r->>'fermee')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'fermer batiment: %', r; END IF;
  r := public.serrure_etat(sid);
  IF r->>'cible' <> 'batiment' OR (r->>'a_portee')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'etat: %', r; END IF;
  RESET ROLE;
  -- Angie, dans la rue : porte fermee ; l'infobulle de la rue le sait.
  r := public.navigation_interieure_personnage_interne(a, bat, 'terrain', true);
  IF r->>'raison' IS DISTINCT FROM 'porte_fermee_a_cle' THEN RAISE EXCEPTION 'Angie dans la rue: %', r; END IF;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.serrures_batiments_lire();
  IF (r->'batiments'->bat->>'fermee')::boolean IS NOT TRUE OR (r->'batiments'->bat->>'a_cle')::boolean IS NOT FALSE THEN
    RAISE EXCEPTION 'lecture rue: %', r; END IF;
  RESET ROLE;
  -- Avec une cle, la serrure ne l'arrete plus.
  PERFORM public.inventaire_deposer_interne(a, public.serrure_cle_objet_interne(sid, 1));
  r := public.navigation_interieure_personnage_interne(a, bat, 'terrain', true);
  IF r->>'raison' = 'porte_fermee_a_cle' THEN RAISE EXCEPTION 'Angie avec cle: %', r; END IF;
  -- Le batiment est vendu : l'integralite est perdue, la serrure est detruite.
  -- (La regle des lots loues a un tiers est eprouvee par le second bloc ci-dessous.)
  UPDATE public.terrains_etat SET proprietaire = 'Quelqu''un' WHERE country = 'republic' AND building_id = bat;
  PERFORM public.serrure_batiment_ferme_interne(a, 'republic', 'capitale', bat);
  IF (SELECT statut FROM public.serrures WHERE id = sid) <> 'detruite' THEN
    RAISE EXCEPTION 'serrure du batiment non detruite apres la vente'; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (serrure de batiment %)', public.serrure_numero_interne(sid);
END $$;

-- Second bloc, meme transaction annulee : un lot loue a un tiers retire l'integralite (joue le 04/11 : avant t, apres f).
DO $$ DECLARE r1 boolean; r2 boolean; BEGIN
  UPDATE public.terrains_etat SET proprietaire = 'Jean Jaaj', niveau_construction = 'building' WHERE country = 'republic' AND building_id = 'terrain-a-batir-5';
  r1 := public.batiment_jouissance_integrale_interne('Jean Jaaj','republic','capitale','terrain-a-batir-5');
  UPDATE public.terrains_etat SET data = (data::jsonb || '{"subdivisions":[{"id":"lot1","locataire":"Quelqu''un"}]}'::jsonb)::text
   WHERE country = 'republic' AND building_id = 'terrain-a-batir-5';
  r2 := public.batiment_jouissance_integrale_interne('Jean Jaaj','republic','capitale','terrain-a-batir-5');
  IF r1 IS NOT TRUE OR r2 IS NOT FALSE THEN RAISE EXCEPTION 'regle des lots: % %', r1, r2; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (lot loue : integralite perdue)';
END $$;
