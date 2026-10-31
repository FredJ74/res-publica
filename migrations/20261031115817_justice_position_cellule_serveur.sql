-- #219 : l'écrou existant doit enregistrer aussi la cellule. Le navigateur ne
-- peut plus achever ce déplacement par une sauvegarde générale.
DO $cellule$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb)'::regprocedure);
 IF position('-- detention_cellule_serveur_v1' IN s)=0 THEN
 a:='  RETURN jsonb_build_object(''ok'',true,''detention_id'',v_id,''jour_debut'',v_jour_cible,''jour_fin'',v_jour_cible+p_jours);';
 b:='  -- detention_cellule_serveur_v1'||chr(10)
 ||'  IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles WHERE pays=p_country AND ville=p_city'
 ||' AND batiment=CASE WHEN p_city=''qhs'' THEN ''qhs-prison'' WHEN p_city=''capitale'' THEN ''commissariat'' ELSE ''commissariat-local'' END'
 ||' AND pieces ? CASE WHEN p_city=''qhs'' THEN ''cellules_qhs'' WHEN p_city=''capitale'' THEN ''prison'' ELSE ''geoles'' END) THEN RAISE EXCEPTION ''cellule_non_referencee'';END IF;'||chr(10)
 ||'  UPDATE public.personnages_donnees SET country=p_country,current_city=p_city,'
 ||'current_building=CASE WHEN p_city=''qhs'' THEN ''qhs-prison'' WHEN p_city=''capitale'' THEN ''commissariat'' ELSE ''commissariat-local'' END,'
 ||'current_room=CASE WHEN p_city=''qhs'' THEN ''cellules_qhs'' WHEN p_city=''capitale'' THEN ''prison'' ELSE ''geoles'' END,current_street=NULL,updated_at=clock_timestamp() WHERE name=p_nom;'||chr(10)||a;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'ecrou_position_definition_non_examinee';END IF;
 EXECUTE replace(s,a,b);
 END IF;
 s:=pg_get_functiondef('public.detention_qhs_poser_interne(text,text,text)'::regprocedure);
 IF position('-- detention_qhs_position_serveur_v1' IN s)>0 THEN RETURN;END IF;
 a:='         detention_qhs = jsonb_build_object(''enQHS'', true, ''paLimite1Jour'', false)';
 b:=a||','||chr(10)||'         -- detention_qhs_position_serveur_v1'||chr(10)
 ||'         country=v_det.country,current_city=''qhs'',current_building=''qhs-prison'',current_room=''cellules_qhs'',current_street=NULL,updated_at=clock_timestamp()';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'qhs_position_definition_non_examinee';END IF;
 EXECUTE replace(s,a,b);
END $cellule$;

-- Une ancienne porte d'auto-incarcération ne devient pas un transport gratuit
-- vers une prison choisie dans le navigateur. Les appels légitimes conservent
-- la ville réelle et la durée positive ; l'autorité judiciaire passe par ses portes.
DO $portes$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb)'::regprocedure);
 IF position('-- detention_soi_lieu_reel_v1' IN s)=0 THEN
 a:='  IF p_jours IS NULL OR p_jours < 0 OR p_jours > 3650 THEN';
 b:='  -- detention_soi_lieu_reel_v1'||chr(10)||'  IF p_jours IS NULL OR p_jours <= 0 OR p_jours > 3650 THEN';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detention_soi_duree_non_examinee';END IF;
 s:=replace(s,a,b);
 a:='  v_r := public.detention_ouvrir_interne(v_moi, p_raison, p_jours, v_ville, v_pays,';
 b:='  IF nullif(btrim(p_city),'''') IS NOT NULL AND p_city IS DISTINCT FROM (SELECT current_city FROM public.personnages_donnees WHERE name=v_moi) THEN'
 ||' RETURN jsonb_build_object(''ok'',false,''raison'',''ville_detention_invalide'');END IF;'||chr(10)||a;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detention_soi_lieu_non_examine';END IF;
 EXECUTE replace(s,a,b);
 END IF;
 s:=pg_get_functiondef('public.detention_transferer_qhs(text,integer,text,jsonb)'::regprocedure);
 IF position('-- qhs_soi_ville_condamnation_v1' IN s)>0 THEN RETURN;END IF;
 a:='  v_prec := v_det.id;';
 b:=a||chr(10)||'  -- qhs_soi_ville_condamnation_v1'||chr(10)
 ||'  IF nullif(btrim(p_city),'''') IS NOT NULL AND p_city IS DISTINCT FROM v_det.city THEN'
 ||' RETURN jsonb_build_object(''ok'',false,''raison'',''ville_detention_invalide'');END IF;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'qhs_soi_lieu_non_examine';END IF;
 EXECUTE replace(s,a,b);
END $portes$;
