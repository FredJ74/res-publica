-- #57 PREPAREE. Prix entiers : meme moteur sous la representation commune et le recu.
BEGIN;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.chantier_prix_definir(text,jsonb)');
IF h='4dcd2727c83b49a29fcf0068238df98f' THEN
s:=replace(s,$a0$v_acteur text:=public.mon_personnage();$a0$,$b0$v_id text; v_acteur text:=public.mon_personnage();$b0$);
s:=replace(s,$a1$  SELECT public.terrain_etat_lire(data) INTO v_etat FROM public.terrains_etat WHERE id=v_pays||'_'||p_terrain_id FOR UPDATE;
  IF v_etat IS NULL OR v_etat->>'proprietaire' IS DISTINCT FROM v_acteur THEN$a1$,$b1$  SELECT t.id,t.data::jsonb INTO v_id,v_etat FROM public.terrains_etat t WHERE t.country=v_pays AND (t.id=p_terrain_id OR t.building_id=p_terrain_id AND t.data::jsonb->>'city'=(SELECT current_city FROM public.personnages_donnees WHERE name=v_acteur)) ORDER BY (t.id=p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF v_etat IS NULL THEN$b1$);
s:=replace(s,$a2$  v_ch:=v_etat->'chantier';$a2$,$b2$  PERFORM public.chantier_autorite_exiger_interne(v_etat->>'proprietaire',v_pays,v_etat->>'city');
  v_ch:=v_etat->'chantier';$b2$);
s:=replace(s,$a3$WHERE id=v_pays||'_'||p_terrain_id;$a3$,$b3$WHERE id=v_id;$b3$);
EXECUTE s;
ELSIF h IS DISTINCT FROM '67fde13bf496f70e7babb1c960cc38c2' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_prix_definir(text,jsonb)';END IF;
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
