-- #94 PREPAREE : les baux restent ceux du moteur de fonds existant, sans nouvelle vente.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.location_lot_ecriture_attester()');
IF h IS NULL OR h NOT IN('c15d550e95f1df4f842181ed4f879256','a8621c5cb90e72304e3652765f750c5e') THEN RAISE EXCEPTION 'definition_non_examinee: location_lot_ecriture_attester';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.location_lot_ecriture_attester() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE e jsonb;h jsonb;t jsonb;
BEGIN
 IF public.est_appel_serveur() THEN RETURN NEW;END IF;
 IF left(coalesce(NEW.data->>'roomId',''),8)<>'lot_dyn_' AND (TG_OP='INSERT' OR left(coalesce(OLD.data->>'roomId',''),8)<>'lot_dyn_') THEN RETURN NEW;END IF;
 -- L'option d'affichage du locataire reste modifiable ; aucun montant ni jour de paiement.
 IF TG_OP='UPDATE' AND (NEW.id,NEW.country,NEW.data-'visible') IS NOT DISTINCT FROM (OLD.id,OLD.country,OLD.data-'visible') THEN RETURN NEW;END IF;
 IF EXISTS(SELECT 1 FROM public.chantier_commandes_recus r JOIN public.personnages_donnees p ON p.id=r.personnage_id
  WHERE p.name=public.mon_personnage() AND r.acteur=p.name AND r.commande->>'action'='louer'
   AND r.resultat->>'transaction_id'=txid_current()::text AND r.resultat->>'bail_id'=NEW.id AND r.resultat->>'interne'='location_lot') THEN RETURN NEW;END IF;
 -- Les moteurs existants de creation/vente du fonds mettent a jour le meme bail.
 -- Ils sont attestes par l'entreprise canonique, jamais par les champs envoyes au bail.
 IF TG_OP='UPDATE' THEN
  SELECT data INTO e FROM public.entreprises WHERE id=NEW.data->>'fondsId' AND coalesce((data->>'version')::integer,0)>=2 AND data->>'type'='fonds_commerce'
   AND coalesce(data->>'statut','actif')='actif' AND data->'implantation'->>'bailId'=NEW.id
   AND data->'implantation'->>'country'=NEW.country AND data->'implantation'->>'city'=NEW.data->>'city'
   AND data->'implantation'->>'buildingId'=NEW.data->>'buildingId' AND data->'implantation'->>'roomId'=NEW.data->>'roomId' FOR SHARE;
  IF e IS NOT NULL AND regexp_replace(e->>'proprietaire','^pj:','')=regexp_replace(coalesce(NEW.data->>'locataireRef',NEW.data->>'locataire'),'^pj:','') THEN
   IF (NEW.id,NEW.country,NEW.data-ARRAY['visible','fondsId']) IS NOT DISTINCT FROM (OLD.id,OLD.country,OLD.data-ARRAY['visible','fondsId']) THEN RETURN NEW;END IF;
   h:=e->'historique'->-1;t:=NEW.data->'transferts'->-1;
   IF (NEW.id,NEW.country,NEW.data-ARRAY['locataire','locataireRef','transferts']) IS NOT DISTINCT FROM (OLD.id,OLD.country,OLD.data-ARRAY['locataire','locataireRef','transferts'])
    AND h->>'evenement'='vente' AND t->>'cause'='vente_fonds' AND t->>'de'=h->>'vendeur' AND t->>'vers'=h->>'acheteur'
    AND regexp_replace(h->>'vendeur','^pj:','')=regexp_replace(coalesce(OLD.data->>'locataireRef',OLD.data->>'locataire'),'^pj:','')
    AND regexp_replace(h->>'acheteur','^pj:','')=regexp_replace(coalesce(NEW.data->>'locataireRef',NEW.data->>'locataire'),'^pj:','')
    AND jsonb_array_length(NEW.data->'transferts')=jsonb_array_length(coalesce(OLD.data->'transferts','[]'))+1
    AND (NEW.data->'transferts')- (jsonb_array_length(NEW.data->'transferts')-1)=coalesce(OLD.data->'transferts','[]') THEN RETURN NEW;END IF;
  END IF;
 END IF;
 RAISE EXCEPTION 'location_commande_versionnee_requise' USING ERRCODE='42501';
END;$f$;
COMMIT;
