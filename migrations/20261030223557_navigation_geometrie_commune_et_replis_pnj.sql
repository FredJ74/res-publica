-- #219 PRÉPARÉE. Même validation de géographie pour les PJ et unités PNJ autonomes.
DO $geometrie$
DECLARE s text;corps text;a integer;b integer;
BEGIN
 IF to_regprocedure('public.navigation_rue_trajet_interne(text,text,text,text,text)') IS NOT NULL THEN RETURN;END IF;
 SELECT prosrc INTO s FROM pg_proc WHERE oid='public.rue_position_personnage_interne(text,text,boolean)'::regprocedure;
 a:=position(' SELECT * INTO v_noeud FROM public.rue_noeuds_serveur' IN s);
 b:=position(' IF p_verifier THEN RETURN' IN s);
 IF a=0 OR b<=a THEN RAISE EXCEPTION 'navigation_geometrie_non_examinee';END IF;
 corps:=substring(s FROM a FOR b-a);
 EXECUTE format('CREATE FUNCTION public.navigation_rue_trajet_interne(p_pays text,p_ville text,p_batiment text,p_rue text,p_noeud text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',
 'DECLARE v_pj record;v_noeud public.rue_noeuds_serveur%ROWTYPE;v_depart text;BEGIN SELECT p_pays AS country,p_ville AS current_city,p_batiment AS current_building,p_rue AS current_street INTO v_pj;'||corps||'RETURN jsonb_build_object(''ok'',true);END;');
 s:=overlay(s placing ' v_verdict:=public.navigation_rue_trajet_interne(v_pj.country,v_pj.current_city,v_pj.current_building,v_pj.current_street,p_noeud);IF NOT coalesce((v_verdict->>''ok'')::boolean,false) THEN RETURN v_verdict;END IF;'||chr(10) FROM a FOR b-a);
 s:=replace(s,' v_depart text;',' v_depart text;v_verdict jsonb;');
 EXECUTE format('CREATE OR REPLACE FUNCTION public.rue_position_personnage_interne(p_nom text,p_noeud text,p_verifier boolean) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',s);
 -- Même lecture de sortie/gauche, identité sans aucune influence sur la géographie.
 SELECT prosrc INTO s FROM pg_proc WHERE oid='public.navigation_destination_fuite_interne(text)'::regprocedure;
 s:=replace(s,'p public.personnages_donnees%ROWTYPE','p record');
 corps:=$c$ SELECT * INTO p FROM public.personnages_donnees WHERE name=p_nom FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent');END IF;$c$;
 IF position(corps IN s)=0 THEN RAISE EXCEPTION 'navigation_destination_identite_non_examinee';END IF;
 s:=replace(s,corps,' SELECT p_pays AS country,p_ville AS current_city,p_batiment AS current_building,p_rue AS current_street,p_depuis AS current_street_from INTO p;');
 EXECUTE format('CREATE FUNCTION public.navigation_destination_fuite_position_interne(p_pays text,p_ville text,p_batiment text,p_rue text,p_depuis text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',s);
