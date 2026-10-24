-- #94 PREPAREE : meme vente, meme recu et memes prix pour les deux familles de chantier.
BEGIN;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.vendre_materiaux_chantier(text,text,text,text,integer,integer)');
IF h='ad287131c34487f495a9849ad23e39cb' THEN
s:=replace(s,$ancien$  v_pj          personnages%ROWTYPE;$ancien$,$nouveau$  v_emplacement text;
  v_pj          personnages%ROWTYPE;$nouveau$);
s:=replace(s,$ancien$  SELECT * INTO v_terrain FROM terrains_etat WHERE id = v_terrain_id FOR UPDATE;$ancien$,$nouveau$  SELECT * INTO v_terrain FROM public.terrains_etat WHERE country=p_country AND (id=v_terrain_id OR building_id=p_building_id AND data::jsonb->>'city'=v_pj.current_city) ORDER BY (id=v_terrain_id) DESC LIMIT 1 FOR UPDATE;$nouveau$);
s:=replace(s,$ancien$  -- PRESENCE PHYSIQUE,$ancien$,$nouveau$  v_terrain_id:=v_terrain.id;
  IF coalesce(v_pj.hp,0)<=0 OR coalesce(v_pj.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text OR EXISTS(SELECT 1 FROM public.detention_active(p_vendeur)) THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
  -- PRESENCE PHYSIQUE,$nouveau$);
s:=replace(s,$ancien$  v_chantier := v_data -> 'chantier';$ancien$,$nouveau$  v_emplacement:=CASE WHEN jsonb_typeof(v_data->'chantier')='object' THEN 'chantier' ELSE 'chantierReamenagement' END;v_chantier:=v_data->v_emplacement;$nouveau$);
s:=replace(s,$ancien$jsonb_build_object('chantier', v_chantier)$ancien$,$nouveau$jsonb_build_object(v_emplacement, v_chantier)$nouveau$);
EXECUTE s;ELSIF h IS DISTINCT FROM 'f3fbf8473b0a45e753f3402b9ae9849f' THEN RAISE EXCEPTION 'definition_non_examinee: vendre_materiaux_chantier(text,text,text,text,integer,integer)';END IF;
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.chantier_prix_definir(text,jsonb)');
IF h='67fde13bf496f70e7babb1c960cc38c2' THEN
s:=replace(s,$ancien$DECLARE v_id text;$ancien$,$nouveau$DECLARE v_emplacement text;v_id text;$nouveau$);
s:=replace(s,$ancien$  v_ch:=v_etat->'chantier';$ancien$,$nouveau$  v_emplacement:=CASE WHEN jsonb_typeof(v_etat->'chantier')='object' THEN 'chantier' ELSE 'chantierReamenagement' END;v_ch:=v_etat->v_emplacement;$nouveau$);
s:=replace(s,$ancien$jsonb_set(v_etat,'{chantier}',v_ch)$ancien$,$nouveau$jsonb_set(v_etat,ARRAY[v_emplacement],v_ch)$nouveau$);
EXECUTE s;ELSIF h IS DISTINCT FROM '992a2563cee23ea6e5ccaec15012cbaf' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_prix_definir(text,jsonb)';END IF;
END;$p$;
COMMIT;
