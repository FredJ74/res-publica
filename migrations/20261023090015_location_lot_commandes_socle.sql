-- #94 PREPAREE : baux existants, leur prelevement commun et le recu de chantier existant.
BEGIN;
DO $garde$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.location_lot_enregistrer_interne(jsonb,text,text,text,text,integer)');IF h IS NOT NULL AND h<>'13c2d4d81e8a6f65835fd9b36829f46e' THEN RAISE EXCEPTION 'definition_non_examinee: location_lot_enregistrer_interne(jsonb,text,text,text,text,integer)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.location_lot_ecriture_attester()');IF h IS NOT NULL AND h<>'c15d550e95f1df4f842181ed4f879256' THEN RAISE EXCEPTION 'definition_non_examinee: location_lot_ecriture_attester()';END IF;
END;$garde$;
CREATE OR REPLACE FUNCTION public.location_lot_enregistrer_interne(p_etat jsonb,p_pays text,p_batiment text,p_lot text,p_acteur text,p_jour integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE lot jsonb;nouveau jsonb;lots jsonb:='[]';piece text;idb text;bail jsonb;r text;loyer numeric;
BEGIN
 SELECT value INTO lot FROM jsonb_array_elements(coalesce(p_etat->'subdivisions','[]')) WHERE value->>'id'=p_lot;
 IF lot IS NULL OR (SELECT count(*) FROM jsonb_array_elements(coalesce(p_etat->'subdivisions','[]')) WHERE value->>'id'=p_lot)<>1 OR nullif(p_etat->>'niveau_construction','') IS NULL THEN RAISE EXCEPTION 'lot_introuvable';END IF;
 IF nullif(lot->>'proprietaire','') IS NOT NULL AND lot->>'proprietaire' IS DISTINCT FROM p_etat->>'proprietaire' THEN RAISE EXCEPTION 'lot_vendu';END IF;
 IF nullif(lot->>'locataire','') IS NOT NULL THEN RAISE EXCEPTION 'local_occupe';END IF;
 IF p_etat->'chantierReamenagement'->'lotsConcernes' ? p_lot THEN RAISE EXCEPTION 'lot_en_travaux';END IF;
 loyer:=(lot->>'loyer')::numeric;
 IF loyer IS NULL OR loyer<0 OR loyer<>trunc(loyer) OR loyer::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'loyer_invalide';END IF;
 piece:='lot_dyn_'||regexp_replace(p_lot,'[^A-Za-z0-9_-]','_','g');idb:=p_pays||':'||p_batiment||':'||piece||':'||(p_etat->>'city');
 IF EXISTS(SELECT 1 FROM public.locations_actives WHERE id=idb OR country=p_pays AND data->>'city'=p_etat->>'city' AND data->>'buildingId'=p_batiment AND data->>'roomId'=piece) THEN RAISE EXCEPTION 'local_occupe';END IF;
 bail:=jsonb_build_object('country',p_pays,'city',p_etat->>'city','buildingId',p_batiment,'roomId',piece,'lotId',p_lot,'localKey',p_pays||'|'||(p_etat->>'city')||'|'||p_batiment||'|'||piece,'localLabel',lot->>'label','batimentLabel',p_batiment,'prix',loyer,'bonusPOP',0,'bonusINF',0,'bonusDIS',0,'orgaId','','orgaAutorisee',true,'locataire',p_acteur,'depuis',p_jour,'visible',true,'destinationLoyer',public.bail_destination_attestee(jsonb_build_object('roomId',piece)));
 INSERT INTO public.locations_actives(id,country,data) VALUES(idb,p_pays,bail);
 r:=public.prelever_loyer_bail(idb);
 IF r NOT IN('paye','ignore_sans_loyer') THEN RAISE EXCEPTION 'premier_loyer_refuse';END IF;
 FOR nouveau IN SELECT value FROM jsonb_array_elements(p_etat->'subdivisions') LOOP
  lots:=lots||jsonb_build_array(CASE WHEN nouveau->>'id'=p_lot THEN nouveau||jsonb_build_object('locataire',p_acteur) ELSE nouveau END);
 END LOOP;
 RETURN p_etat||jsonb_build_object('subdivisions',lots,'lotsHistorique',coalesce(p_etat->'lotsHistorique','[]')||jsonb_build_array(jsonb_build_object('acte','location','acteur',p_acteur,'lot',p_lot,'bail',idb,'premierLoyer',loyer,'date',statement_timestamp())));
END;$f$;
CREATE OR REPLACE FUNCTION public.location_lot_ecriture_attester() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
BEGIN
 IF public.est_appel_serveur() THEN RETURN NEW;END IF;
 IF left(coalesce(NEW.data->>'roomId',''),8)<>'lot_dyn_' AND (TG_OP='INSERT' OR left(coalesce(OLD.data->>'roomId',''),8)<>'lot_dyn_') THEN RETURN NEW;END IF;
 -- L'option d'affichage du locataire reste modifiable ; aucun montant ni jour de paiement.
 IF TG_OP='UPDATE' AND (NEW.id,NEW.country,NEW.data-'visible') IS NOT DISTINCT FROM (OLD.id,OLD.country,OLD.data-'visible') THEN RETURN NEW;END IF;
 IF EXISTS(SELECT 1 FROM public.chantier_commandes_recus r JOIN public.personnages_donnees p ON p.id=r.personnage_id
  WHERE p.name=public.mon_personnage() AND r.acteur=p.name AND r.commande->>'action'='louer'
   AND r.resultat->>'transaction_id'=txid_current()::text AND r.resultat->>'bail_id'=NEW.id AND r.resultat->>'interne'='location_lot') THEN RETURN NEW;END IF;
 RAISE EXCEPTION 'location_commande_versionnee_requise' USING ERRCODE='42501';
END;$f$;
DROP TRIGGER IF EXISTS location_lot_ecriture_attestee ON public.locations_actives;
CREATE TRIGGER location_lot_ecriture_attestee BEFORE INSERT OR UPDATE ON public.locations_actives FOR EACH ROW EXECUTE FUNCTION public.location_lot_ecriture_attester();
REVOKE ALL ON FUNCTION public.location_lot_enregistrer_interne(jsonb,text,text,text,text,integer),public.location_lot_ecriture_attester() FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
