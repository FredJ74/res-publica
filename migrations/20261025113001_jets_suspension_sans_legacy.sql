-- Une suspension ne rouvre jamais les anciennes portes. Aucun état de bascule modifié.
BEGIN;
DO $g$ DECLARE h text;BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.ordres_jets_refuser_legacy(text,text)');IF h IS NULL OR h NOT IN('04fd5be79b924186f9f1cbeef88ea567','bc9db040058c5f9147160a95b6a4e955') THEN RAISE EXCEPTION 'definition_non_examinee: ordres_jets_refuser_legacy';END IF;END;$g$;
CREATE OR REPLACE FUNCTION public.ordres_jets_refuser_legacy(p_acteur text,p_famille text) RETURNS boolean
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path=public,pg_temp AS $f$
 SELECT EXISTS(SELECT 1 FROM public.rp_transitions WHERE cle='actes_jets_atomiques_'||(SELECT country FROM public.personnages_donnees WHERE name=p_acteur))
 AND NOT EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=p_acteur AND ordre=p_famille);
$f$;
DO $g$ DECLARE h text;BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.vol_legacy_inserer_garder()');IF h IS NULL OR h NOT IN('de1559503812c7e02c1b2a6dd313a86d','120a24e7c9617b1b73c183a7236a2501') THEN RAISE EXCEPTION 'definition_non_examinee: vol_legacy_inserer_garder';END IF;END;$g$;
CREATE OR REPLACE FUNCTION public.vol_legacy_inserer_garder() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
BEGIN
 IF EXISTS(SELECT 1 FROM public.rp_transitions WHERE cle='actes_jets_atomiques_'||(SELECT country FROM public.personnages_donnees WHERE name=public.mon_personnage())) THEN RAISE EXCEPTION 'commande_jet_atomique_requise';END IF;
 RETURN NEW;
END;$f$;
COMMIT;
