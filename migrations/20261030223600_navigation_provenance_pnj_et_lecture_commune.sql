-- #219 PRÉPARÉE, après 20261030223559. Aucune valeur de position inventée.
ALTER TABLE public.pnj_membres ADD COLUMN IF NOT EXISTS rue_depuis text;
CREATE OR REPLACE FUNCTION public.pnj_navigation_provenance_garder_interne()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
BEGIN
 NEW.rue_depuis:=OLD.rue_depuis;
 IF NEW.leader_pj IS NULL AND NEW.leader_pnj_id IS NULL AND NEW.rue_noeud_id IS NOT NULL AND OLD.leader_pj IS NOT NULL THEN
  -- Une dépose conserve l'orientation réellement suivie, jamais celle du demandeur.
  SELECT d.current_street_from INTO NEW.rue_depuis FROM public.personnages_donnees d
  WHERE d.name=OLD.leader_pj AND d.country=NEW.pays AND d.current_city=NEW.ville
   AND d.current_building IS NULL AND d.current_street=NEW.rue_noeud_id;
 ELSIF NEW.leader_pj IS NULL AND NEW.leader_pnj_id IS NULL AND NEW.rue_noeud_id IS NOT NULL AND OLD.leader_pnj_id IS NOT NULL THEN
  SELECT m.rue_depuis INTO NEW.rue_depuis FROM public.pnj_membres m CROSS JOIN LATERAL public.pnj_position_effective(m.id) pe
  WHERE m.id=OLD.leader_pnj_id AND pe.pays=NEW.pays AND pe.ville=NEW.ville AND pe.building_id IS NULL AND pe.rue_noeud_id=NEW.rue_noeud_id;
 ELSIF NEW.pays IS DISTINCT FROM OLD.pays OR NEW.ville IS DISTINCT FROM OLD.ville THEN NEW.rue_depuis:=NULL;
 ELSIF NEW.leader_pj IS NULL AND NEW.leader_pnj_id IS NULL AND OLD.building_id IS NULL AND NEW.building_id IS NULL
  AND NEW.rue_noeud_id IS DISTINCT FROM OLD.rue_noeud_id THEN NEW.rue_depuis:=OLD.rue_noeud_id;END IF;
 RETURN NEW;
END $g$;
REVOKE ALL ON FUNCTION public.pnj_navigation_provenance_garder_interne() FROM PUBLIC,anon,authenticated,service_role;
DO $trigger$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.pnj_membres'::regclass AND tgname='pnj_navigation_provenance') THEN
  CREATE TRIGGER pnj_navigation_provenance BEFORE UPDATE ON public.pnj_membres FOR EACH ROW EXECUTE FUNCTION public.pnj_navigation_provenance_garder_interne();
 ELSIF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.pnj_membres'::regclass AND tgname='pnj_navigation_provenance'
  AND tgfoid='public.pnj_navigation_provenance_garder_interne()'::regprocedure AND tgtype=19 AND tgenabled='O' AND tgqual IS NULL) THEN
  RAISE EXCEPTION 'pnj_provenance_trigger_inconnu';END IF;
END $trigger$;
DO $repli$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.militaire_repli_pnj_interne(bigint,text,integer)'::regprocedure);
 IF position('-- PNJ_provenance_commune_v1' IN s)>0 THEN RETURN;END IF;
 a:='SELECT m.id,m.leader_pnj_id,pe.* FROM public.pnj_membres m CROSS JOIN';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'pnj_repli_lecture_non_examinee';END IF;
 s:=replace(s,a,'SELECT m.id,m.leader_pnj_id,coalesce(m.rue_depuis,l.rue_depuis) AS rue_depuis,pe.* FROM public.pnj_membres m LEFT JOIN public.pnj_membres l ON l.id=m.leader_pnj_id CROSS JOIN');
 a:='r.rue_noeud_id,NULL)';IF position(a IN s)=0 THEN RAISE EXCEPTION 'pnj_repli_direction_non_examinee';END IF;
 s:=replace(s,a,'r.rue_noeud_id,r.rue_depuis)');
 EXECUTE overlay(s placing '-- PNJ_provenance_commune_v1'||chr(10) FROM position('BEGIN' IN s) FOR 0);
END $repli$;
-- Lecture déjà faite au chargement et aux interactions : même ligne canonique,
-- pas une seconde table de position ni une consultation périodique supplémentaire.
DO $lecture$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.groupe_pj_lire()'::regprocedure);
 IF position('''position_personnelle''' IN s)>0 THEN RETURN;END IF;
 a:='''chef'',chef_courant';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'groupe_lecture_position_non_examinee';END IF;
 EXECUTE replace(s,a,$b$'position_personnelle',(SELECT jsonb_build_object('ok',true,'personnage',d.name,
  'country',d.country,'city',d.current_city,'building',d.current_building,'room',d.current_room,
  'street',d.current_street,'depuis',d.current_street_from) FROM public.personnages_donnees d WHERE d.name=moi),$b$||a);
END $lecture$;
