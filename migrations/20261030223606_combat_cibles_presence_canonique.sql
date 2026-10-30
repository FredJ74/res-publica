-- #219 : lecture minimale des cibles réellement présentes, pas un second registre.
-- Aucun argent, possession, caractéristique ou autorité administrative exposé.
CREATE OR REPLACE FUNCTION public.combat_cibles_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE moi text;p public.personnages_donnees%ROWTYPE;v jsonb;e jsonb;
BEGIN
 moi:=public.mon_personnage();IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',m.id,'nom',m.nom,'classe',m.classe) ORDER BY m.id),'[]') INTO v
 FROM public.pnj_membres m WHERE m.statut='actif' AND m.pa>0 AND m.classe IN ('alpha','beta')
 AND (m.famille='soldat' OR (m.car_vol IS NOT NULL AND m.car_per IS NOT NULL AND m.car_dup IS NOT NULL))
 AND public.pnj_co_present(moi,m.id);
 -- Un occupant validé peut ne pas avoir encore été matérialisé. La consultation
 -- ne le crée pas : la même ouverture transactionnelle le fera lors de l'acte.
 IF p.current_building LIKE 'terrain-a-batir%' THEN
  SELECT data::jsonb INTO e FROM public.terrains_etat WHERE id=p.country||'_'||p.current_building AND building_id=p.current_building;
  IF e->>'city'=p.current_city AND e->>'pnj' IN ('squatter_cool','squatter_agr') THEN
   v:=v||jsonb_build_array(jsonb_build_object('terrain',p.current_building,'occupation',e->>'pnj','nom','squatteurs','classe','beta'));
  END IF;
 END IF;
 RETURN jsonb_build_object('ok',true,'cibles',v);
END $g$;
REVOKE ALL ON FUNCTION public.combat_cibles_lire() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.combat_cibles_lire() TO authenticated;
