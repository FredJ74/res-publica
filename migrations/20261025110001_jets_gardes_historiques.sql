-- Fermeture conditionnelle des chemins historiques, après tous les autres composants L09.
-- Aucune transition activée ici. L'exécution personnelle absente reste un prévol bloquant.
BEGIN;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='vol_legacy_inserer_garder' AND (p.oid IS DISTINCT FROM to_regprocedure('public.vol_legacy_inserer_garder()') OR md5(p.prosrc)<>'de1559503812c7e02c1b2a6dd313a86d')) THEN RAISE EXCEPTION 'definition_non_examinee: vol_legacy_inserer_garder';END IF;END;$g$;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='ordres_jets_refuser_legacy' AND (p.oid IS DISTINCT FROM to_regprocedure('public.ordres_jets_refuser_legacy(text,text)') OR md5(p.prosrc)<>'04fd5be79b924186f9f1cbeef88ea567')) THEN RAISE EXCEPTION 'definition_non_examinee: ordres_jets_refuser_legacy';END IF;END;$g$;
CREATE OR REPLACE FUNCTION public.ordres_jets_refuser_legacy(p_acteur text,p_famille text) RETURNS boolean
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path=public,pg_temp AS $f$
 SELECT coalesce(public.rp_transition_active('actes_jets_atomiques_'||(SELECT country FROM public.personnages_donnees WHERE name=p_acteur)),false)
 AND NOT EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=p_acteur AND ordre=p_famille);
$f$;
REVOKE ALL ON FUNCTION public.ordres_jets_refuser_legacy(text,text) FROM PUBLIC,anon,authenticated,service_role;
DO $g$ DECLARE r record;h text;d text;BEGIN
 FOR r IN SELECT * FROM (VALUES ('payer_ordre(text,text,integer,integer)','3cf9d168a28282c318adf3f35b94c07c','934b2e64eacc9b523df67d0d4ce89edf','
 IF v_fn IN(''voler'',''mener_enquete'',''organiser_filature'',''organiser_chasse_homme'',''voler_materiel_chantier'',''tentative_evasion'',''demander_benediction_contact'') AND public.ordres_jets_refuser_legacy(p_acteur,v_fn) THEN RETURN jsonb_build_object(''ok'',false,''raison'',''commande_jet_atomique_requise'');END IF;'),
('filature_deplacements(text)','b93a5077febbf222371e0649f681f694','ec15c16173abbc0fbe60a80d4451ec8e','
 IF public.ordres_jets_refuser_legacy(public.mon_personnage(),''organiser_filature'') THEN RETURN jsonb_build_object(''ok'',false,''raison'',''commande_jet_atomique_requise'');END IF;'),
('commissaire_enqueter(text)','96672907a1e2628f4a0ffd80d03ad3bf','1211502a5541b6c3fc30d2247f9cd63f','
 IF public.ordres_jets_refuser_legacy(public.mon_personnage(),''mener_enquete'') THEN RETURN jsonb_build_object(''ok'',false,''raison'',''commande_jet_atomique_requise'');END IF;'),
('justice_executer_condamnation(text,text)','1362571c3e469fdd7161ce3dec8f99c3','75e960bc5686153650e4ff4ba20ce28e','
 IF public.ordres_jets_refuser_legacy(public.mon_personnage(),''organiser_chasse_homme'') THEN RETURN jsonb_build_object(''ok'',false,''raison'',''commande_jet_atomique_requise'');END IF;'),
('detention_clore_evasion()','99bbebe32b7277b8590b916ec6e0b072','937ea9e89a4cad215c952ae6f6f26078','
 IF public.ordres_jets_refuser_legacy(public.mon_personnage(),''tentative_evasion'') THEN RETURN jsonb_build_object(''ok'',false,''raison'',''commande_jet_atomique_requise'');END IF;'),
('terrain_chantier_acte(text,text,text,integer,integer)','e607ff4dff0b68c3c3abca87a35e8d0a','e0c62602049f7f8e9bddb45a865f202f','
 IF p_acte=''chantier_materiaux_voler'' AND public.ordres_jets_refuser_legacy(public.mon_personnage(),''voler_materiel_chantier'') THEN RETURN jsonb_build_object(''ok'',false,''raison'',''commande_jet_atomique_requise'');END IF;'),
('commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)','3b1a95240f0adb8234a1b6d3752444d1','324eb7a589d8180a7f5c9f4bb9d56c82','
 IF p_mode=''marche_noir'' AND public.ordres_jets_refuser_legacy(p_acteur,''choisir_arme'') THEN RETURN jsonb_build_object(''ok'',false,''raison'',''commande_jet_atomique_requise'');END IF;')) t(signature,ancien,nouveau,insertion) LOOP
  IF to_regprocedure('public.'||r.signature) IS NULL THEN CONTINUE;END IF;
  SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.'||r.signature);
  IF h=r.nouveau THEN CONTINUE;END IF;
  IF h IS DISTINCT FROM r.ancien THEN RAISE EXCEPTION 'definition_non_examinee: %',r.signature;END IF;
  d:=overlay(d placing 'BEGIN'||r.insertion FROM position('BEGIN' IN d) FOR 5);EXECUTE d;
  SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.'||r.signature);
  IF h IS DISTINCT FROM r.nouveau THEN RAISE EXCEPTION 'garde_jet_non_confirmee: %',r.signature;END IF;
 END LOOP;
END;$g$;
CREATE OR REPLACE FUNCTION public.vol_legacy_inserer_garder() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
BEGIN
 IF public.rp_transition_active('actes_jets_atomiques_'||(SELECT country FROM public.personnages_donnees WHERE name=public.mon_personnage())) THEN RAISE EXCEPTION 'commande_jet_atomique_requise';END IF;
 RETURN NEW;
END;$f$;
REVOKE ALL ON FUNCTION public.vol_legacy_inserer_garder() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS vol_legacy_inserer_garder ON public.vols_en_attente;
CREATE TRIGGER vol_legacy_inserer_garder BEFORE INSERT ON public.vols_en_attente FOR EACH ROW EXECUTE FUNCTION public.vol_legacy_inserer_garder();
COMMIT;
