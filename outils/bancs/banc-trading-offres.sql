-- Banc annule de 20261103030000_trading_offres_achat : a jouer APRES la migration, dans la meme
-- transaction ; l'exception finale annule tout. Jean Jaaj, connecte dans son bureau, achete pour son
-- organisation A et sert l'offre depuis son local au nom d'une organisation B fictive.
DO $$
DECLARE uj uuid; r jsonb; out text := ''; oa text := 'orga_1792355539137'; ob text := 'orga_banc_offres';
  fonds text := 'fonds-republic-1792353134722-876265'; v_offre uuid; v_o2 uuid; v_o3 uuid; ca0 numeric; ca1 numeric; cb1 numeric;
BEGIN
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = 'Jean Jaaj';
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale', current_building='centre-affaires',
         current_room='bureau_prestige', current_street=NULL, pa=greatest(coalesce(pa,0),10) WHERE name = 'Jean Jaaj';
  INSERT INTO public.equipements_installes (proprietaire, pays, ville, batiment, piece, generique_id, objet) VALUES
    ('Jean Jaaj','republic','capitale','centre-affaires','bureau_prestige','ordinateur-complet','{"name":"Ordinateur"}'),
    ('Jean Jaaj','republic','capitale','centre-affaires','bureau_prestige','box-internet','{"name":"Box internet"}');
  INSERT INTO public.organisations (id, country_origine, data) VALUES (ob, 'republic','{"id":"orga_banc_offres","nom":"Banc B","type":"economique","chef":"Jean Jaaj","caisse":1000,"membres":[{"nom":"Jean Jaaj"}]}');
  UPDATE public.entreprises SET data = jsonb_set(data, '{stockMatieres}', '{"bois":10}') WHERE id = fonds;
  ca0 := (SELECT (data::jsonb->>'caisse')::numeric FROM public.organisations WHERE id = oa);
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);

  r := public.offre_achat_publier('organisation', oa, 'bois', 5, 6);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'publier: %', r; END IF;
  v_offre := (r->>'offre')::uuid; out := out || 'publiee, bloque=' || (r->>'montant_bloque');
  r := public.offres_achat_lire(); out := out || ' | lire: offres=' || jsonb_array_length(r->'offres') || ', locaux=' || jsonb_array_length(r->'locaux');
  r := public.offre_achat_servir(v_offre, 3, 'local', oa, fonds); out := out || ' | servir sa propre orga=' || coalesce(r->>'raison','?');
  PERFORM set_config('request.path', '/rpc/offre_achat_servir', true);
  r := public.offre_achat_servir(v_offre, 3, 'local', ob, fonds);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'servir: %', r; END IF;
  out := out || ' | servi 3 = ' || (r->>'montant') || ' FR';
  r := public.offre_achat_servir(v_offre, 50, 'local', ob, fonds); out := out || ' | reste servi=' || coalesce(r->>'quantite', r->>'raison');
  r := public.offre_achat_servir(v_offre, 1, 'local', ob, fonds); out := out || ' | offre servie=' || coalesce(r->>'raison','?');
  r := public.offre_achat_servir(v_offre, 1, 'inventaire', ob, null); out := out || ' | inventaire=' || coalesce(r->>'raison','?');
  r := public.offre_achat_publier('organisation', oa, 'bois', 2, 4); v_o2 := (r->>'offre')::uuid;
  r := public.offre_achat_retirer(v_o2); out := out || ' | retiree, rembourse=' || (r->>'rembourse');
  r := public.offre_achat_publier('organisation', oa, 'metal', 1, 9); v_o3 := (r->>'offre')::uuid;
  r := public.offre_achat_publier('entrepot', null, 'bois', 1, 5); out := out || ' | entrepot sans poste=' || coalesce(r->>'raison','?');
  r := public.offre_achat_publier('organisation', oa, 'bois', 1, 0); out := out || ' | prix 0=' || coalesce(r->>'raison','?');
  RESET ROLE;
  UPDATE public.offres_achat SET expire_le = now() - interval '1 minute' WHERE id = v_o3;
  r := public.offres_achat_expirer_nuit(); out := out || ' | nuit: expirees=' || (r->>'expirees') || ', rembourse=' || (r->>'rembourse');
  ca1 := (SELECT (data::jsonb->>'caisse')::numeric FROM public.organisations WHERE id = oa);
  cb1 := (SELECT (data::jsonb->>'caisse')::numeric FROM public.organisations WHERE id = ob);
  out := out || ' | caisse A ' || ca0 || '->' || ca1 || ' (-30), B 1000->' || cb1 || ' (+30)';
  out := out || ' | local bois=' || (SELECT data->'stockMatieres'->>'bois' FROM public.entreprises WHERE id = fonds) || ' (5)';
  out := out || ' | fret=' || (SELECT count(*) || ' caisses, ' || sum(cc.quantite) || ' bois' FROM public.caisses_fret c
                                 JOIN public.contenu_caisses_fret cc ON cc.caisse_id = c.id WHERE c.destinataire = 'Jean Jaaj');
  out := out || ' | statuts=' || (SELECT string_agg(statut, ',' ORDER BY cree_le) FROM public.offres_achat WHERE auteur = 'Jean Jaaj');
  RAISE EXCEPTION 'BANC (annule) : %', out;
END $$;
