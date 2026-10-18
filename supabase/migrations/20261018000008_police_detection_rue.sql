CREATE OR REPLACE FUNCTION public.police_detection_verifier(p_batiment text,p_piece text,p_rue text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $detect$
DECLARE v_nom text; v_pj public.personnages_donnees%ROWTYPE; v_bat public.batiments_etat%ROWTYPE;
 v_agents jsonb; v_agent jsonb; v_count integer:=0; v_per numeric:=0; v_dis numeric; v_chance numeric;
 v_id text; v_last timestamptz;
BEGIN
 v_nom:=public.mon_personnage();
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom FOR UPDATE;
 IF NOT FOUND OR v_pj.country<>'republic' OR v_pj.current_city IS NULL OR v_pj.est_emprisonne IS NOT NULL AND v_pj.est_emprisonne<>'null'::jsonb THEN
 RETURN jsonb_build_object('ok',false,'raison','joueur_indisponible'); END IF;
 IF (p_rue IS NOT NULL AND (v_pj.current_building IS NOT NULL OR v_pj.current_street IS DISTINCT FROM p_rue OR p_batiment IS NOT NULL OR p_piece IS NOT NULL))
 OR (p_rue IS NULL AND (p_batiment IS NULL OR p_piece IS NULL OR v_pj.current_building IS DISTINCT FROM p_batiment OR v_pj.current_room IS DISTINCT FROM p_piece)) THEN
 RETURN jsonb_build_object('ok',false,'raison','position_invalide'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.justice_recherches(v_nom) r WHERE r.country=v_pj.country) THEN
 RETURN jsonb_build_object('ok',false,'raison','non_recherche'); END IF;
 SELECT * INTO v_bat FROM public.batiments_etat WHERE country=v_pj.country AND city=v_pj.current_city
 AND building_id=CASE WHEN v_pj.current_city='capitale' THEN 'commissariat' ELSE 'commissariat-local' END;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','effectifs_absents'); END IF;
 v_agents:=v_bat.data::jsonb->'effectifsPolice'->'policiers';
 IF jsonb_typeof(v_agents) IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('ok',false,'raison','effectifs_invalides'); END IF;
 FOR v_agent IN SELECT value FROM jsonb_array_elements(v_agents) LOOP
 IF ((p_rue IS NOT NULL AND v_agent->>'rueNoeudId'=p_rue)
 OR (p_rue IS NULL AND v_agent->>'buildingId'=p_batiment AND v_agent->>'roomId'=p_piece)) AND coalesce((v_agent->>'pa')::integer,12)>0 THEN
 v_count:=v_count+1; v_per:=v_per+coalesce((v_agent->'stats'->>'PER')::numeric,12);
 END IF; END LOOP;
 IF v_count=0 THEN RETURN jsonb_build_object('ok',false,'raison','aucun_policier_present'); END IF;
 v_per:=v_per/v_count+(v_count-1)-CASE WHEN p_rue IS NOT NULL THEN 2 ELSE 0 END;
 SELECT rencontre INTO v_id FROM public.police_interceptions
 WHERE personnage=v_nom AND country=v_pj.country AND city=v_pj.current_city
 AND building IS NOT DISTINCT FROM p_batiment AND room IS NOT DISTINCT FROM p_piece
 AND street IS NOT DISTINCT FROM p_rue AND expires_at>now() LIMIT 1;
 IF v_id IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'detecte',true,'rencontre',v_id); END IF;
 SELECT attempted_at INTO v_last FROM public.police_detection_attempts
 WHERE personnage=v_nom AND country=v_pj.country AND city=v_pj.current_city
 AND building=coalesce(p_batiment,'@rue') AND room=coalesce(p_piece,p_rue) FOR UPDATE;
 IF v_last IS NOT NULL AND v_last>now()-interval '2 minutes' THEN
 RETURN jsonb_build_object('ok',true,'detecte',false,'raison','detection_deja_tentee'); END IF;
 INSERT INTO public.police_detection_attempts(personnage,country,city,building,room,attempted_at)
 VALUES(v_nom,v_pj.country,v_pj.current_city,coalesce(p_batiment,'@rue'),coalesce(p_piece,p_rue),now())
 ON CONFLICT(personnage,country,city,building,room) DO UPDATE SET attempted_at=excluded.attempted_at;
 v_dis:=8+coalesce((v_pj.resources->>'dis')::numeric,0)/10;
 v_chance:=greatest(10,least(90,50+5*(v_dis-v_per)));
 IF random()*100 < v_chance THEN RETURN jsonb_build_object('ok',true,'detecte',false); END IF;
 v_id:='police-'||md5(v_nom||clock_timestamp()::text||random()::text);
 INSERT INTO public.police_interceptions(personnage,rencontre,country,city,building,room,street)
 VALUES(v_nom,v_id,v_pj.country,v_pj.current_city,p_batiment,p_piece,p_rue);
 RETURN jsonb_build_object('ok',true,'detecte',true,'rencontre',v_id);
END;
$detect$;
REVOKE ALL ON FUNCTION public.police_detection_verifier(text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.police_detection_verifier(text,text,text) TO authenticated;
