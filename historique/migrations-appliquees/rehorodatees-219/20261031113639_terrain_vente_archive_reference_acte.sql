-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261024133310_terrain_vente_archive_reference_acte.sql ; aucun changement de règle.
-- Deux ventes légitimes du même terrain au même acheteur le même jour restent distinctes.
BEGIN;
DO $g$ DECLARE h text;d text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.terrain_proprietaire_muter(text,text,jsonb,text)');
IF h='0a0a91b7c89e0aa832ad0b369f1b2bdb' THEN d:=replace(d,$a$|| '-' || v_nouveau,$a$,$b$|| '-' || v_nouveau || '-' || coalesce(nullif(p_reference,''),'historique'),$b$);EXECUTE d;
ELSIF h IS DISTINCT FROM 'e3a763458ff1dd0ae30d65b52105ead8' THEN RAISE EXCEPTION 'definition_non_examinee: terrain_proprietaire_muter archive';END IF;END;$g$;
COMMIT;
