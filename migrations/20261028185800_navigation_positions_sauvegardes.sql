-- #219. Activer avec le raccordement des entrées, transports et accès spéciaux,
-- jamais avant. La fiche/inventaire ne sont pas réécrits : seuls ses lieux sont
-- retirés de la sauvegarde générale comme source d'autorité.
CREATE OR REPLACE FUNCTION public.navigation_positions_garder()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
BEGIN
 IF NOT public.est_appel_serveur()
 AND coalesce(current_setting('request.path',true),'') NOT LIKE '/rpc/%' THEN
  NEW.country:=OLD.country;
  NEW.current_city:=OLD.current_city;
  NEW.current_building:=OLD.current_building;
  NEW.current_room:=OLD.current_room;
  NEW.current_street:=OLD.current_street;
 END IF;
 RETURN NEW;
END $g$;
REVOKE ALL ON FUNCTION public.navigation_positions_garder() FROM PUBLIC,anon,authenticated,service_role;
DO $trigger$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.personnages_donnees'::regclass AND tgname='navigation_positions_garder') THEN
  CREATE TRIGGER navigation_positions_garder BEFORE UPDATE ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.navigation_positions_garder();
 ELSIF (SELECT tgfoid FROM pg_trigger WHERE tgrelid='public.personnages_donnees'::regclass AND tgname='navigation_positions_garder')
 IS DISTINCT FROM 'public.navigation_positions_garder()'::regprocedure THEN
  RAISE EXCEPTION 'navigation_trigger_existant_inconnu'; END IF;
END $trigger$;
-- Annoncer la capacité dans la lecture d'appartenance déjà effectuée au login.
DO $capacite$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.groupe_pj_lire()'::regprocedure);
 a:='''contrat'',1,''chef'',chef_courant';b:='''contrat'',1,''navigation_serveur'',true,''chef'',chef_courant';
 IF position(b IN s)>0 THEN RETURN; END IF;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'navigation_contrat_groupe_inconnu'; END IF;
 EXECUTE replace(s,a,b);
END $capacite$;
