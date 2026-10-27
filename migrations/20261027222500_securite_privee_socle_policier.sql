-- #135 : adaptateur commun de présence et de déploiement.
ALTER TABLE public.pnj_membres
 ADD COLUMN IF NOT EXISTS groupe_deploiement_id text;

-- Les policiers et les agents privés sont arbitrés par les mêmes RPC police_*.
CREATE OR REPLACE FUNCTION public.securite_agents_prives_presents_interne(
  p_pays text, p_ville text, p_batiment text, p_piece text, p_rue text, p_cible text
) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $hg$
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'pnj_prive_id',m.id, 'matricule','prive:'||m.id,
   'groupeCle',coalesce(m.groupe_deploiement_id,m.leader_pnj_id,m.id),
   'pa',m.pa, 'stats',jsonb_build_object('PER',m.car_per,'VOL',m.car_vol),
   'buildingId',p.building_id,'roomId',p.room_id,'rueNoeudId',coalesce(leader.current_street,p.rue_noeud_id)
 ) ORDER BY m.id),'[]'::jsonb)
 FROM public.pnj_membres m
 JOIN public.pnj_employes_metier e ON e.pnj_id=m.id
 CROSS JOIN LATERAL public.pnj_position_effective(m.id) p
 LEFT JOIN public.personnages_donnees leader ON leader.name=m.leader_pj
 WHERE e.job IN ('agent_securite','maitre_chien')
   AND m.famille='employe' AND m.statut='actif'
   AND m.proprietaire_pj IS NOT NULL AND m.proprietaire_pj IS DISTINCT FROM p_cible
   AND m.pa>0 AND m.car_per IS NOT NULL AND m.car_vol IS NOT NULL
   AND m.pays=p_pays AND p.pays=p_pays AND p.ville=p_ville
   AND ( (p_rue IS NOT NULL AND coalesce(leader.current_street,p.rue_noeud_id)=p_rue AND p.building_id IS NULL)
      OR (p_rue IS NULL AND p.building_id=p_batiment AND p.room_id=p_piece) );
$hg$;
REVOKE ALL ON FUNCTION public.securite_agents_prives_presents_interne(text,text,text,text,text,text)
 FROM PUBLIC,anon,authenticated,service_role;

-- Socle universel : identité du détachement au sol, distincte du chef qui se déplace.
-- NULL signifie agent isolé. Une même clé pour les membres d'un détachement
-- conserve l'unité de groupe après le départ de leur chef PJ.

