-- #94 PREPAREE : extension du moteur existant, aucun moteur parallele.
BEGIN;
DO $patch$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.chantier_jour_traiter(text)');
IF h='6410338f9007370e43d05703cbf73913' THEN
s:=replace(s,$ancien$DECLARE r record;$ancien$,$nouveau$DECLARE emplacement text;r record;$nouveau$);
s:=replace(s,$ancien$ IF jsonb_typeof(snapshot->'chantier') IS DISTINCT FROM 'object' THEN$ancien$,$nouveau$ emplacement:=CASE WHEN jsonb_typeof(snapshot->'chantier')='object' THEN 'chantier' ELSE 'chantierReamenagement' END;
 IF jsonb_typeof(snapshot->emplacement) IS DISTINCT FROM 'object' THEN$nouveau$);
s:=replace(s,$ancien$ ch:=etat->'chantier';$ancien$,$nouveau$ ch:=etat->emplacement;$nouveau$);
s:=replace(s,$ancien$ IF ch->>'type' IS DISTINCT FROM 'construction' THEN$ancien$,$nouveau$ IF coalesce(ch->>'type','') NOT IN('construction','reamenagement') THEN$nouveau$);
s:=replace(s,$ancien$   SELECT jsonb_build_object('bois',bois,'minerai',minerai,'metal',metal) INTO besoin FROM public.chantiers_besoins_jour
    WHERE position_cycle=((num-1)%(SELECT count(*) FROM public.chantiers_besoins_jour))+1;$ancien$,$nouveau$   besoin:=public.chantier_besoin_jour_interne(ch,num);$nouveau$);
s:=replace(s,$ancien$jsonb_build_object('chantier',ch)$ancien$,$nouveau$jsonb_build_object(emplacement,ch)$nouveau$);
EXECUTE s;ELSIF h IS DISTINCT FROM 'c8d40a2ec77b7e7a5b2bf155eda5302c' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_jour_traiter';END IF;
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.chantier_travailler(text,text,text,integer)');
IF h='b737ee0f71bfd9265e5ca07aac3d9d90' THEN
s:=replace(s,$ancien$  v_id text;$ancien$,$nouveau$  v_emplacement text;v_id text;$nouveau$);
s:=replace(s,$ancien$  v_ch := v_data->'chantier';$ancien$,$nouveau$  v_emplacement:=CASE WHEN jsonb_typeof(v_data->'chantier')='object' THEN 'chantier' ELSE 'chantierReamenagement' END;v_ch:=v_data->v_emplacement;$nouveau$);
s:=replace(s,$ancien$  IF COALESCE(v_ch->>'type','') <> 'construction' THEN$ancien$,$nouveau$  IF COALESCE(v_ch->>'type','') NOT IN('construction','reamenagement') THEN$nouveau$);
s:=replace(s,$ancien$  SELECT * INTO v_besoin FROM public.chantiers_besoins_jour
   WHERE position_cycle = ((v_jour_num - 1) % (SELECT count(*) FROM public.chantiers_besoins_jour)) + 1;$ancien$,$nouveau$  SELECT (x->>'bois')::numeric AS bois,(x->>'minerai')::numeric AS minerai,(x->>'metal')::numeric AS metal INTO v_besoin FROM (SELECT public.chantier_besoin_jour_interne(v_ch,v_jour_num) AS x) b;$nouveau$);
s:=replace(s,$ancien$jsonb_build_object('chantier', v_ch)$ancien$,$nouveau$jsonb_build_object(v_emplacement, v_ch)$nouveau$);
EXECUTE s;ELSIF h IS DISTINCT FROM 'ad9418553c83871b63362aa1e0113d02' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_travailler';END IF;
END;$patch$;
COMMIT;
