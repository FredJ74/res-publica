-- Banc annule de 20261103020000_trading_matieres_premieres : a jouer APRES la migration, dans la
-- meme transaction ; l'exception finale annule tout. Jean Jaaj (bureau prestige loue, chef d'une
-- organisation economique) recoit le temps du banc un ordinateur et une box.
DO $$
DECLARE uj uuid; ux uuid; nx text; r jsonb; out text := ''; v_org text := 'orga_1792355539137';
  v_ent text; v_res text; c_org0 numeric; c_org1 numeric; c_ent0 numeric; c_ent1 numeric; v_box uuid;
BEGIN
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = 'Jean Jaaj';
  SELECT name, user_id INTO nx, ux FROM public.personnages_donnees WHERE user_id IS NOT NULL AND name NOT IN ('Jean Jaaj') ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale', current_building='centre-affaires',
         current_room='bureau_prestige', current_street=NULL, pa=greatest(coalesce(pa,0),10), hospitalisation=NULL,
         inventory = coalesce(CASE WHEN jsonb_typeof(inventory)='array' THEN inventory END,'[]'::jsonb)
           || '[{"name":"Ordinateur","generique_id":"ordinateur-complet","icon":"ti-package"},{"name":"Box internet","generique_id":"box-internet","icon":"ti-package"}]'::jsonb
   WHERE name = 'Jean Jaaj';
  -- Un entrepot et une matiere effectivement disponibles (au moins 2).
  SELECT b.id, s.key INTO v_ent, v_res FROM public.entrepots_par_ville ep
    JOIN public.batiments_etat b ON b.id = 'republic_' || ep.ville || '_' || ep.building_id
    CROSS JOIN LATERAL jsonb_each(coalesce(public.batiment_etat_lire(b.data)->'entrepot'->'stock','{}'::jsonb)) s
   WHERE jsonb_typeof(s.value)='number' AND (s.value::text)::numeric >= 2
     AND EXISTS (SELECT 1 FROM public.ressources_economie re WHERE re.cle = s.key) LIMIT 1;
  c_org0 := (SELECT (data::jsonb->>'caisse')::numeric FROM public.organisations WHERE id = v_org);
  c_ent0 := public.entrepot_caisse_lire(v_ent);
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);

  r := public.trading_cours(); out := out || 'cours sans equipement=' || coalesce(r->>'raison','?');
  PERFORM set_config('request.path', '/rpc/equipement_installer', true);
  r := public.equipement_installer('ordinateur-complet'); out := out || ' | ordinateur=' || coalesce(r->>'ok','?');
  r := public.equipement_installer('ordinateur-complet'); out := out || ' | 2e ordinateur=' || coalesce(r->>'raison','?');
  r := public.equipement_installer('box-internet'); out := out || ' | box=' || coalesce(r->>'ok','?');
  r := public.equipements_local_lire(); out := out || ' | connexion=' || (r->>'connexion') || ', installes=' || jsonb_array_length(r->'installes');
  r := public.trading_cours();
  out := out || ' | cours: entrepots=' || jsonb_array_length(r->'entrepots') || ', orgas=' || jsonb_array_length(r->'organisations');
  PERFORM set_config('request.path', '/rpc/trading_acheter', true);
  r := public.trading_acheter(v_org, v_ent, v_res, 2);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'acheter: % (%/%)', r, v_ent, v_res; END IF;
  out := out || ' | achat ' || v_res || ' x2 a ' || v_ent || ' = ' || (r->>'montant') || ' FR, pa=' || (r->>'pa');
  r := public.trading_acheter(v_org, v_ent, v_res, 999999); out := out || ' | trop=' || coalesce(r->>'raison','?');
  RESET ROLE;
  c_org1 := (SELECT (data::jsonb->>'caisse')::numeric FROM public.organisations WHERE id = v_org);
  c_ent1 := public.entrepot_caisse_lire(v_ent);
  out := out || ' | caisse orga ' || c_org0 || '->' || c_org1 || ', entrepot +' || (c_ent1 - c_ent0);
  out := out || ' | fret=' || (SELECT statut || '/' || building_destination || '/dedouanee=' || dedouanee || '/q=' ||
            (SELECT sum(quantite) FROM public.contenu_caisses_fret cc WHERE cc.caisse_id = c.id)
            FROM public.caisses_fret c WHERE destinataire = 'Jean Jaaj' ORDER BY date_creation DESC LIMIT 1);
  SELECT id INTO v_box FROM public.equipements_installes WHERE proprietaire='Jean Jaaj' AND generique_id='box-internet';
  SET LOCAL ROLE authenticated;
  r := public.organisation_trader_autoriser(v_org, 'Jean Jaaj', true); out := out || ' | autoriser soi (pas membre ordinaire)=' || coalesce(r->>'raison', r->>'ok');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ux, 'role', 'authenticated')::text, true);
  r := public.trading_acheter(v_org, v_ent, v_res, 1); out := out || ' | tiers=' || coalesce(r->>'raison','?');
  r := public.organisation_trader_autoriser(v_org, nx, true); out := out || ' | tiers autorise=' || coalesce(r->>'raison','?');
  r := public.equipement_desinstaller(v_box); out := out || ' | tiers desinstalle=' || coalesce(r->>'raison','?');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/equipement_desinstaller', true);
  r := public.equipement_desinstaller(v_box); out := out || ' | desinstaller box=' || coalesce(r->>'ok','?');
  r := public.trading_cours(); out := out || ' | cours apres=' || coalesce(r->>'raison','?');
  RAISE EXCEPTION 'BANC (annule) : %', out;
END $$;