END $geometrie$;
REVOKE ALL ON FUNCTION public.navigation_rue_trajet_interne(text,text,text,text,text),public.navigation_destination_fuite_position_interne(text,text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.navigation_destination_fuite_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE p public.personnages_donnees%ROWTYPE;
BEGIN
 SELECT * INTO p FROM public.personnages_donnees WHERE name=p_nom FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent');END IF;
 RETURN public.navigation_destination_fuite_position_interne(p.country,p.current_city,p.current_building,p.current_street,p.current_street_from);
END $g$;
CREATE OR REPLACE FUNCTION public.militaire_repli_pnj_interne(p_bataille bigint,p_groupe text,p_round integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE ids text[];r record;v jsonb;destination text;positions jsonb:='{}';n integer;origine jsonb;b public.batailles%ROWTYPE;
BEGIN
 -- Appelé seulement sous verrou graphe/bataille/groupe de decrocher_groupe.
 SELECT * INTO b FROM public.batailles WHERE id=p_bataille;
 SELECT array_agg(pnj_id ORDER BY pnj_id),count(*) INTO ids,n FROM public.batailles_engagements
 WHERE bataille_id=p_bataille AND groupe_id=p_groupe AND sorti_round IS NULL;
 IF coalesce(n,0)=0 THEN RETURN 0;END IF;
 PERFORM public.pnj_groupes_verrouiller_projections_interne(ids);
 PERFORM id FROM public.pnj_membres WHERE id=ANY(ids) ORDER BY id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM public.pnj_membres WHERE id=ANY(ids) AND (statut<>'actif' OR leader_pj IS NOT NULL OR (leader_pnj_id IS NOT NULL AND NOT leader_pnj_id=ANY(ids))))
 OR (SELECT count(*) FROM public.pnj_membres WHERE id=ANY(ids))<>cardinality(ids) THEN
  RAISE EXCEPTION 'repli_composition_PNJ_invalide' USING ERRCODE='P2194',DETAIL='{"ok":false,"raison":"composition_modifiee"}';END IF;
 FOR r IN SELECT m.id,m.leader_pnj_id,pe.* FROM public.pnj_membres m CROSS JOIN LATERAL public.pnj_position_effective(m.id) pe WHERE m.id=ANY(ids) ORDER BY m.id LOOP
  IF (r.pays,r.ville,r.building_id,r.room_id) IS DISTINCT FROM (b.pays,b.ville,b.batiment,b.piece)
   OR (origine IS NOT NULL AND origine IS DISTINCT FROM jsonb_build_array(r.pays,r.ville,r.building_id,r.room_id,r.rue_noeud_id)) THEN
   RAISE EXCEPTION 'repli_PNJ_pas_sur_place' USING ERRCODE='P2194',DETAIL='{"ok":false,"raison":"groupe_disperse"}';END IF;
  origine:=jsonb_build_array(r.pays,r.ville,r.building_id,r.room_id,r.rue_noeud_id);
  v:=public.navigation_destination_fuite_position_interne(r.pays,r.ville,r.building_id,r.rue_noeud_id,NULL);
  IF NOT coalesce((v->>'ok')::boolean,false) THEN RAISE EXCEPTION 'repli_destination_PNJ_refusee' USING ERRCODE='P2194',DETAIL=v::text;END IF;
  IF destination IS NOT NULL AND destination IS DISTINCT FROM v->>'destination' THEN RAISE EXCEPTION 'repli_PNJ_disperse' USING ERRCODE='P2194',DETAIL='{"ok":false,"raison":"groupe_disperse"}';END IF;
  destination:=v->>'destination';
  v:=public.navigation_rue_trajet_interne(r.pays,r.ville,r.building_id,r.rue_noeud_id,destination);
  IF NOT coalesce((v->>'ok')::boolean,false) THEN RAISE EXCEPTION 'repli_trajet_PNJ_refuse' USING ERRCODE='P2194',DETAIL=v::text;END IF;
  IF r.leader_pnj_id IS NULL THEN positions:=positions||jsonb_build_object(r.id,jsonb_build_object('ville',r.ville,'rue_noeud_id',destination));END IF;
 END LOOP;
 -- Aucun changement d'autorité : seules les ancres sans leader sont matérialisées.
 UPDATE public.batailles_engagements SET sorti_round=p_round,etat_final='replie' WHERE bataille_id=p_bataille AND groupe_id=p_groupe AND sorti_round IS NULL;
 UPDATE public.batailles_groupes SET sorti_round=p_round,attente_depuis=NULL WHERE bataille_id=p_bataille AND groupe_id=p_groupe;
 v:=public.pnj_confrontation_refus_interne(ids);
 IF v IS NOT NULL THEN RAISE EXCEPTION 'repli_confrontation_PNJ_refusee' USING ERRCODE='P2194',DETAIL=v::text;END IF;
 PERFORM public.pnj_positions_separer_interne(positions);
 PERFORM public.pnj_groupes_projeter_interne(ids);
 RETURN n;
END $g$;
REVOKE ALL ON FUNCTION public.militaire_repli_pnj_interne(bigint,text,integer) FROM PUBLIC,anon,authenticated,service_role;
DO $repli$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_decrocher_groupe(bigint,text,integer)'::regprocedure);
 IF position('-- repli_PNJ_geometrie_commune_v1' IN s)>0 THEN RETURN;END IF;
 a:=$a$ IF g.leader IS NULL THEN
  -- Pas de faux PJ utilisé comme conducteur d'une unité autonome.
  RAISE EXCEPTION 'repli_PNJ_autonome_non_raccorde' USING ERRCODE='P2194',DETAIL='{"ok":false,"raison":"repli_PNJ_autonome_non_raccorde"}';END IF;$a$;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'repli_PNJ_adaptateur_non_examine';END IF;
 EXECUTE replace(s,a,' -- repli_PNJ_geometrie_commune_v1'||chr(10)||' IF g.leader IS NULL THEN RETURN public.militaire_repli_pnj_interne(p_bataille_id,p_groupe_id,p_round);END IF;');
END $repli$;
