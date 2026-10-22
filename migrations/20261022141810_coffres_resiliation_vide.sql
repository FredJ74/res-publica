-- #69 PREPAREE. Resiliation volontaire vide : meme moteur commun de terminaison du bail.
-- Les successions restent bloquees tant que leur raccordement complet n'est pas livre.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_resiliation_verifier_interne(text,text,text)');
IF h IS NOT NULL AND h<>'0b28b7cf100491890e6a0669382e9c1c' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_resiliation_verifier_interne';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.coffre_resiliation_verifier_interne(p_bail text,p_cause text,p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE c public.coffres_bancaires;p uuid;n text:=public.mon_personnage();
BEGIN
 SELECT * INTO c FROM public.coffres_bancaires WHERE bail_id=p_bail FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',true);END IF;
 SELECT id INTO p FROM public.personnages_donnees WHERE name=n;
 IF p IS NULL OR c.titulaire_id IS DISTINCT FROM p OR p_acteur IS DISTINCT FROM n THEN RETURN jsonb_build_object('ok',false,'raison','coffre_inaccessible');END IF;
 IF p_cause IS DISTINCT FROM 'resiliation_volontaire' OR c.succession_id IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison','coffre_succession_non_raccordee');END IF;
 IF jsonb_array_length(c.contenu)>0 THEN RETURN jsonb_build_object('ok',false,'raison','coffre_non_vide');END IF;
 RETURN jsonb_build_object('ok',true,'coffre',c.id);
END;$f$;
REVOKE ALL ON FUNCTION public.coffre_resiliation_verifier_interne(text,text,text) FROM PUBLIC,anon,authenticated,service_role;

DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.terminer_bail(text,text,text,integer)');
IF h='e2e707871b0f6c97945730980ac9d35c' THEN
s:=replace(s,$a0$  v_locataire text;$a0$,$b0$  v_locataire text;
  v_coffre jsonb;$b0$);
s:=replace(s,$a1$  v_locataire := v_bail ->> 'locataire';$a1$,$b1$  v_locataire := v_bail ->> 'locataire';
  v_coffre:=public.coffre_resiliation_verifier_interne(p_bail_id,p_cause,p_acteur);
  IF NOT coalesce((v_coffre->>'ok')::boolean,false) THEN RETURN v_coffre;END IF;$b1$);
s:=replace(s,$a2$  INSERT INTO locations_archives$a2$,$b2$  -- Apres tous les refus metier, avec l'archive et le bail dans la meme transaction.
  IF v_coffre ? 'coffre' THEN DELETE FROM public.coffres_bancaires WHERE id=(v_coffre->>'coffre')::uuid;END IF;
  INSERT INTO locations_archives$b2$);
EXECUTE s;
ELSIF h IS DISTINCT FROM '2366def87109ec56312a74196705d4e4' THEN RAISE EXCEPTION 'definition_non_examinee: terminer_bail';END IF;
END;$p$;
COMMIT;
