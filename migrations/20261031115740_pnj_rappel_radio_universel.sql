-- Préparation #217 révisée : une unité détachée, mêmes radios/autorités du socle.
-- Aucun équipement créé. Pas de transport parallèle ni mutation de propriétaire.
CREATE OR REPLACE FUNCTION public.pnj_rappeler_radio(p_ancre text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text; lieu public.personnages_donnees%ROWTYPE;
 ancre public.pnj_membres%ROWTYPE; ids text[]; apres text[]; r record; pe record;
 refus jsonb; radios integer;
BEGIN
 moi:=public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO lieu FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 IF NOT FOUND OR lieu.country IS NULL OR lieu.current_city IS NULL OR
    (lieu.current_building IS NULL AND lieu.current_street IS NULL) THEN
   RETURN jsonb_build_object('ok',false,'raison','position_invalide'); END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(
    CASE WHEN jsonb_typeof(lieu.inventory)='array' THEN lieu.inventory ELSE '[]'::jsonb END) o
    WHERE (o->>'produitMilitaire'='radio' OR o->>'id'='radio')
      AND coalesce(o->>'qty','1') ~ '^[1-9][0-9]*$') THEN
   RETURN jsonb_build_object('ok',false,'raison','radio_appelant_absente'); END IF;
 -- Découvrir puis verrouiller TOUTE l'unité en ordre stable, avant les gardes.
 SELECT array_agg(id ORDER BY id) INTO ids FROM public.pnj_membres
  WHERE id=p_ancre OR leader_pnj_id=p_ancre;
 IF ids IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','unite_absente'); END IF;
 PERFORM id FROM public.pnj_membres WHERE id=ANY(ids) ORDER BY id FOR UPDATE;
 SELECT * INTO ancre FROM public.pnj_membres WHERE id=p_ancre;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','unite_absente'); END IF;
 SELECT array_agg(id ORDER BY id) INTO apres FROM public.pnj_membres
  WHERE id=p_ancre OR leader_pnj_id=p_ancre;
 IF ids IS DISTINCT FROM apres THEN
  RETURN jsonb_build_object('ok',false,'raison','unite_modifiee'); END IF;
 -- Un rappel dont la réponse a été perdue ne déplace pas une deuxième fois.
 -- On ne prétend pas retrouver les anciens membres depuis un lien dissous.
 IF ancre.leader_pj=moi AND ancre.leader_pnj_id IS NULL AND ancre.statut='actif'
    AND public.pnj_peut_administrer(moi,p_ancre) THEN
  RETURN jsonb_build_object('ok',true,'deja_present',true,'ville',lieu.current_city); END IF;
 IF ancre.statut<>'actif' OR ancre.leader_pj IS NOT NULL
    OR ancre.leader_pnj_id IS NOT NULL THEN
   RETURN jsonb_build_object('ok',false,'raison','unite_non_stationnaire'); END IF;
 refus:=public.pnj_axe_position_refus(ids);
 IF refus IS NOT NULL THEN RETURN jsonb_build_object('ok',false)||refus; END IF;
 refus:=public.pnj_mouvement_individuel_refus(ids);
 IF refus IS NOT NULL THEN RETURN jsonb_build_object('ok',false)||refus; END IF;
 FOR r IN SELECT * FROM public.pnj_membres WHERE id=ANY(ids) ORDER BY id LOOP
  IF r.statut<>'actif' OR r.leader_pj IS NOT NULL
     OR NOT public.pnj_peut_administrer(moi,r.id) THEN
   RETURN jsonb_build_object('ok',false,'raison','autorite_insuffisante'); END IF;
  SELECT * INTO pe FROM public.pnj_position_effective(r.id);
  IF pe.pays IS DISTINCT FROM lieu.country OR pe.ville IS DISTINCT FROM lieu.current_city THEN
   RETURN jsonb_build_object('ok',false,'raison','radio_hors_ville'); END IF;
 END LOOP;
 -- Les possessions sont les vrais équipements ; verrouiller avant de les lire.
 PERFORM id FROM public.pnj_possessions WHERE pnj_id=ANY(ids) ORDER BY id FOR UPDATE;
 SELECT count(*) INTO radios FROM public.pnj_possessions p WHERE p.pnj_id=ANY(ids)
   AND (p.objet->>'produitMilitaire'='radio' OR p.objet->>'id'='radio')
   AND coalesce(p.objet->>'qty','1') ~ '^[1-9][0-9]*$';
 IF radios=0 THEN RETURN jsonb_build_object('ok',false,'raison','radio_unite_absente'); END IF;
 -- D'abord matérialiser les membres, puis l'ancre : la contrainte commune de
 -- hiérarchie reste active. L'unité entière rejoint le MÊME chef opérationnel.
 UPDATE public.pnj_membres SET leader_pnj_id=NULL,
   ville=ancre.ville,building_id=ancre.building_id,room_id=ancre.room_id,
   rue_noeud_id=ancre.rue_noeud_id WHERE id=ANY(ids) AND id<>p_ancre;
 UPDATE public.pnj_membres SET leader_pj=moi,leader_pnj_id=NULL,
   ville=NULL,building_id=NULL,room_id=NULL,rue_noeud_id=NULL WHERE id=ANY(ids);
 RETURN jsonb_build_object('ok',true,'rappeles',cardinality(ids),'ids',to_jsonb(ids),
   'ville',lieu.current_city);
END $g$;
REVOKE ALL ON FUNCTION public.pnj_rappeler_radio(text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.pnj_rappeler_radio(text) TO authenticated;
