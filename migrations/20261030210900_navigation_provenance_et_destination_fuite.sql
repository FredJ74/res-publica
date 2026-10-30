-- #219 PRÉPARÉE, non appliquée. La gauche est une direction, pas voisins[1].
-- Dépend du socle navigation #219 et précède les références générées 223400+.
ALTER TABLE public.rue_noeuds_serveur ADD COLUMN IF NOT EXISTS directions jsonb;
ALTER TABLE public.personnages_donnees ADD COLUMN IF NOT EXISTS current_street_from text;
CREATE OR REPLACE FUNCTION public.navigation_provenance_garder_interne()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
BEGIN
 -- Ce trigger vient après navigation_positions_garder : une sauvegarde refusée
 -- n'est pas un déplacement. Aucune provenance transmise par l'écran n'est adoptée.
 NEW.current_street_from:=OLD.current_street_from;
 IF NEW.country IS DISTINCT FROM OLD.country OR NEW.current_city IS DISTINCT FROM OLD.current_city THEN
  NEW.current_street_from:=NULL;
 ELSIF NEW.current_building IS NULL AND OLD.current_building IS NULL
  AND NEW.current_street IS DISTINCT FROM OLD.current_street THEN
  NEW.current_street_from:=OLD.current_street;
 END IF;
 RETURN NEW;
END $g$;
REVOKE ALL ON FUNCTION public.navigation_provenance_garder_interne() FROM PUBLIC,anon,authenticated,service_role;
DO $trigger$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.personnages_donnees'::regclass AND tgname='navigation_provenance_garder') THEN
  CREATE TRIGGER navigation_provenance_garder BEFORE UPDATE ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.navigation_provenance_garder_interne();
 ELSIF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.personnages_donnees'::regclass AND tgname='navigation_provenance_garder'
  AND tgfoid='public.navigation_provenance_garder_interne()'::regprocedure AND tgtype=19 AND tgenabled='O' AND tgqual IS NULL) THEN
  RAISE EXCEPTION 'provenance_trigger_inconnu';END IF;
END $trigger$;
CREATE OR REPLACE FUNCTION public.navigation_destination_fuite_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE p public.personnages_donnees%ROWTYPE;d jsonb;destination text;voisins text[];n integer;
BEGIN
 SELECT * INTO p FROM public.personnages_donnees WHERE name=p_nom FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent');END IF;
 IF p.current_building IS NOT NULL THEN
  SELECT count(*),min(noeud) INTO n,destination FROM public.rue_sorties_batiments
  WHERE country=p.country AND city=p.current_city AND building=p.current_building;
  IF n<>1 THEN RETURN jsonb_build_object('ok',false,'raison','sortie_batiment_non_univoque');END IF;
 ELSE
  SELECT count(*) INTO n FROM public.rue_noeuds_serveur WHERE country=p.country AND city=p.current_city AND noeud=p.current_street;
  IF n<>1 THEN RETURN jsonb_build_object('ok',false,'raison','rue_non_referencee');END IF;
  SELECT directions,r.voisins INTO d,voisins FROM public.rue_noeuds_serveur r WHERE country=p.country AND city=p.current_city AND noeud=p.current_street;
  IF d IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','directions_non_referencees');END IF;
  IF d->'parArrivee'<>'{}'::jsonb THEN
   IF p.current_street_from IS NULL OR NOT (d->'parArrivee') ? p.current_street_from THEN
    RETURN jsonb_build_object('ok',false,'raison','provenance_non_referencee');END IF;
   destination:=d->'parArrivee'->p.current_street_from->>'gauche';
  ELSE destination:=d->'liens'->>'gauche';END IF;
  IF destination IS NULL OR NOT coalesce(destination=ANY(voisins),false) THEN
   RETURN jsonb_build_object('ok',false,'raison','rue_gauche_non_referencee');END IF;
 END IF;
 RETURN jsonb_build_object('ok',true,'destination',destination);
END $g$;
REVOKE ALL ON FUNCTION public.navigation_destination_fuite_interne(text) FROM PUBLIC,anon,authenticated,service_role;
