-- #57 PREPAREE. Gardes des anciens chemins, memes moteurs sous les portes versionnees.
BEGIN;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.terrain_permis_acte(text,text,jsonb)');
IF h='bb14432f6064d189cdf9b3b85637f844' THEN
s:=replace(s,$a0$  IF p_acte NOT IN ('permis_deposer'$a0$,$b0$  IF p_acte='permis_plan_modifier' THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;
  IF p_acte NOT IN ('permis_deposer'$b0$);
EXECUTE s;
ELSIF h IS DISTINCT FROM 'f2a86c5c08a9f8ce7c95e0c677716b67' THEN RAISE EXCEPTION 'definition_non_examinee: terrain_permis_acte(text,text,jsonb)';END IF;
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.terrain_chantier_acte(text,text,text,integer,integer)');
IF h='81ffe6296a45947ee242e685ff3eea01' THEN
s:=replace(s,$a0$  v_lu := public.terrain_etat_verrouiller_interne(p_terrain_id);$a0$,$b0$  IF p_acte='chantier_accelerer' AND v_pays='republic' THEN RETURN jsonb_build_object('ok',false,'raison','delai_incompressible');END IF;
  v_lu := public.terrain_etat_verrouiller_interne(p_terrain_id);$b0$);
s:=replace(s,$a1$  IF p_acte = 'chantier_accelerer' THEN$a1$,$b1$  IF coalesce((v_ch->>'dureeJours')::numeric,0)<=0 OR coalesce((v_ch->>'progressionJours')::numeric,0)>=(v_ch->>'dureeJours')::numeric THEN RETURN jsonb_build_object('ok',false,'raison','chantier_a_son_terme');END IF;
  IF p_acte = 'chantier_accelerer' THEN$b1$);
EXECUTE s;
ELSIF h IS DISTINCT FROM 'aee482fdff5312df105be6db713eef43' THEN RAISE EXCEPTION 'definition_non_examinee: terrain_chantier_acte(text,text,text,integer,integer)';END IF;
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.chantier_travailler(text,text,text,integer)');
IF h='f20ec50e8dddd7586eb67ff7fb13c6ca' THEN
s:=replace(s,$a0$  v_heures integer;$a0$,$b0$  v_plafond numeric;
  v_heures integer;$b0$);
s:=replace(s,$a1$  v_id := p_pays || '_' || p_batiment;$a1$,$b1$  SELECT id INTO v_id FROM public.terrains_etat WHERE country=p_pays AND id=p_batiment;
  IF v_id IS NULL THEN v_id:=p_pays||'_'||p_batiment;END IF;$b1$);
s:=replace(s,$a2$  v_utiles   := floor(v_capacite * v_fraction);$a2$,$b2$  v_plafond:=CASE WHEN (v_ch->>'totalVerse')::numeric>=(v_ch->>'coutTotal')::numeric THEN (v_ch->>'dureeJours')::numeric WHEN (v_ch->>'totalVerse')::numeric>=ceil((v_ch->>'coutTotal')::numeric*.7) THEN (v_ch->>'dureeJours')::numeric*2/3 WHEN (v_ch->>'totalVerse')::numeric>=ceil((v_ch->>'coutTotal')::numeric*.35) THEN (v_ch->>'dureeJours')::numeric/3 ELSE 0 END;
  v_utiles:=floor(v_capacite*least(v_fraction,greatest(0,v_plafond-coalesce((v_ch->>'progressionJours')::numeric,0))));$b2$);
EXECUTE s;
ELSIF h IS DISTINCT FROM 'b737ee0f71bfd9265e5ca07aac3d9d90' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_travailler(text,text,text,integer)';END IF;
END;$p$;
REVOKE ALL ON FUNCTION public.chantier_travailler(text,text,text,integer) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
