-- Rappel universel par radio : les PNJ rejoignent leur autorité, dans la même ville.
-- Sans nouveau moteur de transport, exception à la co-présence seulement.
-- p_ancre est un PNJ stationné : ses suivants directs forment l'unité.
CREATE OR REPLACE FUNCTION public.pnj_rappeler_radio(p_ancre text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text; moi_lieu public.personnages_donnees%ROWTYPE;
 ancre public.pnj_membres%ROWTYPE; ids text[]; nb integer; radios integer;
BEGIN
 moi:=public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO moi_lieu FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 IF moi_lieu.current_city IS NULL OR
    (moi_lieu.current_building IS NULL AND moi_lieu.current_street IS NULL) THEN
   RETURN jsonb_build_object('ok',false,'raison','position_invalide'); END IF;
 IF NOT EXISTS(
   SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(moi_lieu.inventory)='array'
      THEN moi_lieu.inventory ELSE '[]'::jsonb END) o
   WHERE o->>'produitMilitaire'='radio' OR o->>'id'='radio') THEN
   RETURN jsonb_build_object('ok',false,'raison','radio_appelant_absente'); END IF;
 -- Conserver une ancre stationnaire : les subordonnés suivent par leader_pnj_id.
 SELECT * INTO ancre FROM public.pnj_membres WHERE id=p_ancre FOR UPDATE;
 IF NOT FOUND OR ancre.statut<>'actif' OR ancre.leader_pj IS NOT NULL
    OR ancre.leader_pnj_id IS NOT NULL THEN
   RETURN jsonb_build_object('ok',false,'raison','unite_non_stationnaire'); END IF;
 IF ancre.pays IS DISTINCT FROM moi_lieu.country
    OR ancre.ville IS DISTINCT FROM moi_lieu.current_city THEN
   RETURN jsonb_build_object('ok',false,'raison','radio_hors_ville'); END IF;
 SELECT array_agg(id ORDER BY id) INTO ids
 FROM public.pnj_membres WHERE id=p_ancre OR leader_pnj_id=p_ancre;
 IF ids IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','unite_absente'); END IF;
 -- Toutes les lignes sont verrouillées avant les gardes, puis aucune mutation
 -- avant l'examen de l'unité entière.
 PERFORM id FROM public.pnj_membres WHERE id=ANY(ids) ORDER BY id FOR UPDATE;
 SELECT count(*) INTO nb FROM public.pnj_membres m
 WHERE m.id=ANY(ids) AND m.statut='actif'
   AND m.pays=moi_lieu.country AND m.leader_pj IS NULL
   AND (m.id=p_ancre OR m.leader_pnj_id=p_ancre)
   AND public.pnj_peut_administrer(moi,m.id);
 IF nb<>cardinality(ids) THEN
   RETURN jsonb_build_object('ok',false,'raison','autorite_insuffisante'); END IF;
 SELECT count(*) INTO radios FROM public.pnj_possessions p
 WHERE p.pnj_id=ANY(ids)
   AND (p.objet->>'produitMilitaire'='radio' OR p.objet->>'id'='radio');
 IF radios=0 THEN RETURN jsonb_build_object('ok',false,'raison','radio_unite_absente'); END IF;
 -- Le rappel est un ordre externe ; pas de PNJ auto-décisionnaire.
 -- Dissoudre d'abord l'unité ancrée pour respecter le trigger anti-sous-hiérarchie.
 UPDATE public.pnj_membres SET leader_pnj_id=NULL,
   ville=ancre.ville, building_id=ancre.building_id, room_id=ancre.room_id,
   rue_noeud_id=ancre.rue_noeud_id
 WHERE id=ANY(ids) AND id<>p_ancre;
 UPDATE public.pnj_membres SET leader_pj=moi,leader_pnj_id=NULL,
   ville=NULL,building_id=NULL,room_id=NULL,rue_noeud_id=NULL
 WHERE id=ANY(ids);
 RETURN jsonb_build_object('ok',true,'rappeles',cardinality(ids),'ville',moi_lieu.current_city);
END $g$;
REVOKE ALL ON FUNCTION public.pnj_rappeler_radio(text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.pnj_rappeler_radio(text) TO authenticated;
