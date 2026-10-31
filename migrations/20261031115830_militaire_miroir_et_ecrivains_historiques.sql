-- #219 : les miroirs ne ressuscitent pas les soldats ; pas de suppression
-- de l'identité/histoire d'un mort ou détenu absent d'une ancienne photographie.
DO $miroir$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.pnj_miroir_compagnie(text)'::regprocedure);
 IF position('-- militaire_miroir_histoire_v1' IN s)>0 THEN RETURN;END IF;
 a:='statut = EXCLUDED.statut,';
 b:='statut = CASE WHEN pnj_membres.statut IN (''mort'',''detenu'') THEN pnj_membres.statut ELSE EXCLUDED.statut END,';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>2 THEN RAISE EXCEPTION 'miroir_soldats_statut_non_examine';END IF;
 s:=replace(s,a,b);
 a:='WHERE id LIKE p_compagnie || ''-%'' AND NOT (id = ANY(v_vus));';
 b:='WHERE id LIKE p_compagnie || ''-%'' AND NOT (id = ANY(v_vus)) AND statut NOT IN (''mort'',''detenu'');';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'miroir_soldats_histoire_non_examine';END IF;
 s:=replace(s,a,b);s:=overlay(s placing E'BEGIN\n -- militaire_miroir_histoire_v1' FROM position('BEGIN' IN s) FOR 5);
 EXECUTE s;
END $miroir$;

-- sbSaveCompagnie n'a plus d'appelant et a été retirée de main le 27/10.
-- Les ordres utiles existent en RPC militaires : garder leurs droits, fermer
-- seulement l'ancien remplacement arbitraire du document de compagnie.
CREATE OR REPLACE FUNCTION public.compagnie_ecriture_metier_garder()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp' AS $g$
DECLARE chemin text:=coalesce(current_setting('request.path',true),'');
BEGIN
 IF public.est_appel_serveur() OR (current_user NOT IN ('authenticated','anon') AND
  (chemin LIKE '/rpc/militaire\_%' ESCAPE '\' OR chemin=ANY(ARRAY[
  '/rpc/pnj_prendre','/rpc/pnj_quitter_groupe','/rpc/pnj_transferer','/rpc/pnj_deployer_unite','/rpc/pnj_rappeler_radio',
  '/rpc/rue_position_enregistrer','/rpc/navigation_interieure','/rpc/transport_effectuer','/rpc/douane_controle_groupe',
  '/rpc/police_combat_resoudre','/rpc/police_reddition_resoudre','/rpc/police_fuite_resoudre',
  '/rpc/justice_executer_condamnation_soi','/rpc/detention_ouvrir_soi','/rpc/detention_transferer_qhs']))) THEN
  IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
 END IF;
 RAISE EXCEPTION 'compagnie_ecriture_metier_requise';
END $g$;
REVOKE ALL ON FUNCTION public.compagnie_ecriture_metier_garder() FROM PUBLIC,anon,authenticated,service_role;
DO $garde$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.compagnies_militaires'::regclass AND tgname='compagnie_ecriture_metier') THEN
 CREATE TRIGGER compagnie_ecriture_metier BEFORE INSERT OR UPDATE OR DELETE ON public.compagnies_militaires FOR EACH ROW EXECUTE FUNCTION public.compagnie_ecriture_metier_garder();
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.compagnies_militaires'::regclass AND tgname='compagnie_ecriture_metier' AND tgenabled='O' AND tgfoid='public.compagnie_ecriture_metier_garder()'::regprocedure) THEN RAISE EXCEPTION 'compagnie_garde_non_conforme';END IF;
END $garde$;
