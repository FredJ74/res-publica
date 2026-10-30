-- #219 : étendre la porte transactionnelle existante, mêmes reçus/verrous/paiements.
DO $international$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.transport_effectuer(text,text,text,uuid)'::regprocedure);
 IF position('-- transport_international_commun_v1' IN s)>0 THEN RETURN;END IF;
 a:='p_mode NOT IN (''train'',''bus'')';b:='p_mode NOT IN (''train'',''bus'',''avion'',''bateau'')';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'transport_modes_non_examines';END IF;
 s:=replace(s,a,b);
 a:='p.current_building LIKE ''centre-multinodal-%'' OR';
 b:='p.current_building LIKE ''centre-multinodal-%'' OR (p_mode=''bateau'' AND p.current_building LIKE ''port-%'' AND p.current_room IN (''quai'',''quai_principal'')) OR';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'transport_depart_non_examine';END IF;
 s:=replace(s,a,b);
 a:=' IF p_pays IS DISTINCT FROM p.country OR p_ville=p.current_city OR NOT EXISTS';
 b:=' -- transport_international_commun_v1'||chr(10)
 ||' IF p_mode=''avion'' AND p.current_room IS DISTINCT FROM ''zone_embarquement'' THEN RETURN jsonb_build_object(''ok'',false,''raison'',''controle_douanier_requis'');END IF;'||chr(10)
 ||' IF p_mode=''bateau'' AND NOT coalesce(p.current_building LIKE ''port-%'' AND p.current_room IN (''quai'',''quai_principal''),false) THEN RETURN jsonb_build_object(''ok'',false,''raison'',''pas_au_terminal'');END IF;'||chr(10)
 ||' IF (CASE WHEN p_mode IN (''train'',''bus'') THEN p_pays IS DISTINCT FROM p.country OR p_ville=p.current_city'
 ||' ELSE p_pays IS NOT DISTINCT FROM p.country OR p_ville IS DISTINCT FROM ''capitale'' END) OR NOT EXISTS';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'transport_destination_non_examinee';END IF;
 s:=replace(s,a,b);
 a:='CASE p_mode WHEN ''train'' THEN ''prendre_train'' ELSE ''prendre_bus_taxi'' END';
 b:='CASE p_mode WHEN ''train'' THEN ''prendre_train'' WHEN ''bus'' THEN ''prendre_bus_taxi'' WHEN ''avion'' THEN ''prendre_avion'' ELSE ''prendre_bateau'' END';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>2 THEN RAISE EXCEPTION 'transport_tarifs_non_examines';END IF;
 s:=replace(s,a,b);
 a:=' n:=moi;';
 b:=' n:=moi;'||chr(10)
 ||' IF p_mode IN (''avion'',''bateau'') THEN'||chr(10)
 ||' IF p_mode=''avion'' AND EXISTS(SELECT 1 FROM unnest(ids) membre WHERE NOT public.douane_passage_valide_interne(membre,''avion'')) THEN'
 ||' r:=jsonb_build_object(''ok'',false,''raison'',''controle_douanier_requis'');RAISE EXCEPTION USING ERRCODE=''P2191'',MESSAGE=''controle_requis'';END IF;'||chr(10)
 ||' r:=public.douane_controle_groupe_interne(moi,p_mode);'
 ||' IF NOT coalesce((r->>''ok'')::boolean,false) THEN'
 ||' IF coalesce((r->>''arrestation'')::boolean,false) THEN RETURN r;END IF;'
 ||' RAISE EXCEPTION USING ERRCODE=''P2191'',MESSAGE=''controle_refuse'';END IF;END IF;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'transport_transaction_non_examinee';END IF;
 s:=replace(s,a,b);
 a:='SET current_city=p_ville,current_building=b';b:='SET country=p_pays,current_city=p_ville,current_building=b';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'transport_position_non_examinee';END IF;
 EXECUTE replace(s,a,b);
END $international$;
