-- Complément de #216/#217. Préparé, NON APPLIQUÉ. Aucun propriétaire n'est modifié.
-- Les gardes de famille sont conservées ; leur bascule exige le catalogue vivant.
-- Corrige les mutations partielles et la co-présence en rue dans les portes communes.
CREATE OR REPLACE FUNCTION public.pnj_quitter_groupe(p_ids text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text; ids text[]; r record; pe record; positions jsonb:='{}'; refus jsonb;
BEGIN
 SELECT array_agg(DISTINCT x ORDER BY x) INTO ids FROM unnest(p_ids) x
  WHERE x IS NOT NULL AND x<>'';
 IF ids IS NULL OR cardinality(ids)<>cardinality(p_ids) THEN
  RETURN jsonb_build_object('ok',false,'raison','identifiants_invalides'); END IF;
 moi:=CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
 IF NOT public.est_appel_serveur() AND moi IS NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 -- Même ordre de verrous que la prise/transmission : PJ puis PNJ triés.
 IF moi IS NOT NULL THEN
  PERFORM name FROM public.personnages_donnees WHERE name=moi FOR UPDATE; END IF;
 PERFORM id FROM public.pnj_membres WHERE id=ANY(ids) ORDER BY id FOR UPDATE;
 IF (SELECT count(*) FROM public.pnj_membres WHERE id=ANY(ids) AND statut='actif')<>cardinality(ids) THEN
  RETURN jsonb_build_object('ok',false,'raison','membre_absent_ou_inactif'); END IF;
 refus:=public.pnj_axe_position_refus(ids);
 IF refus IS NOT NULL THEN RETURN jsonb_build_object('ok',false)||refus; END IF;
 refus:=public.pnj_mouvement_individuel_refus(ids);
 IF refus IS NOT NULL THEN RETURN jsonb_build_object('ok',false)||refus; END IF;
 FOR r IN SELECT id FROM public.pnj_membres WHERE id=ANY(ids) ORDER BY id LOOP
  IF moi IS NOT NULL AND NOT public.pnj_peut_conduire(moi,r.id) THEN
   RETURN jsonb_build_object('ok',false,'raison','autorite_insuffisante','pnj',r.id); END IF;
  IF moi IS NOT NULL AND NOT public.pnj_co_present(moi,r.id) THEN
   RETURN jsonb_build_object('ok',false,'raison','pas_co_presents','pnj',r.id); END IF;
  SELECT * INTO pe FROM public.pnj_position_effective(r.id);
  positions:=positions||jsonb_build_object(r.id,to_jsonb(pe));
 END LOOP;
 -- Toutes les positions sont figées AVANT la première séparation de l'ancre.
 FOR r IN SELECT id FROM public.pnj_membres WHERE id=ANY(ids) ORDER BY id LOOP
  UPDATE public.pnj_membres SET leader_pj=NULL,leader_pnj_id=NULL,
   ville=positions->r.id->>'ville',building_id=positions->r.id->>'building_id',
   room_id=positions->r.id->>'room_id',rue_noeud_id=positions->r.id->>'rue_noeud_id'
   WHERE id=r.id;
 END LOOP;
 RETURN jsonb_build_object('ok',true,'detaches',cardinality(ids),'ids',to_jsonb(ids));
END $g$;

CREATE OR REPLACE FUNCTION public.pnj_transferer(p_ids text[],p_dest text,p_dest_est_pnj boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text; ids text[]; r record; dest record; pe record; refus jsonb;
BEGIN
 SELECT array_agg(DISTINCT x ORDER BY x) INTO ids FROM unnest(p_ids) x
  WHERE x IS NOT NULL AND x<>'';
 IF ids IS NULL OR cardinality(ids)<>cardinality(p_ids) OR p_dest IS NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','identifiants_invalides'); END IF;
 moi:=CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
 IF NOT public.est_appel_serveur() AND moi IS NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 PERFORM name FROM public.personnages_donnees WHERE name=moi
  OR (NOT coalesce(p_dest_est_pnj,false) AND name=p_dest) ORDER BY name FOR UPDATE;
 PERFORM id FROM public.pnj_membres WHERE id=ANY(ids)
  OR (coalesce(p_dest_est_pnj,false) AND id=p_dest) ORDER BY id FOR UPDATE;
 IF (SELECT count(*) FROM public.pnj_membres WHERE id=ANY(ids) AND statut='actif')<>cardinality(ids) THEN
  RETURN jsonb_build_object('ok',false,'raison','membre_absent_ou_inactif'); END IF;
 refus:=public.pnj_axe_position_refus(ids);
 IF refus IS NOT NULL THEN RETURN jsonb_build_object('ok',false)||refus; END IF;
 refus:=public.pnj_mouvement_individuel_refus(ids);
 IF refus IS NOT NULL THEN RETURN jsonb_build_object('ok',false)||refus; END IF;
 IF coalesce(p_dest_est_pnj,false) THEN
  IF p_dest=ANY(ids) OR NOT EXISTS(SELECT 1 FROM public.pnj_membres
    WHERE id=p_dest AND statut='actif' AND leader_pj IS NULL AND leader_pnj_id IS NULL) THEN
   RETURN jsonb_build_object('ok',false,'raison','destinataire_invalide'); END IF;
  SELECT * INTO dest FROM public.pnj_position_effective(p_dest);
 ELSE
  SELECT country AS pays,current_city AS ville,current_building AS building_id,
   current_room AS room_id,current_street AS rue_noeud_id INTO dest
   FROM public.personnages_donnees WHERE name=p_dest;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','destinataire_introuvable'); END IF;
 END IF;
 FOR r IN SELECT id FROM public.pnj_membres WHERE id=ANY(ids) ORDER BY id LOOP
  IF moi IS NOT NULL AND NOT public.pnj_peut_administrer(moi,r.id) THEN
   RETURN jsonb_build_object('ok',false,'raison','autorite_insuffisante','pnj',r.id); END IF;
  -- L'administrateur aussi doit être présent lors d'un prêt ordinaire.
  IF moi IS NOT NULL AND NOT public.pnj_co_present(moi,r.id) THEN
   RETURN jsonb_build_object('ok',false,'raison','pas_co_presents','pnj',r.id); END IF;
  SELECT * INTO pe FROM public.pnj_position_effective(r.id);
  IF pe.pays IS DISTINCT FROM dest.pays OR pe.ville IS DISTINCT FROM dest.ville
    OR pe.building_id IS DISTINCT FROM dest.building_id
    OR (pe.building_id IS NOT NULL AND pe.room_id IS DISTINCT FROM dest.room_id)
    OR (pe.building_id IS NULL AND (pe.rue_noeud_id IS NULL
        OR pe.rue_noeud_id IS DISTINCT FROM dest.rue_noeud_id)) THEN
   RETURN jsonb_build_object('ok',false,'raison','pas_co_presents','pnj',r.id); END IF;
  -- Ne pas détacher une ancre seule en laissant une sous-hiérarchie interdite.
  IF EXISTS(SELECT 1 FROM public.pnj_membres WHERE leader_pnj_id=r.id AND NOT id=ANY(ids)) THEN
   RETURN jsonb_build_object('ok',false,'raison','unite_incomplete'); END IF;
 END LOOP;
 BEGIN
  -- La primitive commune matérialise avant de rompre les liens (trigger actif).
  refus:=public.pnj_quitter_groupe(ids);
  IF NOT coalesce((refus->>'ok')::boolean,false) THEN
   RAISE EXCEPTION USING ERRCODE='P1351',MESSAGE='separation_refusee'; END IF;
  UPDATE public.pnj_membres SET
   leader_pj=CASE WHEN coalesce(p_dest_est_pnj,false) THEN NULL ELSE p_dest END,
   leader_pnj_id=CASE WHEN coalesce(p_dest_est_pnj,false) THEN p_dest ELSE NULL END,
   ville=NULL,building_id=NULL,room_id=NULL,rue_noeud_id=NULL WHERE id=ANY(ids);
 EXCEPTION WHEN SQLSTATE 'P1351' THEN RETURN refus;
 END;
 RETURN jsonb_build_object('ok',true,'transferes',cardinality(ids),
   'nouveau_leader',p_dest,'ids',to_jsonb(ids));
END $g$;
-- CREATE OR REPLACE conserve les ACL existantes ; pas de nouvelle porte réseau.
