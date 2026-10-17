-- NON DEPLOYEE. Depend des francs exacts et du registre prive des recus.
-- Reutilise les huit circuits SQL existants, sans ressaisir tarifs, taux ou penalites.
BEGIN;
DO $definitions_preparees$
DECLARE r record; p pg_proc%rowtype;
BEGIN
 FOR r IN SELECT * FROM (VALUES ('hg_fin_helvetia(uuid,text,text,jsonb)','c60c018d70e1cae5309970de6868ea25')) t(signature,empreinte) LOOP
  SELECT * INTO p FROM pg_proc WHERE oid=to_regprocedure('public.'||r.signature);
  IF FOUND AND (md5(p.prosrc)<>r.empreinte OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']) THEN
   RAISE EXCEPTION 'definition financiere preexistante non examinee : %',r.signature;
  END IF;
 END LOOP;
END;
$definitions_preparees$;
DO $garde$
DECLARE r record; p pg_proc%rowtype;
BEGIN
 FOR r IN SELECT * FROM (VALUES ('accepter_accord_helvetia(text,text)','3a530ffb89368bbc7b053354a6cadbd9'),
('creer_placement_helvetia(text,numeric,text)','aa177188b4b2f074936334d18d526786'),
('creer_pret_helvetia(text,numeric,integer)','7b9ce809cd497b0517a0b4bf603badb3'),
('deposer_helvetia(text,numeric)','da0c91516befaf577d012f6439b6ed0c'),
('deposer_helvetia(text,numeric,text)','f5afaa279a4ac0ba2062818aa8f00bc9'),
('fermer_compte_helvetia(text,text)','8e6b28c146d2a55521585659ecc6b67f'),
('ouvrir_compte_helvetia(text)','8e69306fea7bd939738af46599fd1222'),
('rembourser_pret_helvetia_integral(text,text,jsonb)','95dda77b7fd42a1cb1a34b01ca287ded'),
('retirer_helvetia(text,numeric)','bf41a527d266f92e2e87c6884e2620bb'),
('retirer_helvetia(text,numeric,text)','06f2c75904a3c29ff38d5742b026f286')) AS t(signature,empreinte) LOOP
  SELECT * INTO p FROM pg_proc WHERE oid=to_regprocedure('public.'||r.signature);
  IF NOT FOUND OR md5(p.prosrc)<>r.empreinte OR NOT p.prosecdef
    OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp'] THEN
   RAISE EXCEPTION 'Helvetia : definition serveur non examinee : %',r.signature;
  END IF;
 END LOOP;
END;
$garde$;
CREATE OR REPLACE FUNCTION public.hg_fin_helvetia(p_requete uuid,p_personnage text,p_operation text,p_arguments jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE v_etat jsonb; v_corps jsonb; v_recu public.hg_fin_requetes%rowtype;
 v_p public.personnages_donnees%rowtype; v_resultat jsonb; v_montant numeric;
 v_ordre text; v_pa integer; v_paiement jsonb; v_source jsonb;
BEGIN
 IF p_requete IS NULL OR p_operation NOT IN ('ouvrir','deposer','retirer','fermer','placer','emprunter','rembourser','accord')
  OR p_operation IS NULL OR p_arguments IS NULL OR jsonb_typeof(p_arguments)<>'object' THEN
  RAISE EXCEPTION 'requete_financiere_invalide' USING ERRCODE='22023';
 END IF;
 v_etat:=public.hg_fin_etat(p_personnage);
 v_corps:=jsonb_build_object('operation','helvetia_'||p_operation,'personnage',p_personnage,'arguments',p_arguments);
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_requete::text,0));
 SELECT * INTO v_recu FROM public.hg_fin_requetes WHERE utilisateur=auth.uid() AND requete=p_requete;
 IF FOUND THEN
  IF v_corps IS DISTINCT FROM v_recu.corps THEN RAISE EXCEPTION 'requete_reutilisee' USING ERRCODE='22023'; END IF;
  RETURN jsonb_build_object('ok',true,'resultat',v_recu.resultat,'etat',public.hg_fin_etat(p_personnage),'rejeu',true);
 END IF;
 SELECT * INTO v_p FROM public.personnages_donnees WHERE name=p_personnage FOR UPDATE;
 IF v_p.current_building IS DISTINCT FROM 'banque-privee' OR v_p.current_room IS DISTINCT FROM 'bureau_prive' THEN
  RAISE EXCEPTION 'presence_banque_privee_requise' USING ERRCODE='42501';
 END IF;
 IF p_operation IN ('deposer','retirer','placer','emprunter') THEN
  v_montant:=public.hg_fr_lire(p_arguments->'montant');
  IF v_montant<=0 THEN RAISE EXCEPTION 'montant_positif_requis' USING ERRCODE='22023'; END IF;
 END IF;
 IF p_operation='emprunter' AND v_montant<>trunc(v_montant) THEN
  -- Capital entier : regle historique du formulaire de pret, pas arrondi implicite.
  RAISE EXCEPTION 'capital_entier_requis' USING ERRCODE='22023';
 END IF;
 IF p_operation='rembourser' THEN
  IF jsonb_typeof(p_arguments->'sources') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'sources_invalides'; END IF;
  FOR v_source IN SELECT * FROM jsonb_array_elements(p_arguments->'sources') LOOP
   IF public.hg_fr_lire(v_source->'montant')<=0 THEN RAISE EXCEPTION 'montant_positif_requis'; END IF;
  END LOOP;
 END IF;
 v_ordre:=CASE WHEN p_operation='emprunter' THEN 'emprunter_prive'
  WHEN p_operation='placer' AND p_arguments->>'type'='offshore' THEN 'compte_offshore' ELSE 'gerer_finances' END;
 v_pa:=CASE WHEN p_operation='emprunter' THEN 1 ELSE 0 END;
 v_paiement:=public.payer_ordre(p_personnage,v_ordre,v_pa,0);
 IF (v_paiement->>'ok')::boolean IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'ordre_refuse: %',v_paiement->>'raison';
 END IF;
 INSERT INTO public.hg_fin_actes_en_cours(transaction_id,personnage) VALUES(txid_current(),p_personnage);
 CASE p_operation
 WHEN 'ouvrir' THEN SELECT to_jsonb(r) INTO v_resultat FROM public.ouvrir_compte_helvetia(p_personnage) r;
 WHEN 'deposer' THEN SELECT to_jsonb(r) INTO v_resultat FROM public.deposer_helvetia(p_personnage,v_montant,p_arguments->>'source') r;
 WHEN 'retirer' THEN SELECT to_jsonb(r) INTO v_resultat FROM public.retirer_helvetia(p_personnage,v_montant,p_arguments->>'destination') r;
 WHEN 'fermer' THEN v_resultat:=public.fermer_compte_helvetia(p_personnage,p_arguments->>'destination');
 WHEN 'placer' THEN SELECT to_jsonb(r) INTO v_resultat FROM public.creer_placement_helvetia(p_personnage,v_montant,p_arguments->>'type') r;
 WHEN 'emprunter' THEN SELECT to_jsonb(r) INTO v_resultat FROM public.creer_pret_helvetia(p_personnage,v_montant,(p_arguments->>'duree')::integer) r;
 WHEN 'rembourser' THEN SELECT to_jsonb(r) INTO v_resultat FROM public.rembourser_pret_helvetia_integral(p_personnage,p_arguments->>'pret_id',p_arguments->'sources') r;
 WHEN 'accord' THEN SELECT to_jsonb(r) INTO v_resultat FROM public.accepter_accord_helvetia(p_personnage,p_arguments->>'pret_id') r;
 END CASE;
 DELETE FROM public.hg_fin_actes_en_cours WHERE transaction_id=txid_current() AND personnage=p_personnage;
 IF v_resultat IS NULL OR v_resultat->'ok'='false'::jsonb THEN RAISE EXCEPTION 'operation_helvetia_refusee'; END IF;
 -- Toute erreur levee apres le paiement annule aussi les PA et toutes les contreparties.
 -- Aucun montant numeric issu des anciennes fonctions ne traverse le transport JSON.
 v_resultat:=jsonb_build_object('operation',p_operation,'id',v_resultat->'id');
 INSERT INTO public.hg_fin_requetes(utilisateur,requete,personnage,corps,resultat)
 VALUES(auth.uid(),p_requete,p_personnage,v_corps,v_resultat);
 RETURN jsonb_build_object('ok',true,'resultat',v_resultat,'etat',public.hg_fin_etat(p_personnage),'rejeu',false);
END;
$function$;
REVOKE ALL ON FUNCTION public.hg_fin_helvetia(uuid,text,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.hg_fin_helvetia(uuid,text,text,jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.accepter_accord_helvetia(text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.creer_placement_helvetia(text,numeric,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.creer_pret_helvetia(text,numeric,integer) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.deposer_helvetia(text,numeric) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.deposer_helvetia(text,numeric,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.fermer_compte_helvetia(text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.ouvrir_compte_helvetia(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.rembourser_pret_helvetia_integral(text,text,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.retirer_helvetia(text,numeric) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.retirer_helvetia(text,numeric,text) FROM PUBLIC,anon,authenticated;
COMMIT;
