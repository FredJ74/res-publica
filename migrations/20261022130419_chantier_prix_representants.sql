-- #57 PREPAREE. Definition explicite du meme setter, controles et droits auditablement conserves.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_prix_definir(text,jsonb)');
IF h IS NULL OR h NOT IN('4dcd2727c83b49a29fcf0068238df98f','67fde13bf496f70e7babb1c960cc38c2') THEN RAISE EXCEPTION 'definition_non_examinee: chantier_prix_definir';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.chantier_prix_definir(p_terrain_id text,p_prix jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE v_id text; v_acteur text:=public.mon_personnage(); v_pays text; v_etat jsonb; v_ch jsonb; v_k text; v_val jsonb; v_n numeric;
BEGIN
  IF v_acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name=v_acteur;
  SELECT t.id,t.data::jsonb INTO v_id,v_etat FROM public.terrains_etat t WHERE t.country=v_pays AND (t.id=p_terrain_id OR t.building_id=p_terrain_id AND t.data::jsonb->>'city'=(SELECT current_city FROM public.personnages_donnees WHERE name=v_acteur)) ORDER BY (t.id=p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF v_etat IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_proprietaire'); END IF;
  PERFORM public.chantier_autorite_exiger_interne(v_etat->>'proprietaire',v_pays,v_etat->>'city');
  v_ch:=v_etat->'chantier';
  IF v_ch IS NULL OR (v_ch->>'progressionJours')::numeric >= (v_ch->>'dureeJours')::numeric
     OR nullif(v_etat->>'succession_gel','') IS NOT NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','chantier_indisponible'); END IF;
  IF jsonb_typeof(p_prix) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('ok',false,'raison','prix_invalides'); END IF;
  FOR v_k,v_val IN SELECT * FROM jsonb_each(p_prix) LOOP
    IF v_k NOT IN ('bois','minerai','metal') OR jsonb_typeof(v_val) NOT IN ('string','number') OR (v_val#>>'{}') !~ '^(0|[1-9][0-9]*)$' THEN
      RETURN jsonb_build_object('ok',false,'raison','prix_invalides'); END IF;
    v_n:=(v_val#>>'{}')::numeric;
    v_ch:=jsonb_set(v_ch,ARRAY['prixAchatPJ'],coalesce(v_ch->'prixAchatPJ','{}')||jsonb_build_object(v_k,v_n));
  END LOOP;
  v_etat:=jsonb_set(v_etat,'{chantier}',v_ch);
  UPDATE public.terrains_etat SET data=v_etat::text,updated_at=now() WHERE id=v_id;
  RETURN jsonb_build_object('ok',true,'etat',v_etat);
END;$function$;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.chantier_commande(text,text,text,jsonb)');
IF h='e2e4467e0671aec7c0984b67d52f49ee' THEN
s:=replace(s,$a0$ ELSIF p_action='plan' THEN$a0$,$b0$ ELSIF p_action='prix' THEN
  IF p_parametres-ARRAY['prix']<>'{}' OR jsonb_typeof(p_parametres->'prix') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'prix_invalides';END IF;
  r:=public.chantier_prix_definir(t.id,p_parametres->'prix');
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'prix_invalides';END IF;
  SELECT data::jsonb INTO etat FROM public.terrains_etat WHERE id=t.id;
 ELSIF p_action='plan' THEN$b0$);
s:=replace(s,$a1$IF SQLERRM=ANY(ARRAY[$a1$,$b1$IF SQLERRM=ANY(ARRAY['prix_invalides',$b1$);
EXECUTE s;
ELSIF h IS DISTINCT FROM '106d75cbaecc936f53bdc005acd9ab40' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_commande(text,text,text,jsonb)';END IF;
END;$p$;
REVOKE ALL ON FUNCTION public.chantier_prix_definir(text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
