-- A jouer APRES le corps de la migration 20261104105114, dans la meme transaction annulee.
-- Parcours complet d'une caisse : reservation, chargeur, fermeture avec un lot non declare,
-- inspection (saisie de l'arme, amende de 2 x 10 % x valeur de reference), expedition ;
-- refus d'un non-Chef au controle cible ; ecriture directe de l'ecran refusee.
DO $$
DECLARE n text := 'Jean Jaaj'; d text := 'Angie Porcelana'; u uuid; r jsonb; c uuid; l_med uuid;
  pa0 integer; pa1 integer; v_conv integer; v_conv1 integer; e text;
BEGIN
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;
  UPDATE public.personnages_donnees SET pa = greatest(coalesce(pa, 0), 10), liquide = greatest(coalesce(liquide, 0), 1000),
    country = 'republic', current_city = 'ville_a', current_building = 'port-sainte-marie', current_room = 'entrepot',
    current_street = NULL WHERE name = n;
  SELECT pa, jsonb_array_length(coalesce(convocations, '[]'::jsonb)) INTO pa0, v_conv FROM public.personnages_donnees WHERE name = n;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/fret_caisse_commande', true);
  SET LOCAL ROLE authenticated;

  r := public.fret_caisse_commande('reserver', NULL, '{}', gen_random_uuid());
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'reserver: %', r; END IF;
  c := (r->>'caisse')::uuid;
  r := public.fret_caisse_commande('chargeur_ajouter', c, jsonb_build_object('nom', d), gen_random_uuid());
  IF NOT (r->'chargeurs') ? d THEN RAISE EXCEPTION 'chargeur: %', r; END IF;
  r := public.fret_caisse_commande('chargeur_retirer', c, jsonb_build_object('nom', d), gen_random_uuid());
  IF (r->'chargeurs') ? d THEN RAISE EXCEPTION 'chargeur retire: %', r; END IF;
  r := public.fret_caisse_commande('fermer', c, jsonb_build_object('nom', d), gen_random_uuid());
  IF r->>'raison' IS DISTINCT FROM 'caisse_vide' THEN RAISE EXCEPTION 'fermer vide: %', r; END IF;

  -- Ecriture directe de l'ecran : refusee.
  BEGIN
    INSERT INTO public.caisses_fret(leader, statut) VALUES (n, 'ouverte');
    RAISE EXCEPTION 'insert_direct_accepte';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE public.caisses_fret SET statut = 'en_transit' WHERE id = c;
    RAISE EXCEPTION 'update_direct_accepte';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- Controle cible : reserve au Chef des Douanes.
  BEGIN
    r := public.douane_caisse_controler(c, gen_random_uuid());
    IF (r->>'ok')::boolean IS TRUE THEN RAISE EXCEPTION 'controle_non_chef_accepte: %', r; END IF;
  EXCEPTION WHEN insufficient_privilege THEN NULL; -- exiger_poste : autorite_insuffisante
  WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e LIKE 'controle_non_chef_accepte%' THEN RAISE; END IF;
  END;
  RESET ROLE;

  -- Contenu pose comme l'aurait fait fret_objet_agir : metal declare, medicaments NON declares
  -- (5 x 22 = 110 FR -> amende 22), arme du marche noir.
  INSERT INTO public.contenu_caisses_fret(caisse_id, deposant, objet, quantite) VALUES
    (c, n, '{"name":"Métal","stackKey":"metal","stackable":true}', 10),
    (c, n, '{"name":"Médicaments","stackKey":"medicaments","stackable":true}', 5),
    (c, n, '{"name":"Pistolet","type":"arme","legal":false}', 1);
  SELECT id INTO l_med FROM public.contenu_caisses_fret WHERE caisse_id = c AND objet->>'stackKey' = 'medicaments';

  SET LOCAL ROLE authenticated;
  r := public.fret_caisse_commande('fermer', c, jsonb_build_object('nom', d, 'declaration', 'Métal', 'valeur', 150,
    'non_declares', jsonb_build_array(l_med)), gen_random_uuid());
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'fermer: %', r; END IF;
  RESET ROLE;
  IF (SELECT declaree FROM public.contenu_caisses_fret WHERE id = l_med) IS NOT FALSE
     OR (SELECT count(*) FROM public.contenu_caisses_fret WHERE caisse_id = c AND declaree) <> 2
     OR (SELECT dissimulation FROM public.caisses_fret WHERE id = c) IS NULL THEN
    RAISE EXCEPTION 'declaration non enregistree'; END IF;

  -- Inspection deterministe (le tirage 1 sur 3 de l'expedition est aleatoire).
  r := public.fret_inspecter_interne(c, 'banc');
  IF jsonb_array_length(r->'saisis') <> 1 OR (r->>'amende')::integer <> 22 THEN RAISE EXCEPTION 'inspection: %', r; END IF;
  IF (SELECT quantite FROM public.contenu_caisses_fret WHERE caisse_id = c AND objet->>'type' = 'arme') <> 0 THEN
    RAISE EXCEPTION 'arme non saisie'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.amendes_tresor WHERE jugement_id = 'fret-' || c::text AND montant = 22 AND condamne = n) THEN
    RAISE EXCEPTION 'amende absente'; END IF;
  SELECT jsonb_array_length(coalesce(convocations, '[]'::jsonb)) INTO v_conv1 FROM public.personnages_donnees WHERE name = n;
  IF v_conv1 <> v_conv + 1 THEN RAISE EXCEPTION 'convocation % -> %', v_conv, v_conv1; END IF;

  SET LOCAL ROLE authenticated;
  r := public.fret_caisse_commande('expedier', c, '{}', gen_random_uuid());
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'expedier: %', r; END IF;
  RESET ROLE;
  IF (SELECT statut FROM public.caisses_fret WHERE id = c) <> 'en_transit' THEN RAISE EXCEPTION 'pas en transit'; END IF;
  SELECT pa INTO pa1 FROM public.personnages_donnees WHERE name = n;
  IF pa1 <> pa0 - 2 THEN RAISE EXCEPTION 'PA % -> %', pa0, pa1; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (caisse %, arme saisie, amende 22, PA % -> %)', c, pa0, pa1;
END $$;
