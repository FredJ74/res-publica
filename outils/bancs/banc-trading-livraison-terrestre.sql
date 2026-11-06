-- A jouer APRES le corps de la migration 20261104173000, dans la meme transaction annulee.
-- Achat de trading par Jean Jaaj a l'entrepot de Montrouge, livraison demandee a Luthecia :
-- caisse terrestre vers l'Entrepot Logistique de Luthecia (plus le port de PSM), courrier recu,
-- retrait refuse au port, accepte a la Salle des ventes une fois la caisse arrivee.
-- La connexion (ordinateur + box) est simulee dans la transaction : elle n'est pas l'objet du banc.
DO $$
DECLARE n text := 'Jean Jaaj'; u uuid; r jsonb; c record; org text; nmail integer; inv0 numeric; inv1 numeric; rev bigint; ligne uuid;
BEGIN
  EXECUTE 'CREATE OR REPLACE FUNCTION public.trading_connexion_interne(p_acteur text) RETURNS boolean LANGUAGE sql AS ''SELECT true''';
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;
  SELECT t.id INTO org FROM public.trading_organisations_interne(n) t LIMIT 1;
  UPDATE public.personnages_donnees SET pa = greatest(coalesce(pa,0), 10) WHERE name = n;
  SELECT count(*) INTO nmail FROM public.mails WHERE to_player = n;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/trading_acheter', true);
  SET LOCAL ROLE authenticated;
  r := public.trading_acheter(org, 'republic_ville_b_entrepot-logistique-montrouge', 'bois', 2,
                              'republic_capitale_entrepot-logistique-luthecia');
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'arrivee' <> 'entrepot-logistique-luthecia' OR r->>'ville_livraison' <> 'capitale' THEN
    RAISE EXCEPTION 'achat: %', r; END IF;
  SELECT * INTO c FROM public.caisses_fret WHERE id = (r->>'caisse_fret')::uuid;
  IF c.building_destination <> 'entrepot-logistique-luthecia' OR c.ville_destination <> 'capitale' OR NOT c.dedouanee THEN
    RAISE EXCEPTION 'caisse: % %', c.building_destination, c.ville_destination; END IF;
  IF (SELECT count(*) FROM public.mails WHERE to_player = n) <> nmail + 1 THEN RAISE EXCEPTION 'courrier absent'; END IF;
  -- Sans p_livraison : entrepot de la ville ou se trouve l'acheteur (comportement de l'ancien ecran).
  SET LOCAL ROLE authenticated;
  r := public.trading_acheter(org, 'republic_ville_b_entrepot-logistique-montrouge', 'bois', 1);
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE OR r->>'ville_livraison' IS DISTINCT FROM
     (SELECT current_city FROM public.personnages_donnees WHERE name = n) THEN RAISE EXCEPTION 'defaut: %', r; END IF;
  -- Arrivee simulee (passe de minuit), puis retrait.
  UPDATE public.caisses_fret SET statut = 'arrivee', date_arrivee_reelle = now(), quantite_arrivee = 2 WHERE id = c.id;
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale',
         current_building = 'port-sainte-marie', current_room = 'entrepot' WHERE name = n;
  PERFORM set_config('request.path', '/rpc/fret_objet_agir', true);
  SET LOCAL ROLE authenticated;
  r := public.fret_objet_agir(gen_random_uuid(), c.id, 'retirer',
         (SELECT id FROM public.contenu_caisses_fret WHERE caisse_id = c.id LIMIT 1), NULL, 2, NULL);
  RESET ROLE;
  IF r->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'retrait hors entrepot: %', r; END IF;
  UPDATE public.personnages_donnees SET current_building = 'entrepot-logistique-luthecia', current_room = 'salle_ventes' WHERE name = n;
  SELECT coalesce(sum((x->>'qty')::numeric), 0) INTO inv0 FROM public.personnages_donnees, jsonb_array_elements(inventory) x
   WHERE name = n AND x->>'stackKey' = 'bois';
  SELECT inventory_revision INTO rev FROM public.personnages_donnees WHERE name = n;
  SELECT id INTO ligne FROM public.contenu_caisses_fret WHERE caisse_id = c.id LIMIT 1;
  SET LOCAL ROLE authenticated;
  r := public.fret_objet_agir(gen_random_uuid(), c.id, 'retirer', ligne, NULL, 2, rev);
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'retrait salle des ventes: %', r; END IF;
  SELECT coalesce(sum((x->>'qty')::numeric), 0) INTO inv1 FROM public.personnages_donnees, jsonb_array_elements(inventory) x
   WHERE name = n AND x->>'stackKey' = 'bois';
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (caisse vers Luthecia, courrier, port refuse, retrait OK, bois % -> %)', inv0, inv1;
END $$;
