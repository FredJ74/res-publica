-- #219 : la zone lit le passage serveur pour chaque PJ, pas state.douanePassee.
DO $zone$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure);
 IF position('-- douane_zone_par_membre_v1' IN s)>0 THEN RETURN;END IF;
 a:='OR p_piece=''zone_embarquement''';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'zone_embarquement_definition_non_examinee';END IF;
 s:=replace(s,a,'');
 a:=' IF EXISTS(SELECT 1 FROM public.batiments_fermes';
 b:=' -- douane_zone_par_membre_v1'||chr(10)||' IF p_piece=''zone_embarquement'' AND NOT public.douane_passage_valide_interne(p_nom,''avion'') THEN'
 ||chr(10)||' RETURN jsonb_build_object(''ok'',false,''raison'',''controle_douanier_requis'');END IF;'
 ||chr(10)||a;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'zone_embarquement_garde_absente';END IF;
 EXECUTE replace(s,a,b);
END $zone$;
