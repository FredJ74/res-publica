-- #219 : séparation au même endroit AVANT le déplacement carcéral.
-- Primitive commune extraite de pnj_quitter_groupe, jamais une porte réseau.
CREATE OR REPLACE FUNCTION public.pnj_positions_separer_interne(p_positions jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE r record;
BEGIN
 FOR r IN SELECT key AS id,value AS lieu FROM jsonb_each(p_positions) ORDER BY key LOOP
  UPDATE public.pnj_membres SET leader_pj=NULL,leader_pnj_id=NULL,
   ville=r.lieu->>'ville',building_id=r.lieu->>'building_id',
   room_id=r.lieu->>'room_id',rue_noeud_id=r.lieu->>'rue_noeud_id' WHERE id=r.id;
 END LOOP;
END $g$;
REVOKE ALL ON FUNCTION public.pnj_positions_separer_interne(jsonb) FROM PUBLIC,anon,authenticated,service_role;
DO $primitive$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.pnj_quitter_groupe(text[])'::regprocedure);
 IF position('-- separation_position_commune_v1' IN s)>0 THEN RETURN;END IF;
 a:=' FOR r IN SELECT id FROM public.pnj_membres WHERE id=ANY(ids) ORDER BY id LOOP'
 ||chr(10)||'  UPDATE public.pnj_membres SET leader_pj=NULL,leader_pnj_id=NULL,'
 ||chr(10)||'   ville=positions->r.id->>''ville'',building_id=positions->r.id->>''building_id'','
 ||chr(10)||'   room_id=positions->r.id->>''room_id'',rue_noeud_id=positions->r.id->>''rue_noeud_id'''
 ||chr(10)||'   WHERE id=r.id;'
 ||chr(10)||' END LOOP;';
 b:=' -- separation_position_commune_v1'||chr(10)||' PERFORM public.pnj_positions_separer_interne(positions);';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'separation_position_definition_non_examinee';END IF;
 EXECUTE replace(s,a,b);
END $primitive$;
CREATE OR REPLACE FUNCTION public.groupe_ecrou_separer_interne(p_nom text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE ids text[];pj_ids text[];positions jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT array_agg(g.identifiant ORDER BY g.identifiant) FILTER(WHERE g.est_pj)
 INTO pj_ids FROM public.groupe_participants_interne(p_nom) g;
 SELECT coalesce(array_agg(id ORDER BY id),'{}'::text[]) INTO ids
 FROM public.pnj_membres WHERE leader_pj=p_nom;
 PERFORM public.pnj_groupes_verrouiller_projections_interne(ids);
 PERFORM name FROM public.personnages_donnees WHERE name=ANY(pj_ids) ORDER BY name FOR UPDATE;
 PERFORM id FROM public.pnj_membres WHERE id=ANY(ids) ORDER BY id FOR UPDATE;
 SELECT coalesce(jsonb_object_agg(m.id,to_jsonb(pe)),'{}'::jsonb) INTO positions
 FROM public.pnj_membres m CROSS JOIN LATERAL public.pnj_position_effective(m.id) pe
 WHERE m.id=ANY(ids);
 PERFORM public.pnj_positions_separer_interne(positions);
 -- Si le chef est écroué, chaque PJ reste à sa position ; aucun nouveau chef
 -- ou ordre de déplacement n'est choisi arbitrairement. Un membre écroué
 -- quitte uniquement son adhésion. Identités/emplois/propriétés conservés.
 DELETE FROM public.groupes_pj_adhesions WHERE membre=p_nom OR chef=p_nom;
 PERFORM public.pnj_groupes_projeter_interne(ids);
END $g$;
REVOKE ALL ON FUNCTION public.groupe_ecrou_separer_interne(text) FROM PUBLIC,anon,authenticated,service_role;
DO $ecrou$
DECLARE s text;a text;b text;f text;
BEGIN
 s:=pg_get_functiondef('public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb)'::regprocedure);
 IF position('-- ecrou_separation_groupe_v1' IN s)=0 THEN
  a:='  -- detention_cellule_serveur_v1';
  b:='  -- ecrou_separation_groupe_v1'||chr(10)||'  PERFORM public.groupe_ecrou_separer_interne(p_nom);'||chr(10)||a;
  IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'ecrou_separation_definition_non_examinee';END IF;
  EXECUTE replace(s,a,b);
 END IF;
 -- Entrées déjà présentes : même verrou de graphe avant leurs verrous PJ.
 FOREACH f IN ARRAY ARRAY[
 'detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb)',
 'detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb)',
 'detention_transferer_qhs(text,integer,text,jsonb)',
 'douane_condamnation_executer_interne(text,text)',
 'police_reddition_resoudre(text)','police_fuite_resoudre(text)'] LOOP
  s:=pg_get_functiondef(('public.'||f)::regprocedure);
  IF position('-- ecrou_verrou_graphe_v1' IN s)>0 THEN CONTINUE;END IF;
  IF position('BEGIN' IN s)=0 THEN RAISE EXCEPTION 'ecrou_verrou_corps_non_examine: %',f;END IF;
  s:=overlay(s placing E'BEGIN\n -- ecrou_verrou_graphe_v1\n PERFORM pg_advisory_xact_lock(hashtextextended(''groupe_pj:graphe'',0));' FROM position('BEGIN' IN s) FOR 5);
  EXECUTE s;
 END LOOP;
END $ecrou$;
