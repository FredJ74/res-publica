-- #379 : le même forum, ses sujets/messages et ses déclencheurs existants.
-- Adaptateur privé appelé par jauges_ordre_executer : publication + POP + reçu
-- sont dans la même transaction. Aucun titre, contenu ou auteur n'est exporté.
CREATE OR REPLACE FUNCTION public.forum_publication_jauges_interne(p_acteur text,p_requete uuid,p_message jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp
AS $function$
DECLARE a public.personnages_donnees; t public.forum_topics; o jsonb;
 f text; auteur text; orga text; nom_reel text; sujet text; post_id text; temps text;
 nouveau boolean; cree text; secret boolean; icone text; membre boolean;
BEGIN
 IF p_acteur IS DISTINCT FROM public.mon_personnage() OR p_requete IS NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF jsonb_typeof(p_message) IS DISTINCT FROM 'object' OR
    p_message-ARRAY['forum','topic','titre','contenu','blocs','mise_en_page','organisation','secret','icone']<>'{}'::jsonb THEN
  RETURN jsonb_build_object('ok',false,'raison','champs_interdits');END IF;
 SELECT * INTO a FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
 IF nullif(btrim(p_message->>'contenu'),'') IS NULL OR
    jsonb_typeof(coalesce(p_message->'blocs','[]'::jsonb))<>'array' THEN
  RETURN jsonb_build_object('ok',false,'raison','publication_vide');END IF;
 nouveau:=nullif(p_message->>'topic','') IS NULL;
 IF nouveau THEN
  f:=p_message->>'forum';sujet:='topic-'||p_requete::text;
  IF nullif(btrim(p_message->>'titre'),'')IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','titre_vide');END IF;
 ELSE
  SELECT * INTO t FROM public.forum_topics WHERE id=p_message->>'topic' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','sujet_introuvable');END IF;
  f:=t.forum_id;sujet:=t.id;
  IF f NOT IN('international','sport')AND t.country IS DISTINCT FROM a.country THEN
   RETURN jsonb_build_object('ok',false,'raison','territoire_invalide');END IF;
 END IF;
 -- Les mêmes restrictions que FORUMS_BASE/getForums/canAccessForum et les éditeurs.
 -- Presse et Présidence : lecture et réponses publiques, création réservée.
 IF f IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','forum_inconnu');END IF;
 IF f='presidence'AND nouveau AND a.poste->>'id' IS DISTINCT FROM 'president' THEN
  RETURN jsonb_build_object('ok',false,'raison','poste_requis');END IF;
 IF f='presse'AND nouveau AND a.career IS DISTINCT FROM 'press' THEN
  RETURN jsonb_build_object('ok',false,'raison','carriere_requise');END IF;
 IF f='gouvernement'AND NOT(coalesce(a.poste->>'id','')=ANY(ARRAY['president','pm','min_int','min_fin','min_just','min_def','min_info','min_ae']))THEN
  RETURN jsonb_build_object('ok',false,'raison','poste_requis');END IF;
 IF left(f,4)='org_' THEN
  SELECT CASE WHEN data IS JSON OBJECT THEN data::jsonb ELSE '{}'::jsonb END INTO o FROM public.organisations WHERE id=substr(f,5);
  SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(o->'membres','[]'::jsonb))m WHERE m->>'nom'=a.name)INTO membre;
  IF NOT membre THEN RETURN jsonb_build_object('ok',false,'raison','membre_requis');END IF;
 ELSIF f NOT IN('national','presidence','assemblee','gouvernement','presse','international','sport',
               'local_'||a.current_city,'tribunal_'||a.current_city)THEN
  RETURN jsonb_build_object('ok',false,'raison','forum_inconnu');END IF;
 auteur:=a.name;orga:=nullif(p_message->>'organisation','');
 IF orga IS NOT NULL THEN
  SELECT CASE WHEN data IS JSON OBJECT THEN data::jsonb ELSE '{}'::jsonb END INTO o FROM public.organisations WHERE id=orga;
  IF o->>'chef' IS DISTINCT FROM a.name THEN RETURN jsonb_build_object('ok',false,'raison','chef_organisation_requis');END IF;
  IF coalesce((o->>'dissoute')::boolean,false)THEN RETURN jsonb_build_object('ok',false,'raison','organisation_dissoute');END IF;
  auteur:=o->>'nom';nom_reel:=a.name;
  IF nullif(auteur,'')IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','organisation_invalide');END IF;
 END IF;
 secret:=orga IS NOT NULL AND NOT coalesce((o->>'visible')::boolean,true);icone:=CASE WHEN orga IS NOT NULL THEN p_message->>'icone' END;
 temps:=to_char(now()AT TIME ZONE'Europe/Paris','DD/MM/YYYY HH24:MI');post_id:='post-'||p_requete::text;
 IF nouveau THEN
  INSERT INTO public.forum_topics(id,forum_id,title,author,country,time,views,replies,last_post_author,last_post_time,
    author_is_org,author_secret,author_real,author_org_id,author_org_icon)
  VALUES(sujet,f,btrim(p_message->>'titre'),auteur,a.country,temps,1,0,auteur,temps,orga IS NOT NULL,secret,nom_reel,orga,icone)RETURNING id INTO cree;
  IF cree IS NULL THEN RAISE EXCEPTION 'forum_ecriture_refusee' USING ERRCODE='42501';END IF;
 END IF;
 cree:=NULL;
 INSERT INTO public.forum_posts(id,topic_id,author,content,time,author_is_org,author_secret,content_blocks,content_layout,author_real,author_org_id,author_org_icon)
 VALUES(post_id,sujet,auteur,p_message->>'contenu',temps,orga IS NOT NULL,secret,coalesce(p_message->'blocs','[]'::jsonb),p_message->'mise_en_page',nom_reel,orga,icone)RETURNING id INTO cree;
 IF cree IS NULL THEN RAISE EXCEPTION 'forum_ecriture_refusee' USING ERRCODE='42501';END IF;
 UPDATE public.forum_topics SET replies=(SELECT greatest(0,count(*)-1)FROM public.forum_posts WHERE topic_id=sujet),last_post_author=auteur,last_post_time=temps WHERE id=sujet;
 RETURN jsonb_build_object('ok',true,'topic',sujet,'post',post_id,'temps',temps,'gain_pop',CASE WHEN nouveau THEN 2 ELSE 1 END);
EXCEPTION WHEN insufficient_privilege OR check_violation OR foreign_key_violation OR unique_violation THEN
 -- Le bloc entier est annulé : aucun sujet orphelin, message sans bonus, ni bonus sans message.
 RETURN jsonb_build_object('ok',false,'raison','publication_refusee');
END;$function$;
REVOKE ALL ON FUNCTION public.forum_publication_jauges_interne(text,uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
