CREATE OR REPLACE FUNCTION public.rue_position_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $fn$
DECLARE v_nom text; v_pj public.personnages_donnees%ROWTYPE;
BEGIN
 v_nom:=public.mon_personnage();
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent'); END IF;
 RETURN jsonb_build_object('ok',true,'country',v_pj.country,'city',v_pj.current_city,
 'building',v_pj.current_building,'room',v_pj.current_room,'street',v_pj.current_street);
END;
$fn$;
REVOKE ALL ON FUNCTION public.rue_position_lire() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.rue_position_lire() TO authenticated;
