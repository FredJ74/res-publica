CREATE OR REPLACE FUNCTION public.police_reddition_resoudre(p_rencontre text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $fn$
DECLARE v_nom text; v_pj public.personnages_donnees%ROWTYPE;
 v_i public.police_interceptions%ROWTYPE; v_jugement text; v_detention jsonb;
BEGIN
 v_nom:=public.mon_personnage();
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent'); END IF;
 SELECT * INTO v_i FROM public.police_interceptions
 WHERE personnage=v_nom AND rencontre=p_rencontre AND expires_at>now() FOR UPDATE;
 IF NOT FOUND OR v_i.country IS DISTINCT FROM v_pj.country OR v_i.city IS DISTINCT FROM v_pj.current_city
 OR v_i.building IS DISTINCT FROM v_pj.current_building
 OR (v_i.street IS NOT NULL AND v_i.street IS DISTINCT FROM v_pj.current_street)
 OR (v_i.street IS NULL AND v_i.room IS DISTINCT FROM v_pj.current_room) THEN
 RETURN jsonb_build_object('ok',false,'raison','rencontre_invalide'); END IF;
 SELECT r.id INTO v_jugement FROM public.justice_recherches(v_nom) r
 WHERE r.country=v_pj.country ORDER BY r.id LIMIT 1;
 IF v_jugement IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','condamnation_absente'); END IF;
 v_detention:=public.justice_executer_condamnation_soi(v_jugement);
 IF NOT coalesce((v_detention->>'ok')::boolean,false) OR v_detention->>'detention_id' IS NULL THEN
 RAISE EXCEPTION 'detention_non_confirmee'; END IF;
 UPDATE public.police_interceptions SET expires_at=now() WHERE personnage=v_nom AND rencontre=p_rencontre;
 RETURN v_detention;
END;
$fn$;
REVOKE ALL ON FUNCTION public.police_reddition_resoudre(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.police_reddition_resoudre(text) TO authenticated;
