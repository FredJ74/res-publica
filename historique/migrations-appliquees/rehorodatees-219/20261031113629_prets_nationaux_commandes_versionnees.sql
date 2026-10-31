-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261024121900_prets_nationaux_commandes_versionnees.sql ; aucun changement de règle.
-- Produits existants : travaux ; consommation 1000-10000, 12 %, jours 5/10/15/20/25/30.
BEGIN;
DO $nouveau$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='pret_national_contracter_versionne' AND (p.oid IS DISTINCT FROM to_regprocedure('public.pret_national_contracter_versionne(numeric,integer,text,text,uuid)') OR md5(p.prosrc)<>'cfad09914e5e02be426d674d3d1ab66c')) THEN RAISE EXCEPTION 'definition_non_examinee: pret_national_contracter_versionne';END IF;END;$nouveau$;

CREATE OR REPLACE FUNCTION public.pret_national_contracter_versionne(p_montant numeric,p_duree_jours integer,p_type_pret text,p_building_id text,p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();p record;ancien record;r jsonb;cout jsonb;param jsonb:=jsonb_build_array(p_montant,p_duree_jours,p_type_pret,p_building_id);solde numeric;
BEGIN
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie');END IF;
 IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_absente');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 SELECT * INTO ancien FROM public.prets_nationaux_demandes WHERE acteur=moi AND requete=p_requete;
 IF FOUND THEN
  IF ancien.parametres IS DISTINCT FROM param THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  r:=ancien.resultat||'{"rejeu":true}';
 ELSE
  IF p.country IS DISTINCT FROM 'republic' OR p.current_building IS DISTINCT FROM 'banque-nationale' OR p_building_id IS DISTINCT FROM p.current_building
   OR coalesce(p.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(moi))
   OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place_ou_indisponible');END IF;
  IF p_type_pret IS NULL OR p_type_pret NOT IN('travaux','consommation') THEN RETURN jsonb_build_object('ok',false,'raison','produit_invalide');END IF;
  -- La creation souleve en cas de refus : la sous-transaction annule aussi le PA.
  BEGIN
   INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,p.country||'_banque-nationale','emprunter',1,0);
   r:=public.pret_national_creer_interne(moi,p_montant,p_duree_jours,p_type_pret,p.current_building,p_requete::text);
   cout:=public.payer_ordre(moi,'emprunter',1,0);
   IF cout->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING MESSAGE=coalesce(cout->>'raison','paiement_refuse');END IF;
   DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;
   INSERT INTO public.prets_nationaux_demandes VALUES(moi,p_requete,param,r);
  EXCEPTION WHEN raise_exception THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);END;
 END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 SELECT cb.solde INTO solde FROM public.comptes_bancaires cb WHERE cb.personnage=moi AND cb.banque='nationale';
 RETURN r||jsonb_build_object('pa',p.pa,'arg',p.arg,'liquide',p.liquide,'solde_banque',solde);
END;$f$;
REVOKE ALL ON FUNCTION public.pret_national_contracter_versionne(numeric,integer,text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pret_national_contracter_versionne(numeric,integer,text,text,uuid) TO authenticated;
COMMIT;
