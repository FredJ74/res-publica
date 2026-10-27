-- PREPAREE #135. Aucun agent cree, aucun joueur deplace. Prevol vivant requis.
BEGIN;
DO $garde$ DECLARE cible text;role_client text;BEGIN
 IF to_regclass('public.chantier_vigiles_affectations') IS NOT NULL
 AND obj_description(to_regclass('public.chantier_vigiles_affectations'),'pg_class') IS DISTINCT FROM 'HG chantier vigiles v1' THEN
  RAISE EXCEPTION 'chantier_affectations_schema_inconnu';END IF;
 FOREACH cible IN ARRAY ARRAY['terrains_etat','pnj_membres','pnj_employes_metier'] LOOP
  FOREACH role_client IN ARRAY ARRAY['anon','authenticated'] LOOP
   IF has_table_privilege(role_client,'public.'||cible,'INSERT,DELETE,TRUNCATE') OR EXISTS(
    SELECT 1 FROM pg_attribute WHERE attrelid=('public.'||cible)::regclass AND attnum>0 AND NOT attisdropped
    AND has_column_privilege(role_client,attrelid,attname,'UPDATE')) THEN
    RAISE EXCEPTION 'chantier_vigiles_sources_modifiables: % %',cible,role_client;END IF;
  END LOOP;
 END LOOP;
