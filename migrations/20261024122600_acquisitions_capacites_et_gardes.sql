-- Capacite privee de transaction, jamais accessible au navigateur.
BEGIN;
CREATE TABLE IF NOT EXISTS public.acquisitions_transactions_internes(transaction_id bigint,acteur text,terrain text,ordre text,pa integer,montant integer,PRIMARY KEY(transaction_id,acteur));
ALTER TABLE public.acquisitions_transactions_internes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.acquisitions_transactions_internes FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE IF NOT EXISTS public.terrain_acquisitions_recus(acteur text,requete uuid,terrain text,action text,parametres jsonb,resultat jsonb,PRIMARY KEY(acteur,requete));
ALTER TABLE public.terrain_acquisitions_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.terrain_acquisitions_recus FROM PUBLIC,anon,authenticated,service_role;
DO $g$ DECLARE h text;d text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.payer_ordre(text,text,integer,integer)');
IF h='9a461bfc3c33f04f342ce6f5586393a7' THEN
d:=replace(d,$a$  v_connu boolean;$a$,$b$  v_acquisition boolean;
  v_connu boolean;$b$);
d:=replace(d,$a$  PERFORM public.exiger_acteur(p_acteur);$a$,$b$  PERFORM public.exiger_acteur(p_acteur);
  v_acquisition:=EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes a WHERE a.transaction_id=txid_current() AND a.acteur=p_acteur AND ((a.ordre=v_fn AND a.pa=p_pa AND a.montant=p_cost) OR (a.ordre='signer_compromis' AND v_fn='deposer_demande_permis' AND p_pa=0 AND p_cost=0)));
  IF v_fn IN('acheter_terrain','signer_compromis','acte_vente_terrain','emprunter') AND NOT v_acquisition THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;$b$);
d:=replace(d,$a$IF NOT v_connu THEN$a$,$b$IF NOT v_connu AND NOT v_acquisition THEN$b$);
d:=replace(d,$a$IF NOT v_valide THEN$a$,$b$IF NOT v_valide AND NOT v_acquisition THEN$b$);
EXECUTE d;
ELSIF h='d2bb47bf851552799397beba72a2a400' THEN
d:=replace(d,$a$  v_connu boolean;$a$,$b$  v_acquisition boolean;
  v_connu boolean;$b$);
d:=replace(d,$a$  PERFORM public.exiger_acteur(p_acteur);$a$,$b$  PERFORM public.exiger_acteur(p_acteur);
  v_acquisition:=EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes a WHERE a.transaction_id=txid_current() AND a.acteur=p_acteur AND ((a.ordre=v_fn AND a.pa=p_pa AND a.montant=p_cost) OR (a.ordre='signer_compromis' AND v_fn='deposer_demande_permis' AND p_pa=0 AND p_cost=0)));
  IF v_fn IN('acheter_terrain','signer_compromis','acte_vente_terrain','emprunter') AND NOT v_acquisition THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;$b$);
d:=replace(d,$a$IF NOT v_connu THEN$a$,$b$IF NOT v_connu AND NOT v_acquisition THEN$b$);
d:=replace(d,$a$IF NOT v_valide THEN$a$,$b$IF NOT v_valide AND NOT v_acquisition THEN$b$);
EXECUTE d;
ELSIF h IS NULL OR h NOT IN('3cf9d168a28282c318adf3f35b94c07c','a246e5b56df06285700eab9bec0dcc0b') THEN RAISE EXCEPTION 'definition_non_examinee: public.payer_ordre(text,text,integer,integer)';END IF;END;$g$;
DO $g$ DECLARE h text;d text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.terrain_compromis_acte(text,text,jsonb)');
IF h='17e26d10e1fb5585d5f5e60a0e816b68' THEN
d:=replace(d,$a$  v_moi := public.mon_personnage();$a$,$b$  v_moi := public.mon_personnage();
  IF p_acte IN('compromis_signer','achat_direct_deposer') AND NOT EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes a WHERE a.transaction_id=txid_current() AND a.acteur=v_moi) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;$b$);
d:=replace(d,$a$  v_etat := v_lu -> 'etat';$a$,$b$  v_etat := v_lu -> 'etat';
  IF p_acte='compromis_pret_demander' AND v_etat->>'proprietaire' IS DISTINCT FROM 'Helvetia' AND NOT EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes a WHERE a.transaction_id=txid_current() AND a.acteur=v_moi) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;$b$);
EXECUTE d;
ELSIF h IS NULL OR h NOT IN('673a2eee7b8ad0a9876f31c7da9ace44') THEN RAISE EXCEPTION 'definition_non_examinee: public.terrain_compromis_acte(text,text,jsonb)';END IF;END;$g$;
DO $g$ DECLARE h text;d text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.terrain_proprietaire_muter(text,text,jsonb,text)');
IF h='df5c90d592cc16812eb0d139d8ead87b' THEN
d:=replace(d,$a$  v_moi := public.mon_personnage();$a$,$b$  v_moi := public.mon_personnage();
  IF p_titre IN('compromis','achat_direct') AND NOT EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes a WHERE a.transaction_id=txid_current() AND a.acteur=v_moi) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;$b$);
EXECUTE d;
ELSIF h IS NULL OR h NOT IN('0a0a91b7c89e0aa832ad0b369f1b2bdb') THEN RAISE EXCEPTION 'definition_non_examinee: public.terrain_proprietaire_muter(text,text,jsonb,text)';END IF;END;$g$;
DO $g$ DECLARE h text;d text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.terrain_permis_deposer(text,text,uuid)');
IF h='2e0c9a32aa2b9c71b47fbc961caa9f01' THEN
d:=replace(d,$a$paiement:=public.payer_ordre(acteur,'deposer_demande_permis',1,100);$a$,$b$IF EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes a WHERE a.transaction_id=txid_current() AND a.acteur=public.mon_personnage() AND a.terrain=pays||'_'||p_terrain AND a.ordre='signer_compromis') THEN
 paiement:=public.payer_ordre(acteur,'deposer_demande_permis',0,0);
 ELSE paiement:=public.payer_ordre(acteur,'deposer_demande_permis',1,100);END IF;$b$);
EXECUTE d;
ELSIF h IS NULL OR h NOT IN('0bf19e5ac706ee5d329b419b9f0c1a07') THEN RAISE EXCEPTION 'definition_non_examinee: public.terrain_permis_deposer(text,text,uuid)';END IF;END;$g$;
COMMIT;
