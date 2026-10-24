-- #94 PREPAREE : un local refuse ne peut consommer l'apport du createur. Moteur existant conserve.
BEGIN;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.creer_fonds_commerce(text,text,text,integer,text)');
IF h IN('b9f8d7f49bac391a9ed13157174f6456','049b15670cb9f660338ab7d20ac31192') THEN
s:=replace(s,$ancien$  IF v_apport > 0 THEN
    IF NOT mouvement_titulaire(p_proprietaire, -v_apport) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
    END IF;
  ELSE
    IF NOT mouvement_titulaire(p_proprietaire, 0) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'proprietaire_absent');
    END IF;
  END IF;
$ancien$,'');s:=replace(s,$point$  v_lot := v_bail ->> 'lotId';$point$,$nouveau$  IF v_apport > 0 THEN
    IF NOT mouvement_titulaire(p_proprietaire, -v_apport) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
    END IF;
  ELSE
    IF NOT mouvement_titulaire(p_proprietaire, 0) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'proprietaire_absent');
    END IF;
  END IF;
  v_lot := v_bail ->> 'lotId';$nouveau$);EXECUTE s;
ELSIF h IS NULL OR h NOT IN('7b4c66eefd3a9be4c2a3eb2fabb6de75','ffae9b5b3a886939aa540729bfd782ee') THEN RAISE EXCEPTION 'definition_non_examinee: creer_fonds_commerce';END IF;
END;$p$;
COMMIT;

