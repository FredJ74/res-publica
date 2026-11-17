-- Banc annulé des failles de la fiche (17/11/2026). Rejouer APRÈS la migration 20261117010000 : il doit lever
-- 'BANC ANNULE' avec hp<=100, dis inchangé à la triche, baisse admise, pèlerinage +10 DIS, domicile changé au serveur.
DO $t$
DECLARE v_uid uuid; v_nom text; a record; b record; c record; v_p jsonb; v_d jsonb; v_out text := '';
BEGIN
  SELECT d.user_id, d.name INTO v_uid, v_nom FROM public.personnages_donnees d JOIN auth.users u ON u.id=d.user_id
   WHERE NOT u.is_anonymous ORDER BY (d.name='Arnie') DESC LIMIT 1;
  SELECT pa, hp, (resources->>'dis')::numeric dis, effets_actifs::text eff, bonus_lobbyiste lob, domicile::text dom, current_city, country, liquide
    INTO a FROM public.personnages_donnees WHERE user_id=v_uid;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_uid,'role','authenticated')::text, true);
  PERFORM set_config('request.path', '/rest/v1/personnages', true);
  SET LOCAL ROLE authenticated;
  UPDATE public.personnages SET hp=999, effets_actifs='[{"t":"triche"}]'::jsonb, bonus_lobbyiste=99,
     domicile='{"country":"soviet","city":"capitale","depuis":1}'::jsonb,
     resources=jsonb_set(resources,'{dis}','9999') WHERE user_id=v_uid;
  RESET ROLE;
  SELECT hp, (resources->>'dis')::numeric dis, effets_actifs::text eff, bonus_lobbyiste lob, domicile::text dom INTO b FROM public.personnages_donnees WHERE user_id=v_uid;
  v_out := v_out || format('TRICHE hp %s->%s dis %s->%s eff_inchange=%s lob %s->%s dom_inchange=%s | ', a.hp, b.hp, a.dis, b.dis, a.eff IS NOT DISTINCT FROM b.eff, a.lob, b.lob, a.dom IS NOT DISTINCT FROM b.dom);
  SET LOCAL ROLE authenticated;
  UPDATE public.personnages SET resources=jsonb_set(resources,'{dis}', to_jsonb(greatest(0, a.dis-5))) WHERE user_id=v_uid;
  RESET ROLE;
  SELECT (resources->>'dis')::numeric dis INTO c FROM public.personnages_donnees WHERE user_id=v_uid;
  v_out := v_out || format('BAISSE dis -> %s | ', c.dis);
  PERFORM set_config('request.path', '/rpc/pelerinage_accomplir', true);
  SET LOCAL ROLE authenticated;
  v_p := public.pelerinage_accomplir();
  PERFORM set_config('request.path', '/rpc/domicile_changer', true);
  v_d := public.domicile_changer();
  RESET ROLE;
  v_out := v_out || format('PELERIN %s | DOMICILE %s | anon_rumeurs=%s anon_pel=%s auth_pel=%s',
    v_p, v_d, has_function_privilege('anon','public.rumeurs_organisations_cibles()','execute'),
    has_function_privilege('anon','public.pelerinage_accomplir()','execute'),
    has_function_privilege('authenticated','public.pelerinage_accomplir()','execute'));
  RAISE EXCEPTION 'BANC ANNULE % (avant: pa=% dis=% ville=%/% dom=% liquide=%)', v_out, a.pa, a.dis, a.country, a.current_city, a.dom, a.liquide;
END $t$;
