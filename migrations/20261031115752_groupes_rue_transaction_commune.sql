-- #219 : moteur de rue existant factorisé ; aucune activation isolée.
-- Corps Git et empreinte communiquée concordants, prévol vivant indispensable.
DO $moteur$
BEGIN
 IF to_regprocedure('public.rue_position_personnage_interne(text,text,boolean)') IS NULL THEN
  IF md5(pg_get_functiondef('public.rue_position_enregistrer(text)'::regprocedure))<>'5e819694359c4bf2f11470c7f9f95ad8' THEN
   RAISE EXCEPTION 'rue_definition_vivante_non_examinee'; END IF;
 ELSE
  IF md5(pg_get_functiondef('public.rue_position_personnage_interne(text,text,boolean)'::regprocedure))<>'03020fe045ce82c9a9e7533da696e6ee' THEN
   RAISE EXCEPTION 'rue_moteur_interne_inconnu'; END IF;
  IF md5(pg_get_functiondef('public.rue_position_enregistrer(text)'::regprocedure))<>'3b5ca4b8717525bbd1ab4b59e4da4e9c' THEN
   RAISE EXCEPTION 'rue_enveloppe_non_examinee'; END IF;
 END IF;
END $moteur$;

CREATE OR REPLACE FUNCTION public.rue_position_personnage_interne(p_nom text, p_noeud text, p_verifier boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $fn$
DECLARE v_nom text; v_pj public.personnages_donnees%ROWTYPE; v_noeud public.rue_noeuds_serveur%ROWTYPE;
 v_depart text;
BEGIN
 v_nom:=p_nom;
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom FOR UPDATE;
 IF NOT FOUND OR v_pj.est_emprisonne IS NOT NULL AND v_pj.est_emprisonne<>'null'::jsonb THEN
 RETURN jsonb_build_object('ok',false,'raison','personnage_indisponible'); END IF;
 IF EXISTS(SELECT 1 FROM public.police_interceptions WHERE personnage=v_nom AND expires_at>now()) THEN
 RETURN jsonb_build_object('ok',false,'raison','interception_en_cours'); END IF;
 -- groupes_moteur_rue_v1 : garde commune déjà utilisée par les ordres de chantier.
 IF coalesce(v_pj.hp,100)<=0
 OR coalesce(v_pj.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text
 OR (CASE WHEN coalesce(v_pj.hospitalisation->>'jourFin','')~'^[0-9]+$'
   THEN (v_pj.hospitalisation->>'jourFin')::numeric>coalesce(v_pj.day,1) ELSE false END) THEN
  RETURN jsonb_build_object('ok',false,'raison','acteur_incapacite'); END IF;
 SELECT * INTO v_noeud FROM public.rue_noeuds_serveur WHERE country=v_pj.country AND city=v_pj.current_city AND noeud=p_noeud;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','noeud_inconnu'); END IF;
 IF v_pj.current_building IS NOT NULL THEN
 IF NOT EXISTS(SELECT 1 FROM public.rue_sorties_batiments
 WHERE country=v_pj.country AND city=v_pj.current_city AND building=v_pj.current_building AND noeud=p_noeud) THEN
 RETURN jsonb_build_object('ok',false,'raison','sortie_invalide'); END IF;
 ELSIF v_pj.current_street IS NOT NULL AND v_pj.current_street<>p_noeud THEN
 IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
 WHERE country=v_pj.country AND city=v_pj.current_city AND noeud=v_pj.current_street
 AND p_noeud=ANY(voisins)) THEN RETURN jsonb_build_object('ok',false,'raison','trajet_invalide'); END IF;
 ELSIF v_pj.current_street IS NULL THEN
 v_depart:=CASE v_pj.current_city WHEN 'capitale' THEN 'luthecia-palais-presidentiel'
 WHEN 'ville_a' THEN 'psm-centre-multimodal' WHEN 'ville_b' THEN 'montrouge-vue-3' ELSE NULL END;
 IF p_noeud IS DISTINCT FROM v_depart THEN RETURN jsonb_build_object('ok',false,'raison','position_initiale_invalide'); END IF;
 END IF;
 IF p_verifier THEN RETURN jsonb_build_object('ok',true,'verifie',true); END IF;
 UPDATE public.personnages_donnees SET current_building=NULL,current_room=NULL,current_street=p_noeud,updated_at=clock_timestamp() WHERE id=v_pj.id;
 UPDATE public.police_interceptions SET expires_at=now() WHERE personnage=v_nom AND expires_at>now();
 RETURN jsonb_build_object('ok',true,'noeud',p_noeud);
END;
$fn$;
REVOKE ALL ON FUNCTION public.rue_position_personnage_interne(text,text,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.rue_position_enregistrer(p_noeud text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $groupe$
DECLARE moi text; ids text[]; pnjs text[]; apres text[]; nom text; a record; r jsonb;
 deja boolean; positions jsonb;
BEGIN
 -- groupes_rue_transaction_v1
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
  r:=public.rue_position_personnage_interne(nom,p_noeud,true);
  IF NOT coalesce((r->>'ok')::boolean,false) THEN
   RETURN r||jsonb_build_object('membre',nom); END IF;
 END LOOP;
 SELECT bool_and(current_building IS NULL AND current_street=p_noeud) INTO deja
  FROM public.personnages_donnees WHERE name=ANY(ids);
 BEGIN
  IF NOT coalesce(deja,false) THEN
   FOREACH nom IN ARRAY ids LOOP
    r:=public.rue_position_personnage_interne(nom,p_noeud,false);
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
 RETURN jsonb_build_object('ok',true,'noeud',p_noeud,'deja_present',coalesce(deja,false),
   'chef',moi,'membres',to_jsonb(ids),'positions',positions);
END $groupe$;
-- CREATE OR REPLACE préserve les droits de la porte publique ; le moteur est privé.
