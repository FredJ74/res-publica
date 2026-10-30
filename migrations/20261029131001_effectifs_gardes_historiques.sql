-- #219 : scission technique (limite MCP 12 500 caractères).
-- Appliquer ces deux fichiers consécutifs dans la même transaction.
CREATE OR REPLACE FUNCTION public.effectifs_ecriture_metier_garder()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp' AS $g$
DECLARE avant jsonb;apres jsonb;chemin text:=coalesce(current_setting('request.path',true),'');
BEGIN
 IF public.est_appel_serveur() OR (current_user NOT IN ('authenticated','anon') AND chemin=ANY(ARRAY[
 '/rpc/force_publique_effectif_acte','/rpc/pnj_prendre','/rpc/pnj_quitter_groupe','/rpc/pnj_transferer',
 '/rpc/pnj_deployer_unite','/rpc/pnj_rappeler_radio','/rpc/rue_position_enregistrer','/rpc/navigation_interieure',
 '/rpc/transport_effectuer','/rpc/douane_controle_groupe','/rpc/police_combat_resoudre',
 '/rpc/police_reddition_resoudre','/rpc/police_fuite_resoudre','/rpc/justice_executer_condamnation_soi',
 '/rpc/detention_ouvrir_soi','/rpc/detention_transferer_qhs','/rpc/police_payer_effectifs','/rpc/douane_payer_effectifs'])) THEN
  IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
 END IF;
 IF TG_OP<>'INSERT' THEN avant:=public.batiment_etat_lire(OLD.data);END IF;
 IF TG_OP<>'DELETE' THEN apres:=public.batiment_etat_lire(NEW.data);END IF;
 IF (avant->'effectifsPolice',avant->'effectifsDouane') IS DISTINCT FROM (apres->'effectifsPolice',apres->'effectifsDouane')
 OR (TG_OP='UPDATE' AND ((avant ? 'effectifsPolice') OR (avant ? 'effectifsDouane')) AND
 (OLD.id,OLD.country,OLD.city,OLD.building_id) IS DISTINCT FROM (NEW.id,NEW.country,NEW.city,NEW.building_id)) THEN
  RAISE EXCEPTION 'effectifs_ecriture_metier_requise';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END $g$;
REVOKE ALL ON FUNCTION public.effectifs_ecriture_metier_garder() FROM PUBLIC,anon,authenticated,service_role;
DO $garde$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.batiments_etat'::regclass AND tgname='effectifs_ecriture_metier') THEN
  CREATE TRIGGER effectifs_ecriture_metier BEFORE INSERT OR UPDATE OR DELETE ON public.batiments_etat FOR EACH ROW EXECUTE FUNCTION public.effectifs_ecriture_metier_garder();
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.batiments_etat'::regclass AND tgname='effectifs_ecriture_metier' AND tgenabled='O' AND tgfoid='public.effectifs_ecriture_metier_garder()'::regprocedure) THEN RAISE EXCEPTION 'effectifs_garde_non_conforme';END IF;
END $garde$;

-- Un PNJ détaché mais déjà recruté dans une interception reste engagé.
DO $confrontation$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.pnj_confrontation_refus_interne(text[])'::regprocedure);
 IF position('-- effectifs_interception_figee_v1' IN s)>0 THEN RETURN;END IF;
 a:=E'  SELECT ''combat_en_cours'' FROM public.batailles_engagements e';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'effectifs_confrontation_corps_non_examine';END IF;
 s:=replace(s,a,E'  -- effectifs_interception_figee_v1\n  SELECT ''interception_en_cours'' FROM public.police_interceptions i\n  CROSS JOIN LATERAL jsonb_array_elements_text(coalesce(i.combattants_forces,''[]''::jsonb)||coalesce(i.combattants_victimes,''[]''::jsonb)) x(cle)\n  WHERE i.expires_at>now() AND x.cle LIKE ''pnj:%'' AND substring(x.cle FROM 5)=ANY(p_ids)\n  UNION ALL\n'||a);
 EXECUTE s;
END $confrontation$;
