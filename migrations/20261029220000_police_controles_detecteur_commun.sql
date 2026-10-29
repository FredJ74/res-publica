-- #219 NON APPLIQUÉE. Étend le détecteur commun, pas de second jet navigateur.
-- Dépend de 20261029123000. Installer avec 220100 et le client correspondant.
ALTER TABLE public.police_interceptions ADD COLUMN IF NOT EXISTS nature text NOT NULL DEFAULT 'judiciaire';
ALTER TABLE public.police_interceptions ADD COLUMN IF NOT EXISTS controle jsonb;
DO $adapter$
DECLARE s text;a text;b text;
BEGIN
 IF to_regprocedure('public.police_detection_contexte_interne(text,text,text,text,boolean)') IS NOT NULL THEN RETURN;END IF;
 s:=pg_get_functiondef('public.police_detection_personnage_interne(text,text,text,text)'::regprocedure);
 a:='p_rue text, p_cible text)';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'detection_signature_non_examinee';END IF;
 s:=replace(s,a,'p_rue text, p_cible text, p_controle boolean)');
 s:=replace(s,'CREATE OR REPLACE FUNCTION public.police_detection_personnage_interne(', 'CREATE OR REPLACE FUNCTION public.police_detection_contexte_interne(');
 a:=' IF NOT EXISTS(SELECT 1 FROM public.douane_recherches_interne(v_nom) r WHERE r.country=v_pj.country) THEN';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'detection_recherche_non_examinee';END IF;
 s:=replace(s,a,replace(a,'IF NOT EXISTS','IF NOT p_controle AND NOT EXISTS'));
 a:=' SELECT * INTO v_bat FROM public.batiments_etat';
 b:=' v_agent:=public.navigation_disponibilite_interne(v_nom);'||chr(10)
 ||' IF NOT coalesce((v_agent->>''ok'')::boolean,false) AND v_agent->>''raison''<>''interception_en_cours'' THEN RETURN v_agent;END IF;'||chr(10)||a;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'detection_disponibilite_non_examinee';END IF;s:=replace(s,a,b);

 a:=' -- police_detection_groupes_reels_v1';
 b:=' IF p_controle THEN SELECT coalesce(jsonb_agg(x),''[]''::jsonb) INTO v_agents FROM jsonb_array_elements(v_agents) x WHERE NOT (x ? ''pnj_prive_id'');END IF;'||chr(10)||a;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'detection_groupes_non_examinee';END IF;s:=replace(s,a,b);
 a:=' IF v_id IS NOT NULL THEN RETURN jsonb_build_object(''ok'',true,''detecte'',true,''rencontre'',v_id,''effectif'',v_count); END IF;';
 b:=' IF v_id IS NOT NULL THEN RETURN jsonb_build_object(''ok'',true,''detecte'',true,''rencontre'',v_id,''effectif'',v_count)||coalesce((SELECT jsonb_build_object(''controle'',controle) FROM public.police_interceptions WHERE personnage=v_nom),''{}''::jsonb); END IF;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'detection_reprise_non_examinee';END IF;s:=replace(s,a,b);
 a:='   VALUES(v_nom,v_id,v_pj.country,v_pj.current_city,p_batiment,p_piece,p_rue,v_agent->''matricules'');';
 b:=a||chr(10)||$b$   IF p_controle THEN
    UPDATE public.police_interceptions SET nature='ordinaire' WHERE personnage=v_nom AND rencontre=v_id;
    -- DUP/PER et mêmes planchers/plafonds historiques, après détection effective.
    v_chance:=greatest(10,least(90,50+5*(coalesce((v_pj.stats->>'DUP')::numeric,8)-v_per)));
    IF floor(random()*100)+1<=v_chance THEN
     UPDATE public.police_interceptions SET expires_at=now(),controle='{"phase":"persuasion"}' WHERE personnage=v_nom;
    ELSIF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(v_pj.inventory,'[]'::jsonb)) x
      WHERE (coalesce((x->>'legal')::boolean,true)=false OR public.assemblee_loi_en_vigueur(v_pj.country,x,now()) IS NOT NULL)
      AND NOT public.inventaire_objet_protege(v_pj.quete_carriere,x)) THEN
     UPDATE public.police_interceptions SET expires_at=now(),controle='{"phase":"rien"}' WHERE personnage=v_nom;
    ELSE
     UPDATE public.police_interceptions SET controle='{"phase":"choix"}' WHERE personnage=v_nom;
    END IF;
    RETURN jsonb_build_object('ok',true,'detecte',true,'rencontre',v_id,'controle',
     (SELECT controle FROM public.police_interceptions WHERE personnage=v_nom));
   END IF;$b$;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'detection_insert_non_examine';END IF;s:=replace(s,a,b);
 -- Une ancienne rencontre expirée ne doit pas empêcher la prochaine rencontre.
 a:='p_rue,v_agent->''matricules'');';
 b:='p_rue,v_agent->''matricules'') ON CONFLICT(personnage) DO UPDATE SET rencontre=EXCLUDED.rencontre,country=EXCLUDED.country,city=EXCLUDED.city,building=EXCLUDED.building,room=EXCLUDED.room,street=EXCLUDED.street,intervenants=EXCLUDED.intervenants,expires_at=EXCLUDED.expires_at,fuite_tentee=false,combattants_victimes=NULL,combattants_forces=NULL,nature=''judiciaire'',controle=NULL WHERE police_interceptions.expires_at<=now();'
 ||chr(10)||'   IF NOT FOUND THEN RETURN jsonb_build_object(''ok'',false,''raison'',''autre_interception_en_cours'');END IF;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'detection_insert_reprise_non_examine';END IF;s:=replace(s,a,b);
 EXECUTE s;
END $adapter$;
REVOKE ALL ON FUNCTION public.police_detection_contexte_interne(text,text,text,text,boolean) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.police_detection_personnage_interne(p_batiment text,p_piece text,p_rue text,p_cible text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
 SELECT public.police_detection_contexte_interne(p_batiment,p_piece,p_rue,p_cible,false);
$g$;
REVOKE ALL ON FUNCTION public.police_detection_personnage_interne(text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
DO $porte$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.police_detection_verifier(text,text,text)'::regprocedure);
 IF position('-- controle_ordinaire_serveur_v1' IN s)>0 THEN RETURN;END IF;
 a:=' RETURN jsonb_build_object(''ok'',true,''detecte'',false,''raison'',''non_recherche'');';
 b:=' -- controle_ordinaire_serveur_v1'||chr(10)||' IF to_regprocedure(''public.police_controle_action_interne(text,text)'') IS NULL THEN RETURN jsonb_build_object(''ok'',false,''raison'',''installation_incomplete'');END IF;'||chr(10)||' RETURN public.police_detection_contexte_interne(p_batiment,p_piece,p_rue,moi,true);';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'detection_porte_non_examinee';END IF;EXECUTE replace(s,a,b);
END $porte$;
