-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261024135353_acquisition_refus_rollback_financement.sql ; aucun changement de règle.
-- Un refus de paiement après décision du prêt annule aussi le crédit et la dette de cette commande.
BEGIN;
DO $g$ DECLARE h text;d text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.terrain_acquisition_commande(text,text,jsonb,uuid)');
IF h='b2eacb6bff248ed3f0393f09cd44c4cc' THEN
d:=replace(d,$a$IF r->>'ok' IS DISTINCT FROM 'true' THEN DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;RETURN r;END IF;$a$,$b$IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(r->>'raison','paiement_refuse');END IF;$b$);
d:=replace(d,$a$ RETURN r;
END;$a$,$b$ RETURN r;
EXCEPTION WHEN SQLSTATE 'P0135' THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);
END;$b$);EXECUTE d;
ELSIF h IS DISTINCT FROM '8f6231f8bebc11dedba9fb05b3b30a4f' THEN RAISE EXCEPTION 'definition_non_examinee: terrain_acquisition_commande rollback';END IF;END;$g$;
COMMIT;