CREATE OR REPLACE FUNCTION public.pnj_deployer_unite(
 p_pnj_ids text[], p_groupe boolean DEFAULT true
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $hg$
DECLARE v_chef text; v_lieu public.personnages_donnees%ROWTYPE;
 v_nb integer; v_ids text[]; v_cle text; v_pnj text;
BEGIN
 v_chef:=public.mon_personnage();
 IF v_chef IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 IF p_pnj_ids IS NULL OR array_length(p_pnj_ids,1) IS NULL OR array_length(p_pnj_ids,1)>50
 THEN RETURN jsonb_build_object('ok',false,'raison','effectif_invalide'); END IF;
 SELECT array_agg(DISTINCT z ORDER BY z) INTO v_ids FROM unnest(p_pnj_ids) z WHERE z IS NOT NULL AND length(z)>0;
 IF v_ids IS NULL OR cardinality(v_ids)<>cardinality(p_pnj_ids)
 THEN RETURN jsonb_build_object('ok',false,'raison','identifiants_invalides'); END IF;
 SELECT * INTO v_lieu FROM public.personnages_donnees WHERE name=v_chef FOR UPDATE;
 IF NOT FOUND OR v_lieu.current_city IS NULL OR
  (v_lieu.current_building IS NULL AND v_lieu.current_street IS NULL)
 THEN RETURN jsonb_build_object('ok',false,'raison','position_invalide'); END IF;
 SELECT count(*) INTO v_nb FROM public.pnj_membres m
 WHERE m.id=ANY(v_ids) AND m.statut='actif' AND m.leader_pj=v_chef
   AND m.leader_pnj_id IS NULL;
 IF v_nb<>cardinality(v_ids) THEN
  RETURN jsonb_build_object('ok',false,'raison','groupe_non_commande');
 END IF;
 v_cle:='deploiement-'||md5(v_chef||clock_timestamp()::text||random()::text);
 UPDATE public.pnj_membres m SET
   leader_pj=NULL,leader_pnj_id=NULL,
   groupe_deploiement_id=CASE WHEN coalesce(p_groupe,true) THEN v_cle ELSE NULL END,
   ville=v_lieu.current_city,
   building_id=v_lieu.current_building,
   room_id=v_lieu.current_room,
   rue_noeud_id=v_lieu.current_street,
   maj_le=now()
 WHERE m.id=ANY(v_ids);
 RETURN jsonb_build_object('ok',true,'deployes',v_nb,
   'ensemble',coalesce(p_groupe,true),'groupe',
   CASE WHEN coalesce(p_groupe,true) THEN v_cle ELSE NULL END);
END $hg$;
REVOKE ALL ON FUNCTION public.pnj_deployer_unite(text[],boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pnj_deployer_unite(text[],boolean) TO authenticated;

-- #135 : les groupes constitués et les patrouilles isolées sont différents.
-- Les policiers du catalogue actuel n'ont pas de chef de groupe : chaque matricule
-- constitue donc une unité isolée, sauf si un regroupement explicite est déjà indiqué (`groupe_id` militaire).
-- Les PNJ privés réutilisent leader_pnj_id (socle de déplacement/embauche).
CREATE OR REPLACE FUNCTION public.securite_ordre_detection_interne(
 p_agents jsonb,p_batiment text,p_piece text,p_rue text
) RETURNS jsonb LANGUAGE sql VOLATILE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $hg$
 WITH presents AS (
  SELECT x AS agent,
    CASE WHEN x ? 'pnj_prive_id' THEN 1 ELSE 0 END AS categorie,
    CASE WHEN x ? 'pnj_prive_id'
      THEN 'prive:'||coalesce(x->>'groupeCle',x->>'pnj_prive_id')
      ELSE 'police:'||coalesce(nullif(x->>'groupe_id',''),nullif(x->>'groupeId',''),x->>'matricule')
    END AS groupe
  FROM jsonb_array_elements(coalesce(p_agents,'[]'::jsonb)) AS x
  WHERE coalesce((x->>'pa')::integer,12)>0
    AND ((p_rue IS NOT NULL AND x->>'rueNoeudId'=p_rue)
      OR (p_rue IS NULL AND x->>'buildingId'=p_batiment AND x->>'roomId'=p_piece))
 ), groupes AS (
  SELECT categorie,groupe,count(*)::integer AS effectif,
    avg(coalesce((agent->'stats'->>'PER')::numeric,12))+(count(*)-1)
      -CASE WHEN p_rue IS NOT NULL THEN 2 ELSE 0 END AS perception,
    jsonb_agg(agent->>'matricule') AS matricules
  FROM presents GROUP BY categorie,groupe
 ), ordonnes AS (
  SELECT *,random() AS tirage FROM groupes
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'categorie',categorie,'groupe',groupe,'effectif',effectif,
   'perception',perception,'matricules',matricules
 ) ORDER BY categorie,effectif DESC,tirage),'[]'::jsonb)
 FROM ordonnes;
$hg$;
REVOKE ALL ON FUNCTION public.securite_ordre_detection_interne(jsonb,text,text,text)
 FROM PUBLIC,anon,authenticated,service_role;

-- L'identité des seuls intervenants retenus est jointe à la rencontre policière
-- existante : ni registre d'affectation ni nouveau moteur d'arrestation.
ALTER TABLE public.police_interceptions
 ADD COLUMN IF NOT EXISTS intervenants jsonb;

