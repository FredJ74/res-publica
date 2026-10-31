-- #219 : scission technique (limite MCP 12 500 caractères).
-- Appliquer ces deux fichiers consécutifs dans la même transaction.
-- #219 : étendre les rounds policiers existants aux deux groupes réels.
-- Pas de nouveau combat/jet/reçu/sentence. Les coups restent combat_coup_resoudre.
ALTER TABLE public.police_interceptions ADD COLUMN IF NOT EXISTS combattants_victimes jsonb;
ALTER TABLE public.police_interceptions ADD COLUMN IF NOT EXISTS combattants_forces jsonb;
CREATE OR REPLACE FUNCTION public.combat_membre_decrire_interne(p_pj boolean,p_id text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT jsonb_build_object('cle','pj:'||d.name,'pj_nom',d.name,'matricule','pj:'||d.name,'pa',d.pa,
  'groupeCle','pj:'||coalesce((SELECT chef FROM public.groupes_pj_adhesions WHERE membre=d.name),d.name),
  'pays',d.country,'ville',d.current_city,'buildingId',d.current_building,'roomId',d.current_room,'rueNoeudId',d.current_street,
  'stats',jsonb_build_object('VOL',coalesce((d.stats->>'VOL')::numeric,8),'PER',coalesce((d.stats->>'PER')::numeric,8)))
 FROM public.personnages_donnees d WHERE p_pj AND d.name=p_id
 UNION ALL
 SELECT jsonb_build_object('cle','pnj:'||m.id,'pnj_socle_id',m.id,
  'matricule',CASE WHEN m.famille='policier' THEN pm.matricule ELSE 'pnj:'||m.id END,
  'groupeCle',CASE WHEN m.leader_pj IS NOT NULL THEN 'pj:'||coalesce((SELECT chef FROM public.groupes_pj_adhesions WHERE membre=m.leader_pj),m.leader_pj) ELSE 'pnj:'||coalesce(m.leader_pnj_id,m.id) END,
  'pays',pe.pays,'ville',pe.ville,'buildingId',pe.building_id,'roomId',pe.room_id,'rueNoeudId',pe.rue_noeud_id,
  'pa',m.pa,'stats',jsonb_build_object(
   'VOL',CASE WHEN m.famille='soldat' THEN coalesce((sm.formation->>'combat_rapproche')::numeric,0) ELSE m.car_vol END,
   'PER',CASE WHEN m.famille='soldat' THEN public.militaire_defense_pnj('PER') ELSE m.car_per END))
 FROM public.pnj_membres m
 LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id=m.id
 LEFT JOIN public.pnj_force_publique_metier pm ON pm.pnj_id=m.id
 CROSS JOIN LATERAL public.pnj_position_effective(m.id) pe
 WHERE NOT p_pj AND m.id=p_id AND (m.famille='soldat' OR (m.car_vol IS NOT NULL AND m.car_per IS NOT NULL));
$g$;
REVOKE ALL ON FUNCTION public.combat_membre_decrire_interne(boolean,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.police_groupe_combattants_interne(p_nom text,p_rencontre text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE resultat jsonb;
BEGIN
 SELECT coalesce(jsonb_agg(public.combat_membre_decrire_interne(g.est_pj,g.identifiant) ORDER BY g.cle),'[]'::jsonb)
 INTO resultat FROM public.groupe_combattants_interne(p_nom,p_rencontre) g;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(resultat) x WHERE x='null'::jsonb) THEN
 RAISE EXCEPTION 'profil_combattant_a_raccorder';END IF;
 RETURN resultat;
END $g$;
REVOKE ALL ON FUNCTION public.police_groupe_combattants_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.police_force_combattants_interne(p_nom text,p_rencontre text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE i public.police_interceptions%ROWTYPE;a text;ident text;m public.pnj_membres%ROWTYPE;g jsonb;resultat jsonb:='[]';pe record;lieu public.personnages_donnees%ROWTYPE;
BEGIN
 SELECT * INTO i FROM public.police_interceptions WHERE personnage=p_nom AND rencontre=p_rencontre AND expires_at>now();
 IF NOT FOUND THEN RETURN resultat;END IF;
 SELECT * INTO lieu FROM public.personnages_donnees WHERE name=p_nom;
 FOR a IN SELECT jsonb_array_elements_text(coalesce(i.intervenants,'[]'::jsonb)||coalesce(i.combattants_forces,'[]'::jsonb)) LOOP
  IF a LIKE 'pj:%' THEN resultat:=resultat||public.police_groupe_combattants_interne(substring(a FROM 4),p_rencontre);CONTINUE;END IF;
  ident:=CASE WHEN a LIKE 'pnj:%' THEN substring(a FROM 5) WHEN a LIKE 'prive:%' THEN substring(a FROM 7) ELSE public.police_pnj_id(i.country,i.city,a) END;
  SELECT * INTO m FROM public.pnj_membres WHERE id=ident AND statut='actif';
  IF NOT FOUND THEN CONTINUE;END IF;
  -- Les prérogatives viennent exclusivement des intervenants déjà détecteurs.
  -- Être recruté avec eux ne transforme pas un compagnon en policier.
  IF m.leader_pj IS NOT NULL THEN
   resultat:=resultat||public.police_groupe_combattants_interne(m.leader_pj,p_rencontre);
  ELSE
   FOR ident IN SELECT id FROM public.pnj_membres WHERE statut='actif' AND pa>0
    AND (id=coalesce(m.leader_pnj_id,m.id) OR leader_pnj_id=coalesce(m.leader_pnj_id,m.id)) ORDER BY id FOR UPDATE LOOP
    SELECT * INTO pe FROM public.pnj_position_effective(ident);
    IF (pe.pays,pe.ville,pe.building_id) IS DISTINCT FROM (lieu.country,lieu.current_city,lieu.current_building)
      OR (lieu.current_building IS NOT NULL AND pe.room_id IS DISTINCT FROM lieu.current_room)
      OR (lieu.current_building IS NULL AND pe.rue_noeud_id IS DISTINCT FROM lieu.current_street) THEN CONTINUE;END IF;
    g:=public.combat_membre_decrire_interne(false,ident);
    IF g IS NULL THEN RAISE EXCEPTION 'profil_combattant_a_raccorder';END IF;
    resultat:=resultat||jsonb_build_array(g);
   END LOOP;
  END IF;
 END LOOP;
 SELECT coalesce(jsonb_agg(x ORDER BY x->>'cle'),'[]'::jsonb) INTO resultat
 FROM (SELECT DISTINCT value AS x FROM jsonb_array_elements(resultat)) t
 WHERE (x->>'pays',x->>'ville',x->>'buildingId') IS NOT DISTINCT FROM (lieu.country,lieu.current_city,lieu.current_building)
 AND CASE WHEN lieu.current_building IS NULL THEN x->>'rueNoeudId'=lieu.current_street ELSE x->>'roomId' IS NOT DISTINCT FROM lieu.current_room END;
 RETURN resultat;
END $g$;
REVOKE ALL ON FUNCTION public.police_force_combattants_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
DO $rounds$
DECLARE s text;a text;b text;debut integer;fin integer;
BEGIN
 s:=pg_get_functiondef('public.police_combat_resoudre(text,text,text,text,integer)'::regprocedure);
 IF position('-- police_rounds_mixtes_v1' IN s)>0 THEN RETURN;END IF;
 a:=' v_interception public.police_interceptions%ROWTYPE; v_receipt jsonb;';
 b:=a||chr(10)||' v_victimes jsonb; v_combattant jsonb; v_victime jsonb; v_vi integer; v_vivants integer;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'rounds_declaration_non_examinee';END IF;
 s:=replace(s,a,b);
 a:=' IF NOT EXISTS(SELECT 1 FROM public.groupe_combattants_interne(v_nom,p_rencontre) g WHERE g.est_pj AND g.identifiant=v_nom) THEN';
 b:=' IF NOT EXISTS(SELECT 1 FROM public.groupe_combattants_interne(v_nom,p_rencontre)) OR coalesce(v_pj.hp,100)<=0'
 ||' OR coalesce(v_pj.hospitalisation->>''dateFinParis'','''')>(statement_timestamp() AT TIME ZONE ''Europe/Paris'')::date::text'
 ||' OR (CASE WHEN coalesce(v_pj.hospitalisation->>''jourFin'','''')~''^[0-9]+$'' THEN (v_pj.hospitalisation->>''jourFin'')::numeric>coalesce(v_pj.day,1) ELSE false END) THEN';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'rounds_eligibilite_non_examinee';END IF;
 s:=replace(s,a,b);
 a:=' IF jsonb_array_length(v_actifs)=0 THEN';
 b:=' -- police_rounds_mixtes_v1'||chr(10)
 ||' IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE membre=v_nom) THEN RETURN jsonb_build_object(''ok'',false,''raison'',''chef_de_groupe_requis'');END IF;'
 ||chr(10)||' v_victimes:=public.police_groupe_combattants_interne(v_nom,p_rencontre);'
 ||chr(10)||' v_actifs:=public.police_force_combattants_interne(v_nom,p_rencontre);'
 ||chr(10)||' IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_victimes) x JOIN jsonb_array_elements(v_actifs) y ON x->>''cle''=y->>''cle'') THEN RETURN jsonb_build_object(''ok'',false,''raison'',''forces_meme_groupe'');END IF;'
 ||chr(10)||' IF v_interception.combattants_victimes IS NOT NULL THEN'
 ||' SELECT coalesce(jsonb_agg(x),''[]''::jsonb) INTO v_victimes FROM jsonb_array_elements(v_victimes) x WHERE v_interception.combattants_victimes ? (x->>''cle'');'
 ||' SELECT coalesce(jsonb_agg(x),''[]''::jsonb) INTO v_actifs FROM jsonb_array_elements(v_actifs) x WHERE v_interception.combattants_forces ? (x->>''cle'');END IF;'
 ||chr(10)||a;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'rounds_composition_non_examinee';END IF;
 s:=replace(s,a,b);
 a:=' IF v_pj_pa=0 THEN RETURN jsonb_build_object(''ok'',false,''raison'',''joueur_sans_pa''); END IF;';
 b:=' IF jsonb_array_length(v_victimes)=0 THEN RETURN jsonb_build_object(''ok'',false,''raison'',''joueur_sans_pa''); END IF;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'rounds_pa_groupe_non_examinee';END IF;
 s:=replace(s,a,b);
 -- Remplacer uniquement la passe des coups par la même passe pour chaque membre.
 a:=' v_cible := floor(random()*jsonb_array_length(v_actifs))::integer;';
 debut:=position(a IN s);fin:=position(' -- Persister aussi les PA des agents privés actifs après le round.' IN s);
 IF debut=0 OR fin<=debut THEN RAISE EXCEPTION 'rounds_passe_non_examinee';END IF;
 b:=$passe$
 FOR v_vi IN 0..jsonb_array_length(v_victimes)-1 LOOP
  v_victime:=v_victimes->v_vi;
  SELECT count(*) INTO v_vivants FROM jsonb_array_elements(v_actifs) x WHERE (x->>'pa')::integer>0;
  EXIT WHEN v_vivants=0;
  SELECT ord-1 INTO v_cible FROM jsonb_array_elements(v_actifs) WITH ORDINALITY t(x,ord) WHERE (x->>'pa')::integer>0 ORDER BY random() LIMIT 1;
  v_agent:=v_actifs->v_cible;
  v_jet:=public.combat_coup_resoudre((v_victime->'stats'->>'VOL')::numeric,(v_agent->'stats'->>'VOL')::numeric,(v_agent->'stats'->>'PER')::numeric,0,(v_agent->>'pa')::integer);
  v_actifs:=jsonb_set(v_actifs,ARRAY[v_cible::text,'pa'],v_jet->'pa_apres');
 END LOOP;
 FOR v_idx IN 0..jsonb_array_length(v_actifs)-1 LOOP
  v_agent:=v_actifs->v_idx;CONTINUE WHEN (v_agent->>'pa')::integer<=0;
  SELECT count(*) INTO v_vivants FROM jsonb_array_elements(v_victimes) x WHERE (x->>'pa')::integer>0;
  EXIT WHEN v_vivants=0;
  SELECT ord-1 INTO v_vi FROM jsonb_array_elements(v_victimes) WITH ORDINALITY t(x,ord) WHERE (x->>'pa')::integer>0 ORDER BY random() LIMIT 1;
  v_victime:=v_victimes->v_vi;
  v_jet:=public.combat_coup_resoudre((v_agent->'stats'->>'VOL')::numeric,(v_victime->'stats'->>'VOL')::numeric,(v_victime->'stats'->>'PER')::numeric,0,(v_victime->>'pa')::integer);
  v_victimes:=jsonb_set(v_victimes,ARRAY[v_vi::text,'pa'],v_jet->'pa_apres');
 END LOOP;
 FOR v_combattant IN SELECT value FROM jsonb_array_elements(v_victimes||v_actifs) LOOP
  IF v_combattant ? 'pj_nom' THEN UPDATE public.personnages_donnees SET pa=(v_combattant->>'pa')::integer WHERE name=v_combattant->>'pj_nom';
  ELSE UPDATE public.pnj_membres SET pa=(v_combattant->>'pa')::integer,maj_le=now() WHERE id=v_combattant->>'pnj_socle_id';END IF;
 END LOOP;
 SELECT coalesce(sum((x->>'pa')::integer),0) INTO v_vivants FROM jsonb_array_elements(v_victimes) x;
 SELECT pa INTO v_pj_pa FROM public.personnages_donnees WHERE name=v_nom;
 UPDATE public.police_interceptions SET combattants_victimes=coalesce(combattants_victimes,(SELECT jsonb_agg(x->>'cle') FROM jsonb_array_elements(v_victimes) x)),
 combattants_forces=coalesce(combattants_forces,(SELECT jsonb_agg(x->>'cle') FROM jsonb_array_elements(v_actifs) x)) WHERE personnage=v_nom AND rencontre=p_rencontre;
 PERFORM public.pnj_groupes_projeter_interne(ARRAY(SELECT x->>'pnj_socle_id' FROM jsonb_array_elements(v_victimes||v_actifs) x WHERE x ? 'pnj_socle_id'));
$passe$;
 s:=overlay(s placing b FROM debut FOR fin-debut);
 -- La police ne récupère pas le recherché tant que son groupe le défend.
 s:=replace(s,' IF v_pj_pa=0 THEN',' IF v_pj_pa=0 AND v_vivants=0 THEN');
 s:=replace(s,'''arrestation'',v_pj_pa=0','''arrestation'',v_pj_pa=0 AND v_vivants=0');
 a:='       v_agent := v_actifs->v_idx;';
 b:='       v_agent := v_agent||jsonb_build_object(''pa'',v_actifs->v_idx->''pa'');';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'rounds_registre_non_examinee';END IF;
 s:=replace(s,a,b);
 EXECUTE s;
END $rounds$;
