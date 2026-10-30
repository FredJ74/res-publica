-- #219 PRÉPARÉE. Une seule bataille, mêmes engagements/lecteurs/rounds/reçus.
CREATE OR REPLACE FUNCTION public.combat_ouvrir_interne(p_cible text,p_mode text,p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE moi text;p public.personnages_donnees%ROWTYPE;cible text;pnj text;b_id bigint;v jsonb;args jsonb;racine text;g record;v_camp text;gid text;terrain text;pe record;trajet jsonb;
BEGIN
 moi:=public.mon_personnage();IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie');END IF;
 IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_requise');END IF;
 args:=jsonb_build_object('operation','combat_ouvrir','cible',p_cible,'mode',p_mode);
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT verdict INTO v FROM public.navigation_requetes WHERE acteur=moi AND requete=p_requete AND arguments=args;IF FOUND THEN RETURN v;END IF;
 IF EXISTS(SELECT 1 FROM public.navigation_requetes WHERE acteur=moi AND requete=p_requete) THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
 IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE membre=moi) THEN RETURN jsonb_build_object('ok',false,'raison','chef_de_groupe_requis');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 IF p.current_building=p_cible AND p_cible LIKE 'terrain-a-batir%' THEN
  terrain:=p_cible;pnj:=public.combat_occupant_terrain_interne(terrain,moi);
 ELSE SELECT name INTO cible FROM public.personnages_donnees WHERE name=p_cible;
  IF cible IS NULL THEN SELECT id INTO pnj FROM public.pnj_membres WHERE id=p_cible AND statut='actif';END IF;
 END IF;
 IF cible=moi OR (cible IS NULL AND pnj IS NULL) THEN RETURN jsonb_build_object('ok',false,'raison','cible_non_referencee');END IF;
 IF cible IS NOT NULL AND EXISTS(SELECT 1 FROM public.groupe_participants_interne(moi) WHERE est_pj AND identifiant=cible)
 OR pnj IS NOT NULL AND EXISTS(SELECT 1 FROM public.groupe_participants_interne(moi) WHERE NOT est_pj AND identifiant=pnj) THEN RETURN jsonb_build_object('ok',false,'raison','meme_groupe');END IF;
 IF cible IS NOT NULL THEN SELECT coalesce((SELECT chef FROM public.groupes_pj_adhesions WHERE membre=cible),cible) INTO racine;END IF;
 IF pnj IS NOT NULL THEN
  IF EXISTS(SELECT 1 FROM public.pnj_membres WHERE id=pnj AND classe='gamma') THEN RETURN jsonb_build_object('ok',false,'raison','cible_protegee');END IF;
  -- Un accompagnant appartient au vrai groupe de son leader PJ, pas à un
  -- nouveau groupe d'un seul PNJ créé pour les besoins de l'agression.
  SELECT leader_pj INTO racine FROM public.pnj_membres WHERE id=pnj;
  IF racine IS NOT NULL THEN SELECT coalesce((SELECT chef FROM public.groupes_pj_adhesions WHERE membre=racine),racine) INTO racine;END IF;
  IF pnj LIKE 'occupation:%' THEN
   SELECT t.building_id INTO terrain FROM public.terrains_etat t WHERE t.country=p.country
    AND t.building_id=p.current_building AND t.data::jsonb->>'city'=p.current_city
    AND t.data::jsonb->>'pnjSocleId'=pnj AND t.data::jsonb->>'pnj' IN ('squatter_cool','squatter_agr');
   IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','occupation_obsolete');END IF;
  END IF;
 END IF;
 PERFORM public.pnj_groupes_verrouiller_projections_interne(ARRAY(SELECT identifiant FROM public.groupe_participants_interne(moi) WHERE NOT est_pj UNION SELECT identifiant FROM public.groupe_participants_interne(racine) WHERE NOT est_pj UNION SELECT pnj WHERE pnj IS NOT NULL));
 PERFORM name FROM public.personnages_donnees WHERE name IN (SELECT identifiant FROM public.groupe_participants_interne(moi) WHERE est_pj UNION SELECT identifiant FROM public.groupe_participants_interne(racine) WHERE est_pj) ORDER BY name FOR UPDATE;
 FOR g IN SELECT * FROM public.groupe_participants_interne(moi) UNION SELECT * FROM public.groupe_participants_interne(racine) LOOP
  IF (g.pays,g.ville,g.batiment,g.piece) IS DISTINCT FROM (p.country,p.current_city,p.current_building,p.current_room) OR (p.current_building IS NULL AND g.rue IS DISTINCT FROM p.current_street) THEN RETURN jsonb_build_object('ok',false,'raison','groupe_disperse');END IF;
  IF g.est_pj THEN v:=public.navigation_disponibilite_interne(g.identifiant);IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v;END IF;END IF;
 END LOOP;
 IF pnj IS NOT NULL THEN
  PERFORM id FROM public.pnj_membres WHERE id=pnj AND statut='actif' AND pa>0 FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','cible_indisponible');END IF;
  SELECT * INTO pe FROM public.pnj_position_effective(pnj);
  IF (pe.pays,pe.ville,pe.building_id,pe.room_id) IS DISTINCT FROM (p.country,p.current_city,p.current_building,p.current_room) OR (p.current_building IS NULL AND pe.rue_noeud_id IS DISTINCT FROM p.current_street) THEN RETURN jsonb_build_object('ok',false,'raison','pas_au_meme_endroit');END IF;
  v:=public.pnj_confrontation_refus_interne(ARRAY[pnj]);IF v IS NOT NULL THEN RETURN jsonb_build_object('ok',false)||v;END IF;
 END IF;
 BEGIN
  v:=public.combat_agression_preparer_interne(coalesce(cible,pnj),p_mode,10);
  IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v;END IF;
  INSERT INTO public.batailles(pays,ville,batiment,piece,camp_a,camp_b,initiative,leader_a,leader_b,contexte)
  VALUES(p.country,p.current_city,p.current_building,p.current_room,'acteur','defenseur','simultane',moi,racine,
   jsonb_build_object('type',CASE WHEN terrain IS NULL THEN 'civil' ELSE 'squatteurs' END,'phase','choix','acteur',moi,'cible',coalesce(cible,pnj),'terrain',terrain,'camp_acteur','acteur','camp_squatteurs','defenseur','requete',p_requete,'mode',p_mode)) RETURNING id INTO b_id;
  FOR g IN SELECT * FROM public.groupe_participants_interne(moi) UNION SELECT * FROM public.groupe_participants_interne(racine) LOOP
   v_camp:=CASE WHEN g.chef=moi THEN 'acteur' ELSE 'defenseur' END;gid:=v_camp||'|pj:'||g.chef;
   IF g.est_pj THEN INSERT INTO public.batailles_engagements(bataille_id,camp,personnage,groupe_id,pa_initial) SELECT b_id,v_camp,g.identifiant,gid,pa FROM public.personnages_donnees WHERE name=g.identifiant;
   ELSE INSERT INTO public.batailles_engagements(bataille_id,camp,pnj_id,matricule,groupe_id,pa_initial) SELECT b_id,v_camp,g.identifiant,g.identifiant,gid,pa FROM public.pnj_membres WHERE id=g.identifiant;END IF;
  END LOOP;
  IF pnj IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=b_id AND pnj_id=pnj) THEN INSERT INTO public.batailles_engagements(bataille_id,camp,pnj_id,matricule,groupe_id,pa_initial) SELECT b_id,'defenseur',pnj,pnj,'defenseur|pnj:'||pnj,pa FROM public.pnj_membres WHERE id=pnj;END IF;
  -- Les doctrines historiques exigent une sortie référencée. Sa géographie
  -- provient du même moteur de navigation, jamais d'une ancienne caserne.
  trajet:=public.navigation_destination_fuite_interne(moi);
  IF coalesce((trajet->>'ok')::boolean,false) THEN UPDATE public.batailles SET repli_a=trajet WHERE id=b_id;END IF;
  IF racine IS NOT NULL THEN trajet:=public.navigation_destination_fuite_interne(racine);
  ELSE trajet:=public.navigation_destination_fuite_position_interne(pe.pays,pe.ville,pe.building_id,pe.rue_noeud_id,NULL);END IF;
  IF coalesce((trajet->>'ok')::boolean,false) THEN UPDATE public.batailles SET repli_b=trajet WHERE id=b_id;END IF;
  PERFORM public.combat_bataille_completer_groupes_interne(b_id,'acteur',p.current_city,p.current_building,p.current_room);
  PERFORM public.combat_bataille_completer_groupes_interne(b_id,'defenseur',p.current_city,p.current_building,p.current_room);
  PERFORM public.militaire_bataille_groupes_constituer(b_id);
  UPDATE public.batailles SET effectif_initial_a=(SELECT count(*) FROM public.batailles_engagements WHERE bataille_id=b_id AND camp='acteur'),effectif_initial_b=(SELECT count(*) FROM public.batailles_engagements WHERE bataille_id=b_id AND camp='defenseur') WHERE id=b_id;
  v:=v||jsonb_build_object('ok',true,'bataille',b_id,'phase','choix');
  INSERT INTO public.navigation_requetes(acteur,requete,arguments,verdict) VALUES(moi,p_requete,args,v);
  RETURN v;
 END;
END $g$;
REVOKE ALL ON FUNCTION public.combat_ouvrir_interne(text,text,uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.combat_ouvrir(p_cible text,p_mode text,p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE v jsonb;
BEGIN
 BEGIN
  v:=public.combat_ouvrir_interne(p_cible,p_mode,p_requete);
  IF NOT coalesce((v->>'ok')::boolean,false) THEN RAISE EXCEPTION USING ERRCODE='P2198',MESSAGE='ouverture_refusee';END IF;
 EXCEPTION WHEN SQLSTATE 'P2198' THEN RETURN v;END;
 RETURN v;
END $g$;
REVOKE ALL ON FUNCTION public.combat_ouvrir(text,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.combat_ouvrir(text,text,uuid) TO authenticated;