-- La RPC police_detection_verifier demeure seule responsable du jet et du registre.
DO $patch$
DECLARE s text; a text; b text; old text;
BEGIN
 s:=pg_get_functiondef('public.police_detection_verifier(text,text,text)'::regprocedure);
 a:='IF NOT FOUND THEN RETURN jsonb_build_object(''ok'',false,''raison'',''effectifs_absents''); END IF;';
 b:='-- L''absence de commissariat ne supprime pas les agents privés réellement présents.';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detecteur_commissariat_conflit'; END IF;
 s:=replace(s,a,b);
 a:='v_agents:=v_bat.data::jsonb->''effectifsPolice''->''policiers'';'
    ||chr(10)||' IF jsonb_typeof(v_agents) IS DISTINCT FROM ''array'' THEN RETURN jsonb_build_object(''ok'',false,''raison'',''effectifs_invalides''); END IF;';
 b:='v_agents:=CASE WHEN jsonb_typeof(v_bat.data::jsonb->''effectifsPolice''->''policiers'')=''array'' THEN v_bat.data::jsonb->''effectifsPolice''->''policiers'' ELSE ''[]''::jsonb END;'
    ||chr(10)||' v_agents:=v_agents || public.securite_agents_prives_presents_interne(v_pj.country,v_pj.current_city,p_batiment,p_piece,p_rue,v_nom);';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detecteur_effectifs_conflit'; END IF;
 s:=replace(s,a,b);
 a:=' FOR v_agent IN SELECT value FROM jsonb_array_elements(v_agents) LOOP'
   ||chr(10)||' IF ((p_rue IS NOT NULL AND v_agent->>''rueNoeudId''=p_rue)'
   ||chr(10)||' OR (p_rue IS NULL AND v_agent->>''buildingId''=p_batiment AND v_agent->>''roomId''=p_piece)) AND coalesce((v_agent->>''pa'')::integer,12)>0 THEN'
   ||chr(10)||' v_count:=v_count+1; v_per:=v_per+coalesce((v_agent->''stats''->>''PER'')::numeric,12);'
   ||chr(10)||' END IF; END LOOP;'
   ||chr(10)||' IF v_count=0 THEN RETURN jsonb_build_object(''ok'',false,''raison'',''aucun_policier_present''); END IF;'
   ||chr(10)||' v_per:=v_per/v_count+(v_count-1)-CASE WHEN p_rue IS NOT NULL THEN 2 ELSE 0 END;';
 b:=' v_count:=jsonb_array_length(public.securite_ordre_detection_interne(v_agents,p_batiment,p_piece,p_rue));'
   ||chr(10)||' IF v_count=0 THEN RETURN jsonb_build_object(''ok'',false,''raison'',''aucun_policier_present''); END IF;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detecteur_groupes_conflit'; END IF;
 s:=replace(s,a,b);
 a:=' v_chance:=greatest(10,least(90,50+5*(v_dis-v_per)));'
   ||chr(10)||' IF random()*100 < v_chance THEN RETURN jsonb_build_object(''ok'',true,''detecte'',false); END IF;'
   ||chr(10)||' v_id:=''police-''||md5(v_nom||clock_timestamp()::text||random()::text);'
   ||chr(10)||' INSERT INTO public.police_interceptions(personnage,rencontre,country,city,building,room,street)'
   ||chr(10)||' VALUES(v_nom,v_id,v_pj.country,v_pj.current_city,p_batiment,p_piece,p_rue);'
   ||chr(10)||' RETURN jsonb_build_object(''ok'',true,''detecte'',true,''rencontre'',v_id);';
 b:=' FOR v_agent IN SELECT value FROM jsonb_array_elements(public.securite_ordre_detection_interne(v_agents,p_batiment,p_piece,p_rue)) LOOP'
   ||chr(10)||'   v_per:=(v_agent->>''perception'')::numeric;'
   ||chr(10)||'   v_chance:=greatest(10,least(90,50+5*(v_dis-v_per)));'
   ||chr(10)||'   IF random()*100 < v_chance THEN CONTINUE; END IF;'
   ||chr(10)||'   v_id:=(CASE WHEN (v_agent->>''categorie'')::integer=0 THEN ''police-'' ELSE ''prive-'' END)'
   ||chr(10)||'     ||md5(v_nom||clock_timestamp()::text||random()::text);'
   ||chr(10)||'   INSERT INTO public.police_interceptions(personnage,rencontre,country,city,building,room,street,intervenants)'
   ||chr(10)||'   VALUES(v_nom,v_id,v_pj.country,v_pj.current_city,p_batiment,p_piece,p_rue,v_agent->''matricules'');'
   ||chr(10)||'   RETURN jsonb_build_object(''ok'',true,''detecte'',true,''rencontre'',v_id,''effectif'',(v_agent->>''effectif'')::integer);'
   ||chr(10)||' END LOOP;'
   ||chr(10)||' RETURN jsonb_build_object(''ok'',true,''detecte'',false);';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detecteur_jet_sequence_conflit'; END IF;
 s:=replace(s,a,b);
 a:=' SELECT rencontre INTO v_id FROM public.police_interceptions';
 b:=' SELECT rencontre,CASE WHEN jsonb_typeof(intervenants)=''array'' THEN jsonb_array_length(intervenants) ELSE 1 END'
   ||chr(10)||' INTO v_id,v_count FROM public.police_interceptions';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detecteur_reprise_effectif_conflit'; END IF;
 s:=replace(s,a,b);
 a:='IF v_id IS NOT NULL THEN RETURN jsonb_build_object(''ok'',true,''detecte'',true,''rencontre'',v_id); END IF;';
 b:='IF v_id IS NOT NULL THEN RETURN jsonb_build_object(''ok'',true,''detecte'',true,''rencontre'',v_id,''effectif'',v_count); END IF;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detecteur_reprise_reponse_conflit'; END IF;
 s:=replace(s,a,b);
 EXECUTE s;
