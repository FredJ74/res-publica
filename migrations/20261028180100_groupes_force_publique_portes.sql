-- #219. Après projection des miroirs et raccordement militaire, jamais isolément.
-- Même ordre de ressources pour les groupes mixtes : services, compagnies, PJ, PNJ.
CREATE OR REPLACE FUNCTION public.pnj_groupes_verrouiller_projections_interne(p_ids text[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
BEGIN
 PERFORM t.id FROM public.batiments_etat t WHERE t.id IN (
  SELECT b.id FROM public.batiments_etat b JOIN public.pnj_membres m ON m.pays=b.country
   AND m.proprietaire_perimetre=b.city||':'||b.building_id
  WHERE m.id=ANY(p_ids) AND m.proprietaire_institution IN ('police','douane')
   AND m.famille IN ('policier','douanier')) ORDER BY t.id FOR UPDATE;
 PERFORM c.id FROM public.compagnies_militaires c WHERE c.id IN (
  SELECT sm.compagnie_id FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id=sm.pnj_id
  WHERE m.id=ANY(p_ids) AND m.famille='soldat') ORDER BY c.id FOR UPDATE;
END $g$;
REVOKE ALL ON FUNCTION public.pnj_groupes_verrouiller_projections_interne(text[]) FROM PUBLIC,anon,authenticated,service_role;
DO $dispatch$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.pnj_groupes_projeter_interne(text[])'::regprocedure);
 a:=' END LOOP;';
 b:=a||chr(10)||' PERFORM public.pnj_groupes_projeter_institutions_interne(p_ids);';
 IF position(b IN s)>0 THEN RETURN; END IF;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN
  RAISE EXCEPTION 'dispatch_projection_definition_non_examinee'; END IF;
 EXECUTE replace(s,a,b);
END $dispatch$;

-- Lecture de l'autorité commune pour les interfaces/radios, pas un nouvel annuaire.
CREATE OR REPLACE FUNCTION public.pnj_unites_administrables_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text;
BEGIN
 moi:=public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 RETURN jsonb_build_object('ok',true,'membres',coalesce((
  SELECT jsonb_agg(jsonb_build_object('id',m.id,'nom',m.nom,'famille',m.famille,
   'leader_pj',m.leader_pj,'leader_pnj_id',m.leader_pnj_id,'position',to_jsonb(pe),
   'peut_administrer',public.pnj_peut_administrer(moi,m.id),'co_present',public.pnj_co_present(moi,m.id),
   'mouvement_individuel',public.pnj_axe_position_refus(ARRAY[m.id]) IS NULL
    AND public.pnj_mouvement_individuel_refus(ARRAY[m.id]) IS NULL) ORDER BY m.id)
  FROM public.pnj_membres m CROSS JOIN LATERAL public.pnj_position_effective(m.id) pe
  WHERE m.statut='actif' AND (m.leader_pj=moi OR public.pnj_peut_administrer(moi,m.id))), '[]'::jsonb));
END $g$;
REVOKE ALL ON FUNCTION public.pnj_unites_administrables_lire() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.pnj_unites_administrables_lire() TO authenticated;

-- Ne pas ouvrir l'axe sans les miroirs correspondants réellement patchés.
DO $activation$
BEGIN
 IF position('-- groupes_force_publique_position_v1' IN pg_get_functiondef('public.pnj_miroir_police(text,text,text)'::regprocedure))=0
 OR position('-- groupes_force_publique_position_v1' IN pg_get_functiondef('public.pnj_miroir_douane(text,text,text)'::regprocedure))=0 THEN
  RAISE EXCEPTION 'miroirs_force_publique_requis'; END IF;
 IF (SELECT count(*) FROM public.pnj_axes_autorite WHERE famille IN ('policier','douanier')
   AND axe='position_leader' AND autorite IN ('institution','socle'))<>2 THEN
  RAISE EXCEPTION 'axes_force_publique_non_examines'; END IF;
 UPDATE public.pnj_axes_autorite SET autorite='socle',
  note='Fred 28/10 : suivi universel ; les miroirs gardent identite/emploi, la position effective est au socle.'
  WHERE famille IN ('policier','douanier') AND axe='position_leader';
 UPDATE public.pnj_mouvement_individuel SET autorise=true,raison='groupes_universels_force_publique',
  note='Fred 28/10 : portes communes ; autorite territoriale du service conservee.'
  WHERE famille IN ('policier','douanier');
END $activation$;
