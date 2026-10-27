-- #135 : adaptateur de présence uniquement. Aucune affectation, aucun moteur de détection parallèle.
-- Les policiers et les agents privés sont arbitrés par les mêmes RPC police_*.
CREATE OR REPLACE FUNCTION public.securite_agents_prives_presents_interne(
  p_pays text, p_ville text, p_batiment text, p_piece text, p_rue text, p_cible text
) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $hg$
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'pnj_prive_id',m.id, 'matricule','prive:'||m.id,
   'groupeCle',coalesce(m.leader_pnj_id,m.id),
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

-- #135 : les groupes constitués et les patrouilles isolées sont différents.
-- Les policiers du catalogue actuel n'ont pas de chef de groupe : chaque matricule
-- constitue donc une unité isolée, sauf si un regroupement explicite est déjà indiqué.
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
      ELSE 'police:'||coalesce(nullif(x->>'groupeId',''),x->>'matricule')
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
 a:='v_id:=''police-''||md5(';
 b:='v_id:=(CASE WHEN EXISTS (SELECT 1 FROM jsonb_array_elements(v_agents) x WHERE NOT (x ? ''pnj_prive_id'') AND coalesce((x->>''pa'')::integer,12)>0 AND ((p_rue IS NOT NULL AND x->>''rueNoeudId''=p_rue) OR (p_rue IS NULL AND x->>''buildingId''=p_batiment AND x->>''roomId''=p_piece))) THEN ''police-'' ELSE ''prive-'' END)||md5(';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'detecteur_identifiant_conflit'; END IF;
 s:=replace(s,a,b);
 a:='''rencontre'',v_id);'; b:='''rencontre'',v_id,''effectif'',v_count);';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>2 THEN RAISE EXCEPTION 'detecteur_reponse_conflit'; END IF;
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
    ||chr(10)||' v_agents:=v_agents || public.securite_agents_prives_presents_interne(v_i.country,v_i.city,v_i.building,v_i.room,v_i.street,v_nom);';
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
    ||chr(10)||' v_agents := v_agents || public.securite_agents_prives_presents_interne(v_pj.country,v_pj.current_city,p_batiment,p_piece,p_rue,v_nom);';
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
