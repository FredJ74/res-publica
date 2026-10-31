-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261024121400_prets_nationaux_moteur_credit_commun.sql ; aucun changement de règle.
-- Moteur dette + recu de credit + virement extrait de la definition vivante 8a08c456.
BEGIN;
DO $nouveau$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='pret_national_creer_interne' AND (p.oid IS DISTINCT FROM to_regprocedure('public.pret_national_creer_interne(text,numeric,integer,text,text,text,numeric)') OR md5(p.prosrc)<>'61843a3b08aa2da16fc4f1c0c5975ed4')) THEN RAISE EXCEPTION 'definition_non_examinee: pret_national_creer_interne';END IF;END;$nouveau$;

ALTER TABLE public.prets ADD COLUMN IF NOT EXISTS contrat_version integer;
CREATE TABLE IF NOT EXISTS public.prets_ecritures_internes(transaction_id bigint PRIMARY KEY);
ALTER TABLE public.prets_ecritures_internes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.prets_ecritures_internes FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE IF NOT EXISTS public.prets_nationaux_demandes (
 acteur text NOT NULL,requete uuid NOT NULL,parametres jsonb NOT NULL,resultat jsonb NOT NULL,PRIMARY KEY(acteur,requete));
ALTER TABLE public.prets_nationaux_demandes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.prets_nationaux_demandes FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.pret_national_creer_interne(p_nom text,p_montant numeric,p_duree_jours integer,p_type_pret text,p_building_id text,p_reference text,p_taux_capture numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE v_pj public.personnages_donnees%ROWTYPE;v_taux numeric;v_total numeric;v_mensualite numeric;v_id text;v_solde numeric;v_arg numeric;v_liquide numeric;ancien public.prets%ROWTYPE;
BEGIN
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=p_nom FOR UPDATE;
 IF NOT FOUND OR p_reference IS NULL THEN RAISE EXCEPTION 'acteur_ou_reference_absent';END IF;
 SELECT * INTO ancien FROM public.prets WHERE id='pret-national-'||p_reference FOR UPDATE;
 IF FOUND THEN
  IF (ancien.emprunteur,ancien.montant_initial,ancien.duree_jours,ancien.type_pret,ancien.building_id) IS DISTINCT FROM (p_nom,p_montant,p_duree_jours,p_type_pret,p_building_id) THEN RAISE EXCEPTION 'requete_reutilisee';END IF;
  RETURN jsonb_build_object('ok',true,'rejeu',true,'pret_id',ancien.id);
 END IF;
 IF p_montant IS NULL OR p_montant::text IN('NaN','Infinity','-Infinity') OR p_montant<>trunc(p_montant) OR p_montant<1000 OR p_duree_jours IS NULL OR p_duree_jours<=0
 OR p_type_pret NOT IN('travaux','consommation','immobilier') OR p_type_pret IS NULL
 OR (p_type_pret='travaux' AND (p_montant>1000000 OR p_duree_jours NOT IN(10,15,20,25,30)))
 OR (p_type_pret='consommation' AND (p_montant>10000 OR p_duree_jours NOT IN(5,10,15,20,25,30)))
 OR (p_type_pret='immobilier' AND p_montant>150000) THEN RAISE EXCEPTION 'parametres_pret_invalides';END IF;
 IF EXISTS(SELECT 1 FROM public.prets WHERE emprunteur=p_nom AND type_pret=p_type_pret AND statut='en_cours') THEN RAISE EXCEPTION 'pret_deja_actif';END IF;
 SELECT solde INTO v_solde FROM public.comptes_bancaires WHERE personnage=p_nom AND banque='nationale' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'compte_national_absent';END IF;

 IF v_solde IS NULL OR v_solde<>trunc(v_solde) OR v_solde::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'compte_non_exploitable';END IF;
 INSERT INTO public.prets_ecritures_internes VALUES(txid_current()) ON CONFLICT DO NOTHING;
 v_taux:=CASE WHEN p_type_pret='consommation' THEN 12 ELSE coalesce(p_taux_capture,CASE WHEN v_pj.country='republic' THEN public.taux_pret_nationale(v_pj.country) ELSE (SELECT 5+(data->'indices'->v_pj.country->>'IE')::numeric/10 FROM public.terrain_actions_regles WHERE id) END) END;
 v_total:=round(p_montant*(1+v_taux/100));
 v_mensualite:=ceil(v_total/p_duree_jours);
 v_id:='pret-national-'||p_reference;
 INSERT INTO public.prets(id,emprunteur,country,building_id,type_banque,type_pret,montant_initial,montant_restant,duree_jours,mensualite,jours_impayes,jour_dernier_prelevement,statut,contrat_version)
 VALUES(v_id,p_nom,v_pj.country,p_building_id,'nationale',p_type_pret,p_montant,v_total,p_duree_jours,v_mensualite,0,(now() at time zone 'Europe/Paris')::date::text,'en_cours',2);
 INSERT INTO public.fonds_credits_uniques(acteur,source,reference,ordre,montant) VALUES(p_nom,'pret_national',v_id,CASE WHEN p_type_pret='travaux' THEN 'emprunter_construction' ELSE 'emprunter' END,p_montant);
 UPDATE public.comptes_bancaires SET solde=solde+p_montant,updated_at=now() WHERE personnage=p_nom AND banque='nationale' RETURNING solde INTO v_solde;
 UPDATE public.personnages_donnees SET arg=COALESCE(arg,0)+p_montant,updated_at=now() WHERE name=p_nom RETURNING arg,COALESCE(liquide,0) INTO v_arg,v_liquide;
 DELETE FROM public.prets_ecritures_internes WHERE transaction_id=txid_current();
 RETURN jsonb_build_object('ok',true,'pret_id',v_id,'montant',p_montant,'solde_banque',v_solde,'arg',v_arg,'liquide',v_liquide);
END;$f$;
REVOKE ALL ON FUNCTION public.pret_national_creer_interne(text,numeric,integer,text,text,text,numeric) FROM PUBLIC,anon,authenticated,service_role;
DO $g$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.pret_national_contracter(numeric,integer,text,text)') AND md5(prosrc) IN('8a08c4561a32f8eafb3c03429fa63b38','5a7540c67ebe52c14f6db45a3dfa1b48')) THEN RAISE EXCEPTION 'definition_non_examinee: pret_national_contracter';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.pret_national_contracter(p_montant numeric, p_duree_jours integer, p_type_pret text, p_building_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_pj public.personnages_donnees%ROWTYPE; v_taux numeric; v_total numeric; v_mensualite numeric; v_id text; v_solde numeric; v_arg numeric; v_liquide numeric;
BEGIN
 RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');
 v_nom:=public.mon_personnage();
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent'); END IF;
 IF p_montant IS NULL OR p_montant<>trunc(p_montant) OR p_montant<1000 OR p_montant>1000000
    OR p_duree_jours NOT IN (10,15,20,25,30)
    OR p_type_pret <> 'travaux' OR v_pj.country<>'republic'
    OR v_pj.current_building <> 'banque-nationale' THEN
  RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');
 END IF;
 IF EXISTS(SELECT 1 FROM public.prets WHERE emprunteur=v_nom AND type_pret=p_type_pret AND statut='en_cours') THEN
  RETURN jsonb_build_object('ok',false,'raison','pret_deja_actif');
 END IF;
 SELECT solde INTO v_solde FROM public.comptes_bancaires WHERE personnage=v_nom AND banque='nationale' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','compte_national_absent'); END IF;
 RETURN public.pret_national_creer_interne(v_nom,p_montant,p_duree_jours,p_type_pret,v_pj.current_building,gen_random_uuid()::text);
END; $function$;
COMMIT;
