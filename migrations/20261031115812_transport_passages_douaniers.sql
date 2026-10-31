-- #219 : remplacer l'attestation du navigateur, pas créer une billetterie.
CREATE TABLE IF NOT EXISTS public.navigation_passages_douaniers(
 personnage text PRIMARY KEY,pays text NOT NULL,ville text NOT NULL,batiment text NOT NULL,
 mode text NOT NULL CHECK(mode IN ('avion','bateau')),corruption boolean NOT NULL DEFAULT false,
 controle_le timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.navigation_passages_douaniers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.navigation_passages_douaniers FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.douane_passage_valide_interne(p_nom text,p_mode text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT EXISTS(SELECT 1 FROM public.navigation_passages_douaniers a
 JOIN public.personnages_donnees d ON d.name=a.personnage
 WHERE a.personnage=p_nom AND a.mode=p_mode AND a.pays=d.country
 AND a.ville=d.current_city AND a.batiment=d.current_building);
$g$;
REVOKE ALL ON FUNCTION public.douane_passage_valide_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.douane_passage_invalider()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
BEGIN
 IF (OLD.country,OLD.current_city,OLD.current_building) IS DISTINCT FROM
 (NEW.country,NEW.current_city,NEW.current_building) THEN
 DELETE FROM public.navigation_passages_douaniers WHERE personnage=NEW.name;
 END IF;
 RETURN NEW;
END $g$;
REVOKE ALL ON FUNCTION public.douane_passage_invalider() FROM PUBLIC,anon,authenticated,service_role;
DO $g$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.personnages_donnees'::regclass AND tgname='douane_passage_invalider') THEN
 CREATE TRIGGER douane_passage_invalider AFTER UPDATE ON public.personnages_donnees
 FOR EACH ROW EXECUTE FUNCTION public.douane_passage_invalider();END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.personnages_donnees'::regclass
 AND tgname='douane_passage_invalider' AND tgenabled='O' AND tgfoid='public.douane_passage_invalider()'::regprocedure) THEN
 RAISE EXCEPTION 'garde_passage_douanier_non_conforme';END IF;
END $g$;
