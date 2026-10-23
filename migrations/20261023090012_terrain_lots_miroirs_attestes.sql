-- #94 PREPAREE : les anciens actes de lots ne peuvent reecrire geometrie, titres ou loyers.
BEGIN;
DO $garde$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.terrain_lots_acte(text,text,jsonb,text[])');IF h IS NOT NULL AND h NOT IN('9d14be53d8be1dd0d5940c2c4b4cfce5','9d648dfb4f5248faf18b4373083ba57f') THEN RAISE EXCEPTION 'definition_non_examinee: terrain_lots_acte(text,text,jsonb,text[])';END IF;
END;$garde$;
CREATE OR REPLACE FUNCTION public.terrain_lots_acte(p_terrain_id text,p_acte text,p_lots jsonb DEFAULT NULL,p_retirer text[] DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();p record;t record;etat jsonb;lots jsonb;sortie jsonb:='[]';entree jsonb;lot jsonb;nouveau jsonb;bail record;vus text[]:=ARRAY[]::text[];idlot text;modifie boolean:=false;proprio boolean:=false;
BEGIN
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_acte IN('lot_ajouter','lot_fusion_proposer','lot_fusion_accepter') THEN RETURN jsonb_build_object('ok',false,'raison','reamenagement_payant_requis');END IF;
 IF p_acte IS NULL OR p_acte NOT IN('lot_louer','lot_bail_libere','lot_fusion_refuser') THEN RETURN jsonb_build_object('ok',false,'raison','acte_inconnu');END IF;
 IF p_retirer IS NOT NULL AND cardinality(p_retirer)>0 THEN RETURN jsonb_build_object('ok',false,'raison','suppression_interdite');END IF;
 IF jsonb_typeof(p_lots) IS DISTINCT FROM 'array' OR jsonb_array_length(p_lots)=0 THEN RETURN jsonb_build_object('ok',false,'raison','lots_invalides');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 IF coalesce(p.hp,0)<=0 OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text OR EXISTS(SELECT 1 FROM public.detention_active(moi)) THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE country=p.country AND (id=p_terrain_id OR building_id=p_terrain_id AND data::jsonb->>'city'=p.current_city) ORDER BY (id=p_terrain_id) DESC LIMIT 1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable');END IF;
 etat:=t.data::jsonb;lots:=coalesce(etat->'subdivisions','[]');
 IF coalesce(etat->>'succession_gel','')<>'' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele');END IF;
 -- Valider TOUTE la commande avant la premiere ecriture, puis ne reprendre que l'identifiant.
 FOR entree IN SELECT value FROM jsonb_array_elements(p_lots) LOOP
  idlot:=entree->>'id';
  IF idlot IS NULL OR idlot=ANY(vus) THEN RETURN jsonb_build_object('ok',false,'raison','identifiant_lot_invalide');END IF;
  vus:=array_append(vus,idlot);
  SELECT value INTO lot FROM jsonb_array_elements(lots) WHERE value->>'id'=idlot;
  IF lot IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','lot_introuvable');END IF;
  IF p_acte='lot_louer' THEN
   IF p.current_city IS DISTINCT FROM etat->>'city' OR p.current_building IS DISTINCT FROM t.building_id THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
   IF etat->'chantierReamenagement'->'lotsConcernes' ? idlot THEN RETURN jsonb_build_object('ok',false,'raison','lot_en_travaux');END IF;
   SELECT * INTO bail FROM public.locations_actives WHERE country=t.country AND data->>'city'=etat->>'city' AND data->>'buildingId'=t.building_id AND data->>'roomId'='lot_dyn_'||regexp_replace(idlot,'[^A-Za-z0-9_-]','_','g') FOR UPDATE;
   IF NOT FOUND OR bail.data->>'locataire' IS DISTINCT FROM moi OR nullif(lot->>'locataire','') IS NOT NULL AND lot->>'locataire' NOT IN(moi,'pj:'||moi) THEN RETURN jsonb_build_object('ok',false,'raison','pas_mon_bail');END IF;
  ELSIF p_acte='lot_fusion_refuser' THEN
   IF lot->>'locataire' NOT IN(moi,'pj:'||moi) OR lot->>'locataire' IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pas_mon_bail');END IF;
  ELSE
   -- Une liberation de miroir ne resilie pas le bail canonique et n'expulse personne.
   IF EXISTS(SELECT 1 FROM public.locations_actives WHERE country=t.country AND data->>'city'=etat->>'city' AND data->>'buildingId'=t.building_id AND data->>'roomId'='lot_dyn_'||regexp_replace(idlot,'[^A-Za-z0-9_-]','_','g')) THEN RETURN jsonb_build_object('ok',false,'raison','bail_encore_actif');END IF;
   IF nullif(lot->>'locataire','') IS NOT NULL AND lot->>'locataire' NOT IN(moi,'pj:'||moi) THEN
    -- Meme autorite que le chantier pour PJ, organisation et commune ; aucun titre de presentation.
    PERFORM public.chantier_autorite_exiger_interne(etat->>'proprietaire',t.country,etat->>'city');
   END IF;
  END IF;
 END LOOP;
 FOR lot IN SELECT value FROM jsonb_array_elements(lots) LOOP
  nouveau:=lot;
  IF lot->>'id'=ANY(vus) THEN
   nouveau:=CASE WHEN p_acte='lot_louer' THEN lot||jsonb_build_object('locataire',moi) WHEN p_acte='lot_bail_libere' THEN lot||jsonb_build_object('locataire',NULL) ELSE lot-'propositionAgrandissement' END;
  END IF;
  modifie:=modifie OR nouveau<>lot;sortie:=sortie||jsonb_build_array(nouveau);
 END LOOP;
 IF modifie THEN
  etat:=etat||jsonb_build_object('subdivisions',sortie,'lotsHistorique',coalesce(etat->'lotsHistorique','[]')||jsonb_build_array(jsonb_build_object('acte',p_acte,'acteur',moi,'date',statement_timestamp(),'lots',to_jsonb(vus))));
  UPDATE public.terrains_etat SET data=etat::text,updated_at=now() WHERE id=t.id;
 END IF;
 RETURN jsonb_build_object('ok',true,'etat',etat,'lots',sortie,'rejeu',NOT modifie,'retires',0);
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_lots_acte(text,text,jsonb,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.terrain_lots_acte(text,text,jsonb,text[]) TO authenticated;
COMMIT;
