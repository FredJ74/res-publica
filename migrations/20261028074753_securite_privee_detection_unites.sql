-- Scission technique sous 12 500 caractères, pas une nouvelle mécanique.
-- Dépend de 20261027222500 ; vérifier le détecteur vivant avant toute application.
-- La RPC police_detection_verifier demeure seule responsable du jet et du registre.
DO $patch$
DECLARE s text; a text; b text; old text;
BEGIN
 s:=pg_get_functiondef('public.police_detection_verifier(text,text,text)'::regprocedure);
 a:='IF NOT FOUND THEN RETURN jsonb_build_object(''ok'',false,''raison'',''effectifs_absents''); END IF;';
 b:='-- L''absence de commissariat ne supprime pas les agents privés réellement présents.';
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detecteur_commissariat_conflit';
 ELSE s:=replace(s,a,b); END IF;
 a:='v_agents:=v_bat.data::jsonb->''effectifsPolice''->''policiers'';'
    ||chr(10)||' IF jsonb_typeof(v_agents) IS DISTINCT FROM ''array'' THEN RETURN jsonb_build_object(''ok'',false,''raison'',''effectifs_invalides''); END IF;';
 b:='v_agents:=CASE WHEN jsonb_typeof(v_bat.data::jsonb->''effectifsPolice''->''policiers'')=''array'' THEN v_bat.data::jsonb->''effectifsPolice''->''policiers'' ELSE ''[]''::jsonb END;'
    ||chr(10)||' v_agents:=v_agents || public.securite_agents_prives_presents_interne(v_pj.country,v_pj.current_city,p_batiment,p_piece,p_rue,v_nom);';
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detecteur_effectifs_conflit';
 ELSE s:=replace(s,a,b); END IF;
 a:=' FOR v_agent IN SELECT value FROM jsonb_array_elements(v_agents) LOOP'
   ||chr(10)||' IF ((p_rue IS NOT NULL AND v_agent->>''rueNoeudId''=p_rue)'
   ||chr(10)||' OR (p_rue IS NULL AND v_agent->>''buildingId''=p_batiment AND v_agent->>''roomId''=p_piece)) AND coalesce((v_agent->>''pa'')::integer,12)>0 THEN'
   ||chr(10)||' v_count:=v_count+1; v_per:=v_per+coalesce((v_agent->''stats''->>''PER'')::numeric,12);'
   ||chr(10)||' END IF; END LOOP;'
   ||chr(10)||' IF v_count=0 THEN RETURN jsonb_build_object(''ok'',false,''raison'',''aucun_policier_present''); END IF;'
   ||chr(10)||' v_per:=v_per/v_count+(v_count-1)-CASE WHEN p_rue IS NOT NULL THEN 2 ELSE 0 END;';
 b:=' v_agents:=public.securite_ordre_detection_interne(v_agents,p_batiment,p_piece,p_rue);'
   ||chr(10)||' v_count:=jsonb_array_length(v_agents);'
   ||chr(10)||' IF v_count=0 THEN RETURN jsonb_build_object(''ok'',false,''raison'',''aucun_policier_present''); END IF;';
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detecteur_groupes_conflit';
 ELSE s:=replace(s,a,b); END IF;
 a:=' v_chance:=greatest(10,least(90,50+5*(v_dis-v_per)));'
   ||chr(10)||' IF random()*100 < v_chance THEN RETURN jsonb_build_object(''ok'',true,''detecte'',false); END IF;'
   ||chr(10)||' v_id:=''police-''||md5(v_nom||clock_timestamp()::text||random()::text);'
   ||chr(10)||' INSERT INTO public.police_interceptions(personnage,rencontre,country,city,building,room,street)'
   ||chr(10)||' VALUES(v_nom,v_id,v_pj.country,v_pj.current_city,p_batiment,p_piece,p_rue);'
   ||chr(10)||' RETURN jsonb_build_object(''ok'',true,''detecte'',true,''rencontre'',v_id);';
 b:=' FOR v_agent IN SELECT value FROM jsonb_array_elements(v_agents) LOOP'
   ||chr(10)||'   v_per:=(v_agent->>''perception'')::numeric;'
   ||chr(10)||'   v_chance:=greatest(10,least(90,50+5*(v_dis-v_per)));'
   ||chr(10)||'   IF random()*100 < v_chance THEN CONTINUE; END IF;'
   ||chr(10)||'   v_id:=(CASE WHEN (v_agent->>''categorie'')::integer=0 THEN ''police-'' ELSE ''prive-'' END)'
   ||chr(10)||'     ||md5(v_nom||clock_timestamp()::text||random()::text);'
   ||chr(10)||'   INSERT INTO public.police_interceptions(personnage,rencontre,country,city,building,room,street,intervenants)'
   ||chr(10)||'   VALUES(v_nom,v_id,v_pj.country,v_pj.current_city,p_batiment,p_piece,p_rue,v_agent->''matricules'');'
   ||chr(10)||'   RETURN jsonb_build_object(''ok'',true,''detecte'',true,''rencontre'',v_id,''effectif'',(v_agent->>''effectif'')::integer);'
   ||chr(10)||' END LOOP;'
   ||chr(10)||' RETURN jsonb_build_object(''ok'',true,''detecte'',false);';
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detecteur_jet_sequence_conflit';
 ELSE s:=replace(s,a,b); END IF;
 a:=' SELECT rencontre INTO v_id FROM public.police_interceptions';
 b:=' SELECT rencontre,CASE WHEN jsonb_typeof(intervenants)=''array'' THEN jsonb_array_length(intervenants) ELSE 1 END'
   ||chr(10)||' INTO v_id,v_count FROM public.police_interceptions';
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detecteur_reprise_effectif_conflit';
 ELSE s:=replace(s,a,b); END IF;
 a:='IF v_id IS NOT NULL THEN RETURN jsonb_build_object(''ok'',true,''detecte'',true,''rencontre'',v_id); END IF;';
 b:='IF v_id IS NOT NULL THEN RETURN jsonb_build_object(''ok'',true,''detecte'',true,''rencontre'',v_id,''effectif'',v_count); END IF;';
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detecteur_reprise_reponse_conflit';
 ELSE s:=replace(s,a,b); END IF;
 EXECUTE s;
END $patch$;