END $patch$;

DO $patch$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.police_fuite_resoudre(text)'::regprocedure);
 a:='IF NOT FOUND THEN RETURN jsonb_build_object(''ok'',false,''raison'',''effectifs_absents''); END IF;';
 b:='-- Une force privée présente reste admissible sans policier.';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'fuite_commissariat_conflit'; END IF;
 s:=replace(s,a,b);
 a:='v_agents:=v_b.data::jsonb->''effectifsPolice''->''policiers'';'
    ||chr(10)||' IF jsonb_typeof(v_agents) IS DISTINCT FROM ''array'' THEN RETURN jsonb_build_object(''ok'',false,''raison'',''effectifs_invalides''); END IF;';
 b:='v_agents:=CASE WHEN jsonb_typeof(v_b.data::jsonb->''effectifsPolice''->''policiers'')=''array'' THEN v_b.data::jsonb->''effectifsPolice''->''policiers'' ELSE ''[]''::jsonb END;'
    ||chr(10)||' v_agents:=v_agents || public.securite_agents_prives_presents_interne(v_i.country,v_i.city,v_i.building,v_i.room,v_i.street,v_nom);'
   ||chr(10)||' IF jsonb_typeof(v_i.intervenants)=''array'' THEN'
   ||chr(10)||'   SELECT coalesce(jsonb_agg(x),''[]''::jsonb) INTO v_agents FROM jsonb_array_elements(v_agents) x'
   ||chr(10)||'   WHERE x->>''matricule'' IN (SELECT jsonb_array_elements_text(v_i.intervenants));'
   ||chr(10)||' END IF;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'fuite_effectifs_conflit'; END IF;
 EXECUTE replace(s,a,b);
