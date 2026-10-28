-- #219 : le pays institutionnel n'est pas le pays du déplacement.
-- Préparée, non appliquée. Ne pas activer sans le lot navigation complet.
ALTER TABLE public.pnj_membres ADD COLUMN IF NOT EXISTS position_pays text;
COMMENT ON COLUMN public.pnj_membres.position_pays IS
 'Pays physique du PNJ détaché ; NULL reprend le pays historique. Ne transfère ni nationalité ni autorité institutionnelle.';

DO $position$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.pnj_position_effective(text)'::regprocedure);
 a:='SELECT m.pays,';
 b:='SELECT CASE WHEN m.leader_pj IS NOT NULL THEN d.country'
 ||chr(10)||'    WHEN m.leader_pnj_id IS NOT NULL THEN coalesce(l.position_pays,l.pays)'
 ||chr(10)||'    ELSE coalesce(m.position_pays,m.pays) END,';
 IF position(b IN s)>0 THEN RETURN;END IF;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN
 RAISE EXCEPTION 'pnj_pays_position_definition_non_examinee';END IF;
 -- Toutes les autres coordonnées et gardes du corps présent sont conservées.
 EXECUTE replace(s,a,b);
END $position$;

CREATE OR REPLACE FUNCTION public.pnj_position_pays_garder()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
BEGIN
 IF NOT public.est_appel_serveur() AND coalesce(current_setting('request.path',true),'') NOT LIKE '/rpc/%' THEN
  IF NEW.position_pays IS DISTINCT FROM OLD.position_pays THEN
   RAISE EXCEPTION 'position_pnj_reservee_au_serveur';END IF;
 END IF;
 -- Avant de couper le lien, mémoriser le pays réellement occupé, exactement
 -- comme les portes communes mémorisent déjà ville/bâtiment/pièce/rue.
 IF NEW.leader_pj IS NULL AND NEW.leader_pnj_id IS NULL
 AND (OLD.leader_pj IS NOT NULL OR OLD.leader_pnj_id IS NOT NULL) THEN
  SELECT pays INTO NEW.position_pays FROM public.pnj_position_effective(OLD.id);
 END IF;
 RETURN NEW;
END $g$;
REVOKE ALL ON FUNCTION public.pnj_position_pays_garder() FROM PUBLIC,anon,authenticated,service_role;
DO $trigger$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.pnj_membres'::regclass AND tgname='pnj_position_pays_garde') THEN
  CREATE TRIGGER pnj_position_pays_garde BEFORE UPDATE ON public.pnj_membres
  FOR EACH ROW EXECUTE FUNCTION public.pnj_position_pays_garder();
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.pnj_membres'::regclass
 AND tgname='pnj_position_pays_garde' AND tgenabled='O' AND tgfoid='public.pnj_position_pays_garder()'::regprocedure) THEN
 RAISE EXCEPTION 'garde_pays_pnj_non_conforme';END IF;
END $trigger$;

-- Les gardes géographiques utilisent désormais le pays effectif, sans toucher
-- les résolveurs administratifs qui continuent à lire le pays d'origine.
DO $portes$
DECLARE f text;s text;a text;b text;
BEGIN
 FOREACH f IN ARRAY ARRAY['navigation_commander_interne(text,text,text)','transport_effectuer(text,text,text,uuid)','pnj_deployer_unite(text[],boolean)'] LOOP
  s:=pg_get_functiondef(('public.'||f)::regprocedure);
  IF position('-- pays_physique_groupes_v1' IN s)>0 THEN CONTINUE;END IF;
  IF f LIKE 'pnj_deployer%' THEN
   a:='m.pays=v_lieu.country';b:='(SELECT pays FROM public.pnj_position_effective(m.id))=v_lieu.country';
  ELSIF f LIKE 'transport_%' THEN
   a:='OR pays IS DISTINCT FROM p.country';b:='OR (SELECT pe.pays FROM public.pnj_position_effective(pnj_membres.id) pe) IS DISTINCT FROM p.country';
  ELSE
   a:='pays IS DISTINCT FROM a.country';b:='(SELECT pe.pays FROM public.pnj_position_effective(pnj_membres.id) pe) IS DISTINCT FROM a.country';
  END IF;
  IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'porte_pays_non_examinee: %',f;END IF;
  s:=replace(s,a,b);s:=replace(s,'BEGIN',E'BEGIN\n -- pays_physique_groupes_v1');EXECUTE s;
 END LOOP;
END $portes$;
