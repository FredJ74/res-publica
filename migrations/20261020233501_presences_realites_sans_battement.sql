-- PR #56 : lecture des positions physiques, sans heartbeat ni expiration des PJ inactifs.
-- PREPAREE UNIQUEMENT : verifier le catalogue vivant avant application. Aucun changement de donnees.
-- La table presences fournit uniquement les accompagnants d'affichage ; elle n'est pas l'autorite de position.
DO $g$ DECLARE h text; BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.presences_realites_lire(text,text,text,text)'); IF h IS NOT NULL AND h<>'09f412fd439bfcf55f91e7c229233d90' THEN RAISE EXCEPTION 'definition_non_examinee: presences_realites_lire'; END IF; END;$g$;
CREATE OR REPLACE FUNCTION public.presences_realites_lire(p_country text,p_city text,p_building text,p_room text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE v_nom text:=public.mon_personnage(); v_moi public.personnages_donnees%rowtype; v_liste jsonb;
BEGIN
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 SELECT * INTO v_moi FROM public.personnages_donnees WHERE name=v_nom;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent'); END IF;
 IF v_moi.country IS DISTINCT FROM p_country OR v_moi.current_city IS DISTINCT FROM p_city THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 IF p_building='rue-centrale' THEN
  IF NOT (to_jsonb(v_moi)?'current_street') THEN RETURN jsonb_build_object('ok',false,'raison','schema_rue_indetermine'); END IF;
  IF v_moi.current_building IS NOT NULL OR (to_jsonb(v_moi)->>'current_street') IS DISTINCT FROM p_room THEN
   RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 ELSE
  IF p_building IS NULL OR p_room IS NULL OR v_moi.current_building IS DISTINCT FROM p_building OR v_moi.current_room IS DISTINCT FROM p_room THEN
   RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('name',d.name,'country',d.country,'city',d.current_city,
  'building_id',p_building,'room_id',p_room,'groupe_pnj',coalesce(p.groupe_pnj,'[]'::jsonb),'updated_at',d.updated_at) ORDER BY d.name),'[]'::jsonb)
 INTO v_liste FROM public.personnages_donnees d
 LEFT JOIN public.presences p ON p.name=d.name AND p.country=d.country AND p.city=d.current_city
  AND p.building_id=p_building AND p.room_id=p_room
 WHERE d.country=p_country AND d.current_city=p_city AND
  (CASE WHEN p_building='rue-centrale' THEN d.current_building IS NULL AND to_jsonb(d)->>'current_street'=p_room
   ELSE d.current_building=p_building AND d.current_room=p_room END);
 RETURN jsonb_build_object('ok',true,'presences',v_liste,'contrat',1);
END;
$function$;
REVOKE ALL ON FUNCTION public.presences_realites_lire(text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.presences_realites_lire(text,text,text,text) TO authenticated;
