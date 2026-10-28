-- #219 : un seul moteur de composition/verrouillage pour rues et intérieurs.
DO $prevol$
BEGIN
 IF md5(pg_get_functiondef('public.rue_position_enregistrer(text)'::regprocedure))<>'3b5ca4b8717525bbd1ab4b59e4da4e9c'
 AND (SELECT prosrc FROM pg_proc WHERE oid='public.rue_position_enregistrer(text)'::regprocedure)<>E'\n SELECT public.navigation_commander_interne(\'rue\',p_noeud,NULL);\n' THEN
  RAISE EXCEPTION 'navigation_porte_rue_non_examinee'; END IF;
END $prevol$;
CREATE OR REPLACE FUNCTION public.navigation_commander_interne(p_mode text,p_destination text,p_piece text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $groupe$
DECLARE moi text; ids text[]; pnjs text[]; apres text[]; nom text; a record; r jsonb;
 deja boolean; positions jsonb;
BEGIN
 -- navigation_transaction_commune_v1
 IF p_mode NOT IN ('rue','piece') OR p_mode IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','mode_invalide'); END IF;
 moi:=public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 -- Même verrou que l'adhésion/départ, avant toute lecture de composition.
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE membre=moi) THEN
  RETURN jsonb_build_object('ok',false,'raison','chef_de_groupe_requis'); END IF;
 SELECT array_agg(n ORDER BY n) INTO ids FROM (
  SELECT moi n UNION SELECT membre FROM public.groupes_pj_adhesions WHERE chef=moi) t;
 SELECT coalesce(array_agg(id ORDER BY id),'{}'::text[]) INTO pnjs
  FROM public.pnj_membres WHERE leader_pj=ANY(ids);
 -- Ordre commun avec les ordres PNJ et leurs projections institutionnelles.
 PERFORM public.pnj_groupes_verrouiller_projections_interne(pnjs);
 PERFORM name FROM public.personnages_donnees WHERE name=ANY(ids) ORDER BY name FOR UPDATE;
 SELECT coalesce(array_agg(id ORDER BY id),'{}'::text[]) INTO apres
  FROM public.pnj_membres WHERE leader_pj=ANY(ids);
 IF pnjs IS DISTINCT FROM apres THEN
  RETURN jsonb_build_object('ok',false,'raison','composition_modifiee'); END IF;
 PERFORM id FROM public.pnj_membres WHERE id=ANY(pnjs) ORDER BY id FOR UPDATE;
 SELECT country,current_city,current_building,current_room,current_street INTO a
  FROM public.personnages_donnees WHERE name=moi;
 IF (SELECT count(*) FROM public.personnages_donnees WHERE name=ANY(ids))<>cardinality(ids)
 OR EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.name=ANY(ids)
  AND (d.country IS DISTINCT FROM a.country OR d.current_city IS DISTINCT FROM a.current_city
   OR d.current_building IS DISTINCT FROM a.current_building
   OR (a.current_building IS NOT NULL AND d.current_room IS DISTINCT FROM a.current_room)
   OR (a.current_building IS NULL AND d.current_street IS DISTINCT FROM a.current_street))) THEN
  RETURN jsonb_build_object('ok',false,'raison','groupe_disperse'); END IF;
 IF EXISTS(SELECT 1 FROM public.pnj_membres WHERE id=ANY(pnjs)
  AND (statut<>'actif' OR pays IS DISTINCT FROM a.country)) THEN
  RETURN jsonb_build_object('ok',false,'raison','membre_pnj_indisponible'); END IF;
 -- Phase de validation : même moteur, aucune écriture ni dépense.
 FOREACH nom IN ARRAY ids LOOP
  r:=CASE WHEN p_mode='rue' THEN public.rue_position_personnage_interne(nom,p_destination,true) ELSE public.navigation_interieure_personnage_interne(nom,p_destination,p_piece,true) END;
  IF NOT coalesce((r->>'ok')::boolean,false) THEN
   RETURN r||jsonb_build_object('membre',nom); END IF;
 END LOOP;
 SELECT bool_and(CASE WHEN p_mode='rue' THEN current_building IS NULL AND current_street=p_destination ELSE current_building=p_destination AND current_room=p_piece END) INTO deja
  FROM public.personnages_donnees WHERE name=ANY(ids);
 BEGIN
  IF NOT coalesce(deja,false) THEN
   FOREACH nom IN ARRAY ids LOOP
    r:=CASE WHEN p_mode='rue' THEN public.rue_position_personnage_interne(nom,p_destination,false) ELSE public.navigation_interieure_personnage_interne(nom,p_destination,p_piece,false) END;
    IF NOT coalesce((r->>'ok')::boolean,false) THEN
     RAISE EXCEPTION USING ERRCODE='P2190',MESSAGE='mouvement_membre_refuse'; END IF;
   END LOOP;
   PERFORM public.pnj_groupes_projeter_interne(pnjs);
  END IF;
 EXCEPTION WHEN SQLSTATE 'P2190' THEN RETURN r||jsonb_build_object('membre',nom);
 END;
 SELECT jsonb_agg(jsonb_build_object('name',name,'country',country,'city',current_city,
   'building',current_building,'room',current_room,'street',current_street,'updated_at',updated_at) ORDER BY name)
  INTO positions FROM public.personnages_donnees WHERE name=ANY(ids);
 RETURN jsonb_build_object('ok',true,'noeud',CASE WHEN p_mode='rue' THEN p_destination END,'building',CASE WHEN p_mode='piece' THEN p_destination END,'room',p_piece,'deja_present',coalesce(deja,false),
   'chef',moi,'membres',to_jsonb(ids),'positions',positions);
END $groupe$;

REVOKE ALL ON FUNCTION public.navigation_commander_interne(text,text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.rue_position_enregistrer(p_noeud text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT public.navigation_commander_interne('rue',p_noeud,NULL);
$g$;
CREATE OR REPLACE FUNCTION public.navigation_interieure(p_batiment text,p_piece text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT public.navigation_commander_interne('piece',p_batiment,p_piece);
$g$;
REVOKE ALL ON FUNCTION public.navigation_interieure(text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.navigation_interieure(text,text) TO authenticated;
