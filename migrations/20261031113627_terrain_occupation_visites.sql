-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261022222907_terrain_occupation_visites.sql ; aucun changement de règle.
-- #94 PREPAREE : l'occupation reste dans terrains_etat ; les visites sont un verrou technique.
BEGIN;
CREATE TABLE public.terrain_visites_actives (
 personnage_id uuid NOT NULL REFERENCES public.personnages_donnees(id) ON DELETE CASCADE, terrain_id text NOT NULL REFERENCES public.terrains_etat(id),
 PRIMARY KEY(personnage_id,terrain_id)
);
ALTER TABLE public.terrain_visites_actives ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.terrain_visites_actives FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.terrain_occupation_tirer_interne() RETURNS text
LANGUAGE sql VOLATILE SET search_path=public,pg_temp AS $f$
 SELECT (ARRAY[NULL::text,'squatter_cool','squatter_agr','cadavre'])[1+floor(random()*4)::integer];
$f$;
REVOKE ALL ON FUNCTION public.terrain_occupation_tirer_interne() FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.terrain_visites_clore_interne() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE v record;
BEGIN
 -- Un rechargement, une sauvegarde ou un changement de piece ne termine pas la visite.
 IF (NEW.country,NEW.current_city,NEW.current_building) IS NOT DISTINCT FROM
    (OLD.country,OLD.current_city,OLD.current_building) THEN RETURN NEW; END IF;
 FOR v IN SELECT t.id FROM public.terrain_visites_actives a JOIN public.terrains_etat t ON t.id=a.terrain_id
  WHERE a.personnage_id=OLD.id AND (t.country,t.building_id) IS DISTINCT FROM (NEW.country,NEW.current_building)
  ORDER BY t.id FOR UPDATE OF t LOOP
  DELETE FROM public.terrain_visites_actives WHERE personnage_id=OLD.id AND terrain_id=v.id;
 END LOOP;
 RETURN NEW;
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_visites_clore_interne() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER terrain_visites_deplacement AFTER UPDATE OF country,current_city,current_building
 ON public.personnages_donnees FOR EACH ROW EXECUTE FUNCTION public.terrain_visites_clore_interne();
CREATE FUNCTION public.terrain_occupation_lire(p_terrain text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text:=public.mon_personnage();p record;t record;e jsonb;nouvelle boolean;occupation text;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 SELECT id,country,current_city,current_building INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT FOUND OR p.current_building IS DISTINCT FROM p_terrain OR p_terrain NOT LIKE 'terrain-a-batir%' THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE id=p.country||'_'||p_terrain AND country=p.country
  AND building_id=p_terrain FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
 e:=public.terrain_etat_lire(t.data);
 IF e IS NULL OR e->>'city' IS DISTINCT FROM p.current_city THEN RETURN jsonb_build_object('ok',false,'raison','terrain_incoherent'); END IF;
 nouvelle:=NOT EXISTS(SELECT 1 FROM public.terrain_visites_actives WHERE terrain_id=t.id);
 IF nouvelle AND NOT coalesce((e->>'occupationScellee')::boolean,false)
  AND nullif(e->>'proprietaire','') IS NULL AND NOT coalesce((e->>'compromis')::boolean,false)
  AND coalesce(e->>'succession_gel','')=''
  AND coalesce(e->>'policeAppellee','')=''
  AND coalesce((e->>'enqueteJusqua')::numeric,0)<=extract(epoch FROM clock_timestamp())*1000 THEN
  -- Conserver une presence historique a sa premiere adoption, sans la reinterpreter.
  IF coalesce((e->>'occupationInitialisee')::boolean,false) OR NOT (e ? 'pnj') THEN
   occupation:=public.terrain_occupation_tirer_interne();
   e:=public.terrain_etat_fusionner_interne(t.id,jsonb_build_object('pnj',occupation,'pnjData',NULL,
    'occupationInitialisee',true,'dateGeneration',floor(extract(epoch FROM clock_timestamp())*1000)),p.country);
  ELSE
   e:=public.terrain_etat_fusionner_interne(t.id,'{"occupationInitialisee":true}',p.country);
  END IF;
 END IF;
 IF nullif(e->>'proprietaire','') IS NOT NULL OR coalesce((e->>'compromis')::boolean,false) THEN
  e:=public.terrain_etat_fusionner_interne(t.id,'{"occupationScellee":true}',p.country);
 END IF;
 INSERT INTO public.terrain_visites_actives VALUES(p.id,t.id) ON CONFLICT DO NOTHING;
 RETURN jsonb_build_object('ok',true,'etat',e);
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_occupation_lire(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.terrain_occupation_lire(text) TO authenticated;
COMMIT;
