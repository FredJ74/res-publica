-- #379, lot présidence et gouvernement (Claude, 03/11/2026) : POP/INF décidées par le serveur
-- pour le décret inutile, le référendum, le jour de deuil, la censure d'un média, l'intervention
-- policière, le banquet diplomatique, la réception d'État, la déclaration de guerre et les trois
-- prises de parole de tribune (conférence, propagande, démenti).
-- Formules d'origine de l'écran conservées à l'identique ; aucune règle de jeu nouvelle.
-- Dépend de 20261103203000 (dispatcher des jauges). Ne pas appliquer avant la certification #379.

-- 0. Prévol : n'accepter que les corps examinés, ou ce lot déjà installé (rejeu permis).
DO $prevol$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.jauges_ordre_executer(text,uuid,jsonb)')
     AND (md5(prosrc)='069eb3092862c27a6bf5fec7545097c2' OR position('hg379_presidence_v1' in prosrc)>0)) THEN
  RAISE EXCEPTION '379_presidence_dispatcher_divergent'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.indice_diplomatique_ordre(text,integer,integer)')
     AND (md5(prosrc)='e29ed7ed6993904f8e244ec869907d8e' OR position('jauges_effet_appliquer_interne' in prosrc)>0)) THEN
  RAISE EXCEPTION '379_presidence_indice_diplomatique_divergent'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.guerre_declarer(text)')
     AND (md5(prosrc)='5e3bf9d4145d7d7b6d2c7c3192dcb2c1' OR position('jauges_effet_appliquer_interne' in prosrc)>0)) THEN
  RAISE EXCEPTION '379_presidence_guerre_divergent'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.communication_officielle_publier(text,text,text,integer,integer,text,text,jsonb,boolean)')
     AND (md5(prosrc)='366b7a2c66de40074af6113bc429855f' OR position('jauges_effet_appliquer_interne' in prosrc)>0)) THEN
  RAISE EXCEPTION '379_presidence_communication_divergent'; END IF;
END $prevol$;

