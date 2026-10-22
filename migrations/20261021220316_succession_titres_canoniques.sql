-- PREPAREE #66 : coherence du titre lors du reglement successoral commun.
-- Compatible avec la garde #69 si celle-ci est installee en premier, sans la retirer.
BEGIN;
DO $patch$ DECLARE h text;s text;BEGIN
 SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.succession_regler(text)');
 IF h IN('3da95e25ac0241c7226c8e041834539a','99761397541aa91a75f35fad1c2248f7') THEN
  s:=replace(s,$avant$        SELECT t.id, t.data::jsonb INTO v_tid, v_etat FROM public.terrains_etat t
         WHERE t.country = s.country AND t.building_id = (v_d ->> 'id') FOR UPDATE;$avant$,$apres$        -- Pas de premier resultat arbitraire lorsque plusieurs villes partagent un buildingId.
        PERFORM 1 FROM public.terrains_etat t WHERE t.country=s.country AND
          ((nullif(v_d->>'terrain_id','') IS NOT NULL AND t.id=v_d->>'terrain_id') OR
           (nullif(v_d->>'terrain_id','') IS NULL AND t.building_id=v_d->>'id' AND
             (nullif(v_d->>'ville','') IS NULL OR t.data::jsonb->>'city'=v_d->>'ville'))) ORDER BY t.id FOR UPDATE;
        SELECT count(*) INTO v_n FROM public.terrains_etat t WHERE t.country=s.country AND
          ((nullif(v_d->>'terrain_id','') IS NOT NULL AND t.id=v_d->>'terrain_id') OR
           (nullif(v_d->>'terrain_id','') IS NULL AND t.building_id=v_d->>'id' AND
             (nullif(v_d->>'ville','') IS NULL OR t.data::jsonb->>'city'=v_d->>'ville')));
        IF v_n<>1 THEN RAISE EXCEPTION 'titre_successoral_absent_ou_ambigu';END IF;
        SELECT t.id,t.data::jsonb INTO v_tid,v_etat FROM public.terrains_etat t WHERE t.country=s.country AND
          ((nullif(v_d->>'terrain_id','') IS NOT NULL AND t.id=v_d->>'terrain_id') OR
           (nullif(v_d->>'terrain_id','') IS NULL AND t.building_id=v_d->>'id' AND
             (nullif(v_d->>'ville','') IS NULL OR t.data::jsonb->>'city'=v_d->>'ville')));
        IF coalesce(v_etat->>'proprietaire','') NOT IN(s.defunt,'pj:'||s.defunt) THEN RAISE EXCEPTION 'titre_successoral_titulaire_modifie';END IF;$apres$);
  s:=replace(s,$avant$UPDATE public.terrains_etat SET data = v_etat::text, updated_at = now() WHERE id = v_tid;$avant$,$apres$UPDATE public.terrains_etat SET proprietaire=v_benef, data = v_etat::text, updated_at = now() WHERE id = v_tid;$apres$);
  EXECUTE s;
 ELSIF h IS NULL OR h NOT IN('f8c0193cc9618943706b9a3dc03b7434','92eed313b268bfb297526ef516191e94') THEN RAISE EXCEPTION 'succession_titres_definition_non_examinee';END IF;
END;$patch$;
COMMIT;
