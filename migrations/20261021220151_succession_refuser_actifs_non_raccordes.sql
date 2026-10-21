-- PREPAREE #69. Aucun transfert ni appel de succession dans le DDL.
BEGIN;
DO $patch$ DECLARE h text;s text;BEGIN
 SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.succession_regler(text)');
 IF h='3da95e25ac0241c7226c8e041834539a' THEN
  s:=replace(s,$avant$    BEGIN
      IF (v_d ->> 'type') = 'terrain' THEN$avant$,$apres$    BEGIN
      -- #69 : jamais marquer un actif inconnu comme transmis sans moteur de transfert.
      IF coalesce(v_d->>'type','') NOT IN('terrain','entreprise','argent') THEN
        RAISE EXCEPTION 'type_disposition_non_pris_en_charge:%',coalesce(v_d->>'type','absent');
      END IF;
      IF (v_d ->> 'type') = 'terrain' THEN$apres$);EXECUTE s;
 ELSIF h IS DISTINCT FROM '99761397541aa91a75f35fad1c2248f7' THEN RAISE EXCEPTION 'succession_definition_non_examinee';END IF;
END;$patch$;
COMMIT;
