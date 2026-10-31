-- Même recrutement avant/après détection, sans créer d'interception préalable.
DO $force$
DECLARE s text;a text;b text;
BEGIN
 IF to_regprocedure('public.police_force_decrire_interne(text,text,public.police_interceptions)') IS NOT NULL THEN RETURN;END IF;
 SELECT prosrc INTO s FROM pg_proc WHERE oid='public.police_force_combattants_interne(text,text)'::regprocedure;
 a:=' SELECT * INTO i FROM public.police_interceptions WHERE personnage=p_nom AND rencontre=p_rencontre AND expires_at>now();'
 ||chr(10)||' IF NOT FOUND THEN RETURN resultat;END IF;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'force_description_non_examinee';END IF;
 s:=replace(s,a,' i:=p_interception;');
 EXECUTE format('CREATE OR REPLACE FUNCTION public.police_force_decrire_interne(p_nom text,p_rencontre text,p_interception public.police_interceptions) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',s);
END $force$;
REVOKE ALL ON FUNCTION public.police_force_decrire_interne(text,text,public.police_interceptions) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.police_force_combattants_interne(p_nom text,p_rencontre text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE i public.police_interceptions%ROWTYPE;
BEGIN
 SELECT * INTO i FROM public.police_interceptions WHERE personnage=p_nom AND rencontre=p_rencontre AND expires_at>now();
 IF NOT FOUND THEN RETURN '[]'::jsonb;END IF;
 RETURN public.police_force_decrire_interne(p_nom,p_rencontre,i);
END $g$;
CREATE OR REPLACE FUNCTION public.police_forces_detection_interne(p_candidats jsonb,p_cible text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE i public.police_interceptions%ROWTYPE;x jsonb;g jsonb;res jsonb:='[]';categorie integer;
BEGIN
 SELECT country,current_city,current_building,current_room,current_street INTO i.country,i.city,i.building,i.room,i.street
 FROM public.personnages_donnees WHERE name=p_cible;
 FOR x IN SELECT value FROM jsonb_array_elements(p_candidats) LOOP
  -- Les matricules viennent des forces déjà habilitées, pas de l'écran.
  i.intervenants:=jsonb_build_array(x->>'matricule');
  g:=public.police_force_decrire_interne(p_cible,NULL,i);
  -- Un groupe ne peut simultanément défendre le recherché et l'intercepter.
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(g) f JOIN public.groupe_participants_interne(p_cible) v ON v.cle=f->>'cle') THEN CONTINUE;END IF;
  categorie:=CASE WHEN x ? 'pnj_prive_id' THEN 1 ELSE 0 END;
  SELECT coalesce(jsonb_agg(f||jsonb_build_object('categorie_force',categorie)),'[]'::jsonb) INTO g FROM jsonb_array_elements(g) f;
  res:=res||g;
 END LOOP;
 -- Une seule entrée par individu et une seule catégorie par groupe. La
 -- priorité police existante est conservée lorsqu'un policier habilité y est.
 SELECT coalesce(jsonb_agg(DISTINCT z),'[]'::jsonb) INTO res FROM (
 SELECT f||jsonb_build_object('categorie_force',min((f->>'categorie_force')::integer) OVER(PARTITION BY f->>'groupeCle')) z
 FROM jsonb_array_elements(res) f) t;
 RETURN res;
END $g$;
REVOKE ALL ON FUNCTION public.police_forces_detection_interne(jsonb,text) FROM PUBLIC,anon,authenticated,service_role;
DO $detecteur$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.police_detection_personnage_interne(text,text,text,text)'::regprocedure);
 IF position('-- police_detection_groupes_reels_v1' IN s)=0 THEN
 a:=' v_agents:=public.securite_ordre_detection_interne(v_agents,p_batiment,p_piece,p_rue);';
 b:=' -- police_detection_groupes_reels_v1'||chr(10)||' v_agents:=public.police_forces_detection_interne(v_agents,v_nom);'||chr(10)||a;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detection_groupes_corps_non_examine';END IF;
 EXECUTE replace(s,a,b);
 END IF;
 s:=pg_get_functiondef('public.securite_ordre_detection_interne(jsonb,text,text,text)'::regprocedure);
 IF position('-- detection_categorie_interne_v1' IN s)>0 THEN RETURN;END IF;
 a:='CASE WHEN x ? ''pnj_prive_id'' THEN 1 ELSE 0 END';
 b:='coalesce((x->>''categorie_force'')::integer,CASE WHEN x ? ''pnj_prive_id'' THEN 1 ELSE 0 END)';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detection_categorie_corps_non_examine';END IF;
 s:=replace(s,a,b);
 a:='CASE WHEN x ? ''pnj_prive_id'''||chr(10)||'      THEN ''prive:''';
 b:='CASE WHEN x ? ''categorie_force'' THEN ''groupe:''||(x->>''groupeCle'') WHEN x ? ''pnj_prive_id'''||chr(10)||'      THEN ''prive:''';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detection_racine_corps_non_examine';END IF;
 s:=replace(s,a,b);s:=replace(s,'WITH presents AS (','-- detection_categorie_interne_v1'||chr(10)||'WITH presents AS (');
 EXECUTE s;
END $detecteur$;
