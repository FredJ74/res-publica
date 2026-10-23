-- #94 PREPAREE : lancement/paiement uniquement via chantier_commande('reamenager').
BEGIN;
DO $g$ DECLARE h text;s text;BEGIN
 SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.terrain_reamenagement_poser(text,jsonb)');
 IF h='a8a85325e5e42892733af3c1d0d97124' THEN
  s:=replace(s,'  v_moi := public.mon_personnage();', $nouveau$  RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');
  v_moi := public.mon_personnage();$nouveau$);EXECUTE s;
 ELSIF h IS DISTINCT FROM 'c8368ef267013ed5c4bfb5b0e4007b0d' THEN RAISE EXCEPTION 'definition_non_examinee: terrain_reamenagement_poser';END IF;
END;$g$;
COMMIT;
