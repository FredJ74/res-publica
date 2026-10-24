-- Le cron service_role ne porte pas de personnage. Autoriser uniquement le document
-- d'urbanisme atteste par son archive ; conserver les gardes des autres motifs.
BEGIN;
DO $g$ DECLARE h text;d text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.objet_sas_deposer(text,text,jsonb,text)');
IF h='5be54b74273872b4bdd5302777d9fa7a' THEN
 d:=replace(d,'IF v_acteur IS NULL THEN',
 'IF v_acteur IS NULL AND NOT (coalesce(p_motif=''document_urbanisme'',false) AND coalesce(public.est_appel_serveur(),false)) THEN');EXECUTE d;
ELSIF h IS DISTINCT FROM 'c1d3cdf82694cd31d6aabe7496634d63' THEN RAISE EXCEPTION 'definition_non_examinee: objet_sas_deposer cron permis';END IF;
END;$g$;
COMMIT;
