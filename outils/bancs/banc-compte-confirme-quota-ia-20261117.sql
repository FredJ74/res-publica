-- Banc annulé du compte confirmé et du quota IA (17/11/2026), à rejouer après 20261117020000.
DO $t$
DECLARE v_uid uuid; v_anon uuid; v_nom text; v_anom text; r1 text; r2 text; r3 boolean; r4 boolean; q1 jsonb; q2 jsonb;
BEGIN
  SELECT d.user_id, d.name INTO v_uid, v_nom FROM public.personnages_donnees d JOIN auth.users u ON u.id=d.user_id WHERE NOT u.is_anonymous ORDER BY (d.name='Arnie') DESC LIMIT 1;
  SELECT d.user_id, d.name INTO v_anon, v_anom FROM public.personnages_donnees d JOIN auth.users u ON u.id=d.user_id WHERE u.is_anonymous LIMIT 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_uid,'role','authenticated','is_anonymous',false)::text, true);
  SET LOCAL ROLE authenticated;
  r1 := public.mon_personnage(); r3 := public.est_mon_personnage(v_nom); q1 := public.ia_quota_consommer();
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_anon,'role','authenticated','is_anonymous',true)::text, true);
  SET LOCAL ROLE authenticated;
  r2 := public.mon_personnage(); r4 := public.est_mon_personnage(v_anom); q2 := public.ia_quota_consommer();
  RESET ROLE;
  RAISE EXCEPTION 'BANC ANNULE confirme: mon_personnage=% est_mon=% quota=% | anonyme(%): mon_personnage=% est_mon=% quota=%', r1, r3, q1, v_anom, r2, r4, q2;
END $t$;