END $patch$;

DO $patch$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.police_combat_resoudre(text,text,text,text,integer)'::regprocedure);
 a:='IF NOT FOUND THEN RETURN jsonb_build_object(''ok'',false,''raison'',''effectifs_absents''); END IF;';
 b:='-- Reprendre la même confrontation avec les agents présents.';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'combat_commissariat_conflit'; END IF;
 s:=replace(s,a,b);
 a:='v_agents := v_police->''policiers'';'
    ||chr(10)||' IF jsonb_typeof(v_agents) IS DISTINCT FROM ''array'' THEN'
    ||chr(10)||'   RETURN jsonb_build_object(''ok'',false,''raison'',''effectifs_invalides'');'
    ||chr(10)||' END IF;';
 b:='v_agents := CASE WHEN jsonb_typeof(v_police->''policiers'')=''array'' THEN v_police->''policiers'' ELSE ''[]''::jsonb END;'
    ||chr(10)||' v_agents := v_agents || public.securite_agents_prives_presents_interne(v_pj.country,v_pj.current_city,p_batiment,p_piece,p_rue,v_nom);'
   ||chr(10)||' IF jsonb_typeof(v_interception.intervenants)=''array'' THEN'
   ||chr(10)||'   SELECT coalesce(jsonb_agg(x),''[]''::jsonb) INTO v_agents FROM jsonb_array_elements(v_agents) x'
   ||chr(10)||'   WHERE x->>''matricule'' IN (SELECT jsonb_array_elements_text(v_interception.intervenants));'
   ||chr(10)||' END IF;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'combat_effectifs_conflit'; END IF;
 s:=replace(s,a,b);
 -- Les PNJ privés combattent avec les mêmes PA, mais leur état reste dans pnj_membres.
 a:=' -- Réécriture par matricule ; les policiers absents ne sont jamais touchés.';
 b:=' -- Persister aussi les PA des agents privés actifs après le round.'
   ||chr(10)||' FOR v_idx IN 0..jsonb_array_length(v_actifs)-1 LOOP'
   ||chr(10)||'   v_agent := v_actifs->v_idx;'
   ||chr(10)||'   IF v_agent ? ''pnj_prive_id'' THEN'
   ||chr(10)||'     UPDATE public.pnj_membres SET pa=greatest(0,(v_agent->>''pa'')::integer),maj_le=now()'
   ||chr(10)||'     WHERE id=v_agent->>''pnj_prive_id'' AND statut=''actif'';'
   ||chr(10)||'   END IF;'
   ||chr(10)||' END LOOP;'
   ||chr(10)||' -- Réécriture par matricule ; les policiers absents ne sont jamais touchés.';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'combat_pnj_pa_conflit'; END IF;
 s:=replace(s,a,b);
 a:='   v_modifie := v_modifie || jsonb_build_array(v_agent);';
 b:='   IF v_agent ? ''pnj_prive_id'' THEN'
   ||chr(10)||'     UPDATE public.pnj_membres SET pa=greatest(0,(v_agent->>''pa'')::integer),maj_le=now()'
   ||chr(10)||'     WHERE id=v_agent->>''pnj_prive_id'' AND statut=''actif'';'
   ||chr(10)||'   ELSE v_modifie := v_modifie || jsonb_build_array(v_agent); END IF;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'combat_persistance_conflit'; END IF;
 s:=replace(s,a,b);
 a:=' UPDATE public.batiments_etat SET data=v_etat,updated_at=now()'
  ||chr(10)||' WHERE id=v_bat.id;';
 b:=' IF v_bat.id IS NOT NULL THEN'
  ||chr(10)||' UPDATE public.batiments_etat SET data=v_etat,updated_at=now()'
  ||chr(10)||' WHERE id=v_bat.id; END IF;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'combat_persistance_police_conflit'; END IF;
 EXECUTE replace(s,a,b);
END $patch$;