-- 1. Une seule écriture de jauges pour les commandes serveur déjà existantes.
--    Jamais exposée aux navigateurs : seuls les corps SECURITY DEFINER l'appellent.
CREATE OR REPLACE FUNCTION public.jauges_effet_appliquer_interne(p_nom text,p_pop integer,p_inf integer,p_moral integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $f$
DECLARE r public.personnages_donnees; res jsonb;
BEGIN
 SELECT * INTO r FROM public.personnages_donnees WHERE name=p_nom FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('jauges',NULL); END IF;
 res:=coalesce(r.resources,'{}'::jsonb)-'popBase'-'infBase';
 IF coalesce(p_pop,0)<>0 THEN res:=jsonb_set(res,'{pop}',to_jsonb(least(100,greatest(0,coalesce((res->>'pop')::numeric,0)+p_pop))));END IF;
 IF coalesce(p_inf,0)<>0 THEN res:=jsonb_set(res,'{inf}',to_jsonb(least(100,greatest(0,coalesce((res->>'inf')::numeric,0)+p_inf))));END IF;
 UPDATE public.personnages_donnees SET resources=res,
   moral=CASE WHEN coalesce(p_moral,0)<>0 THEN least(100,greatest(0,coalesce(moral,50)+p_moral)) ELSE moral END
  WHERE name=p_nom RETURNING * INTO r;
 RETURN jsonb_build_object('jauges',jsonb_build_object('pop',r.resources->'pop','inf',r.resources->'inf','moral',r.moral,
   'gain_pop',coalesce(p_pop,0),'gain_inf',coalesce(p_inf,0),'gain_moral',coalesce(p_moral,0)));
END;$f$;
REVOKE ALL ON FUNCTION public.jauges_effet_appliquer_interne(text,integer,integer,integer) FROM PUBLIC,anon,authenticated,service_role;

-- 2. Coûts des trois ordres présidentiels jamais déclarés (menus du Palais : 1, 3 et 1 PA).
INSERT INTO public.ordres_couts(fn,pa,cost) VALUES ('decret_inutile',1,0),('decret_referendum',3,0),('jour_deuil',1,0)
ON CONFLICT DO NOTHING;

-- 3. Nouvelles branches du dispatcher, insérées avant la branche de refus.
DO $patch$
DECLARE v_def text; v_ancre text; v_ajout text;
BEGIN
 v_def:=pg_get_functiondef('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure);
 IF position('hg379_presidence_v1' in v_def)>0 THEN RETURN; END IF;
 v_ancre:=E'  ELSE RETURN jsonb_build_object(''ok'',false,''raison'',''ordre_non_raccorde'');\n  END CASE;';
 v_ajout:=$a$
  -- hg379_presidence_v1 : formules d'origine de l'écran, tirées ici.
  WHEN 'decret_inutile' THEN
    IF p_contexte<>'{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    IF a.poste->>'id' IS DISTINCT FROM 'president' THEN RETURN jsonb_build_object('ok',false,'raison','poste_requis');END IF;
    pa_cout:=1; pop_gain:=floor(random()*20)::integer-5; inf_gain:=floor(random()*10)::integer+2;
  WHEN 'message_presidentiel' THEN
    IF p_contexte NOT IN('{"type":"referendum"}'::jsonb,'{"type":"deuil"}'::jsonb) THEN
      RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    IF a.poste->>'id' IS DISTINCT FROM 'president' THEN RETURN jsonb_build_object('ok',false,'raison','poste_requis');END IF;
    paiement:=public.payer_ordre(a.name,CASE WHEN p_contexte->>'type'='referendum' THEN 'decret_referendum' ELSE 'jour_deuil' END,
      CASE WHEN p_contexte->>'type'='referendum' THEN 3 ELSE 1 END,0);
    IF coalesce((paiement->>'ok')::boolean,false) IS NOT TRUE THEN RETURN paiement;END IF;
    pa_cout:=NULL;
    pop_gain:=CASE WHEN p_contexte->>'type'='referendum' THEN 10 ELSE 15 END;
    inf_gain:=CASE WHEN p_contexte->>'type'='referendum' THEN 8 ELSE 0 END;
  WHEN 'censurer_media' THEN
    IF p_contexte-ARRAY['media']<>'{}'::jsonb OR jsonb_typeof(p_contexte->'media') IS DISTINCT FROM 'string'
       OR nullif(btrim(p_contexte->>'media'),'') IS NULL THEN
      RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    IF a.poste->>'id' IS DISTINCT FROM 'min_info' THEN RETURN jsonb_build_object('ok',false,'raison','poste_requis');END IF;
    pa_cout:=2; v_detecte:=random()<0.30;
    pop_gain:=CASE WHEN v_detecte THEN -20 ELSE 0 END;
    publication:=jsonb_build_object('scandale',v_detecte,'media',btrim(p_contexte->>'media'));
  WHEN 'mobiliser_police' THEN
    IF p_contexte NOT IN('{"option":"encadrer"}'::jsonb,'{"option":"quartier"}'::jsonb,'{"option":"reprimer"}'::jsonb) THEN
      RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    IF a.poste->>'id' IS DISTINCT FROM 'commissaire' THEN RETURN jsonb_build_object('ok',false,'raison','poste_requis');END IF;
    pa_cout:=2;
    pop_gain:=CASE p_contexte->>'option' WHEN 'encadrer' THEN -2 WHEN 'quartier' THEN 0 ELSE -15 END;
    publication:=jsonb_build_object('option',p_contexte->>'option',
      'isn',CASE p_contexte->>'option' WHEN 'encadrer' THEN 3 WHEN 'quartier' THEN 5 ELSE 10 END);
$a$;
 IF (length(v_def)-length(replace(v_def,v_ancre,'')))/length(v_ancre)<>1 THEN RAISE EXCEPTION '379_presidence_ancre_dispatcher'; END IF;
 EXECUTE replace(v_def,v_ancre,v_ajout||v_ancre);
END $patch$;

-- 4. Banquet et réception : l'issue était déjà tirée ici ; les jauges suivent dans la même transaction.
DO $patch$
DECLARE v_def text; v_ancre text;
BEGIN
 v_def:=pg_get_functiondef('public.indice_diplomatique_ordre(text,integer,integer)'::regprocedure);
 IF position('jauges_effet_appliquer_interne' in v_def)>0 THEN RETURN; END IF;
 v_ancre:=E'  RETURN jsonb_build_object(''ok'', true, ''reussi'', v_reussi,';
 IF (length(v_def)-length(replace(v_def,v_ancre,'')))/length(v_ancre)<>1 THEN RAISE EXCEPTION '379_presidence_ancre_diplomatie'; END IF;
 EXECUTE replace(v_def,v_ancre,
  E'  RETURN public.jauges_effet_appliquer_interne(v_moi,\n'
  ||E'    CASE p_fn WHEN ''banquet_diplo'' THEN CASE WHEN v_venus=p_invites THEN 15 WHEN v_venus>0 THEN 5 ELSE -25 END\n'
  ||E'              WHEN ''reception_etat'' THEN CASE WHEN v_reussi THEN 10 ELSE -30 END ELSE 0 END,\n'
  ||E'    CASE p_fn WHEN ''banquet_diplo'' THEN CASE WHEN v_venus=p_invites THEN 12 WHEN v_venus>0 THEN 5 ELSE -20 END\n'
  ||E'              WHEN ''reception_etat'' THEN CASE WHEN v_reussi THEN 8 ELSE -30 END ELSE 0 END,\n'
  ||E'    CASE p_fn WHEN ''banquet_diplo'' THEN CASE WHEN v_venus=p_invites THEN 5 WHEN v_venus>0 THEN 0 ELSE -10 END\n'
  ||E'              WHEN ''reception_etat'' THEN CASE WHEN v_reussi THEN 5 ELSE -10 END ELSE 0 END)\n'
  ||E'    || jsonb_build_object(''ok'', true, ''reussi'', v_reussi,');
END $patch$;

-- 5. Déclaration de guerre : -20 POP, +10 INF au président, dans la transaction de la guerre.
DO $patch$
DECLARE v_def text; v_ancre text;
BEGIN
 v_def:=pg_get_functiondef('public.guerre_declarer(text)'::regprocedure);
 IF position('jauges_effet_appliquer_interne' in v_def)>0 THEN RETURN; END IF;
 v_ancre:=E'  RETURN jsonb_build_object(''ok'', true, ''id'', v_id,';
 IF (length(v_def)-length(replace(v_def,v_ancre,'')))/length(v_ancre)<>1 THEN RAISE EXCEPTION '379_presidence_ancre_guerre'; END IF;
 EXECUTE replace(v_def,v_ancre,E'  RETURN public.jauges_effet_appliquer_interne(v_moi,-20,10)\n    || jsonb_build_object(''ok'', true, ''id'', v_id,');
END $patch$;

-- 6. Tribune : conférence +15 POP +10 INF, propagande +20 POP, démenti +8 POP +5 INF.
DO $patch$
DECLARE v_def text; v_ancre text;
BEGIN
 v_def:=pg_get_functiondef('public.communication_officielle_publier(text,text,text,integer,integer,text,text,jsonb,boolean)'::regprocedure);
 IF position('jauges_effet_appliquer_interne' in v_def)>0 THEN RETURN; END IF;
 v_ancre:=E'  RETURN jsonb_build_object(''ok'', true, ''topic'', v_topic,';
 IF (length(v_def)-length(replace(v_def,v_ancre,'')))/length(v_ancre)<>1 THEN RAISE EXCEPTION '379_presidence_ancre_tribune'; END IF;
 EXECUTE replace(v_def,v_ancre,
  E'  RETURN public.jauges_effet_appliquer_interne(v_moi,\n'
  ||E'    CASE p_fn WHEN ''conference_presse'' THEN 15 WHEN ''propagande_etat'' THEN 20 WHEN ''dementi'' THEN 8 ELSE 0 END,\n'
  ||E'    CASE p_fn WHEN ''conference_presse'' THEN 10 WHEN ''dementi'' THEN 5 ELSE 0 END)\n'
  ||E'    || jsonb_build_object(''ok'', true, ''topic'', v_topic,');
END $patch$;

NOTIFY pgrst,'reload schema';