END;$garde$;
CREATE TABLE IF NOT EXISTS public.chantier_vigiles_affectations (
 pnj_id text PRIMARY KEY REFERENCES public.pnj_membres(id) ON DELETE CASCADE,
 terrain_id text NOT NULL REFERENCES public.terrains_etat(id) ON DELETE CASCADE,
 employeur_pj text NOT NULL, maitre_ouvrage text NOT NULL,
 affecte_le timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.chantier_vigiles_affectations IS 'HG chantier vigiles v1';
CREATE INDEX IF NOT EXISTS chantier_vigiles_par_terrain ON public.chantier_vigiles_affectations(terrain_id);
ALTER TABLE public.chantier_vigiles_affectations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.chantier_vigiles_affectations FROM PUBLIC,anon,authenticated,service_role;

-- Le socle PNJ est l'unique autorite de position, metier, statut et employeur.
-- L'affectation ne remplace PAS pnj_position_effective ; elle lui ajoute la mission.
CREATE OR REPLACE FUNCTION public.chantier_vigiles_presents_interne(p_terrain text)
RETURNS TABLE(pnj_id text,nom text,metier text) LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=public,pg_temp AS $f$
 SELECT m.id,m.nom,e.job
 FROM public.chantier_vigiles_affectations a
 JOIN public.terrains_etat t ON t.id=a.terrain_id
 JOIN public.pnj_membres m ON m.id=a.pnj_id
 JOIN public.pnj_employes_metier e ON e.pnj_id=m.id
 JOIN public.pnj_candidats_catalogue c ON c.candidat_id=e.candidat_id
 JOIN public.pnj_employeurs emp ON emp.employeur_id=c.employeur_id
 CROSS JOIN LATERAL public.pnj_position_effective(m.id) pos
 WHERE t.id=p_terrain AND a.maitre_ouvrage=t.data::jsonb->>'proprietaire'
 AND m.proprietaire_pj=a.employeur_pj AND m.famille='employe'
 AND m.statut='actif' AND m.pa>0
 AND e.job IN ('agent_securite','maitre_chien') AND c.metier=e.job
 AND emp.pays=t.country AND m.pays=t.country
 AND m.leader_pj IS NULL AND m.leader_pnj_id IS NULL
 AND pos.pays=t.country AND pos.ville=t.data::jsonb->>'city'
 AND pos.building_id=t.building_id AND pos.room_id='terrain'
 AND pos.rue_noeud_id IS NULL;
$f$;
REVOKE ALL ON FUNCTION public.chantier_vigiles_presents_interne(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.chantier_vigiles_affecter(p_terrain text,p_ids text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text:=public.mon_personnage();pj record;t record;m record;r jsonb;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_ids IS NULL OR cardinality(p_ids)=0 OR cardinality(p_ids)>10
 OR array_position(p_ids,NULL) IS NOT NULL
 OR cardinality(p_ids)<>(SELECT count(DISTINCT v) FROM unnest(p_ids) v) THEN
  RETURN jsonb_build_object('ok',false,'raison','agents_invalides');END IF;
 SELECT * INTO pj FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF coalesce(pj.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(acteur)) THEN
  RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
 -- Ordre de verrou : acteur, PNJ (tri), terrain ; coherent avec le vol.
 PERFORM 1 FROM public.pnj_membres WHERE id=ANY(p_ids) ORDER BY id FOR UPDATE;
 SELECT * INTO t FROM public.terrains_etat WHERE country=pj.country
 AND (id=p_terrain OR building_id=p_terrain AND data::jsonb->>'city'=pj.current_city)
 ORDER BY (id=p_terrain) DESC LIMIT 1 FOR UPDATE;
 IF NOT FOUND OR pj.current_building IS DISTINCT FROM t.building_id
 OR pj.current_city IS DISTINCT FROM t.data::jsonb->>'city' OR pj.current_room IS DISTINCT FROM 'terrain' THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 PERFORM public.chantier_autorite_exiger_interne(t.data::jsonb->>'proprietaire',t.country,t.data::jsonb->>'city');
 IF jsonb_typeof(t.data::jsonb->'chantier') IS DISTINCT FROM 'object'
 OR coalesce(t.data::jsonb->>'succession_gel','')<>'' THEN
  RETURN jsonb_build_object('ok',false,'raison','chantier_indisponible');END IF;
 -- Verifier TOUS les agents avant de detacher le premier.
 IF (SELECT count(*) FROM public.pnj_membres n JOIN public.pnj_employes_metier e ON e.pnj_id=n.id
 JOIN public.pnj_candidats_catalogue c ON c.candidat_id=e.candidat_id
 JOIN public.pnj_employeurs emp ON emp.employeur_id=c.employeur_id
 WHERE n.id=ANY(p_ids) AND n.proprietaire_pj=acteur AND n.famille='employe'
 AND n.statut='actif' AND n.pa>0 AND n.pays=t.country AND emp.pays=t.country
 AND c.metier=e.job AND e.job IN('agent_securite','maitre_chien')
 AND public.pnj_peut_conduire(acteur,n.id) AND public.pnj_co_present(acteur,n.id))<>cardinality(p_ids) THEN
  RETURN jsonb_build_object('ok',false,'raison','agents_non_disponibles');END IF;
 r:=public.pnj_quitter_groupe(p_ids);
 IF NOT coalesce((r->>'ok')::boolean,false) OR (r->>'detaches')::integer<>cardinality(p_ids) THEN
  RAISE EXCEPTION 'detachement_non_confirme';END IF;
 INSERT INTO public.chantier_vigiles_affectations(pnj_id,terrain_id,employeur_pj,maitre_ouvrage)
 SELECT id,t.id,acteur,t.data::jsonb->>'proprietaire' FROM public.pnj_membres WHERE id=ANY(p_ids)
 ON CONFLICT(pnj_id) DO UPDATE SET terrain_id=excluded.terrain_id,employeur_pj=excluded.employeur_pj,
 maitre_ouvrage=excluded.maitre_ouvrage,affecte_le=now()
 WHERE (chantier_vigiles_affectations.terrain_id,chantier_vigiles_affectations.employeur_pj,chantier_vigiles_affectations.maitre_ouvrage)
 IS DISTINCT FROM (excluded.terrain_id,excluded.employeur_pj,excluded.maitre_ouvrage);
 RETURN jsonb_build_object('ok',true,'affectes',cardinality(p_ids));
EXCEPTION WHEN insufficient_privilege THEN
 RETURN jsonb_build_object('ok',false,'raison',SQLERRM);
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_vigiles_affecter(text,text[]) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.chantier_vigiles_affecter(text,text[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.chantier_securite_lire(p_terrain text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE pj record;t record;agents jsonb;
BEGIN
 SELECT * INTO pj FROM public.personnages_donnees WHERE name=public.mon_personnage();
 SELECT * INTO t FROM public.terrains_etat WHERE country=pj.country AND
 (id=p_terrain OR building_id=p_terrain AND data::jsonb->>'city'=pj.current_city) ORDER BY (id=p_terrain) DESC LIMIT 1;
 IF NOT FOUND OR pj.current_building IS DISTINCT FROM t.building_id
 OR pj.current_room IS DISTINCT FROM 'terrain' OR pj.current_city IS DISTINCT FROM t.data::jsonb->>'city' THEN
 RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(v) ORDER BY v.pnj_id),'[]') INTO agents FROM public.chantier_vigiles_presents_interne(t.id) v;
 RETURN jsonb_build_object('ok',true,'agents',agents,'nombre',jsonb_array_length(agents));
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_securite_lire(text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.chantier_securite_lire(text) TO authenticated;
-- Triple gratuit extrait de l'ordre dynamique du client ; aucune empreinte avancee.
INSERT INTO public.ordres_couts(fn,pa,cost) SELECT 'vigiles_chantier',0,0
 WHERE NOT EXISTS(SELECT 1 FROM public.ordres_couts WHERE fn='vigiles_chantier' AND pa=0 AND cost=0);
COMMIT;
