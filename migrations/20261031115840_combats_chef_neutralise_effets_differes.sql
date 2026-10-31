-- #219 NON APPLIQUEE. Chef à zéro PA : le groupe continue sans dissolution.
-- Les conséquences militaires existantes sont différées jusqu'à sa sortie effective.
DO $extraire$
DECLARE s text;corps text;debut integer;fin integer;
BEGIN
 IF to_regprocedure('public.militaire_bataille_neutralisation_terminale_interne(bigint,jsonb,integer)') IS NOT NULL THEN RETURN;END IF;
 SELECT prosrc INTO s FROM pg_proc WHERE oid='public.militaire_bataille_appliquer(bigint,jsonb,integer)'::regprocedure;
 debut:=position('      v_camp_mutin := public.mutinerie_camp_de' IN s);
 fin:=position(E'    ELSE\n      IF v_pnj IS NOT NULL THEN PERFORM public.pnj_mourir' IN s);
 IF debut=0 OR fin<=debut THEN RAISE EXCEPTION 'neutralisation_terminale_corps_non_examine';END IF;
 corps:=substring(s FROM debut FOR fin-debut);
 EXECUTE format('CREATE OR REPLACE FUNCTION public.militaire_bataille_neutralisation_terminale_interne(p_bataille_id bigint,act jsonb,p_round integer) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',
 'DECLARE v_camp_mutin text;v_b record;v_ville_prison text;v_det jsonb;BEGIN SELECT pays,ville INTO v_b FROM public.batailles WHERE id=p_bataille_id;'||corps||'END;');
 -- Une seule implémentation des suites militaires, différée ou immédiate.
 s:=overlay(s placing '      PERFORM public.militaire_bataille_neutralisation_terminale_interne(p_bataille_id,act,p_round);' FROM debut FOR fin-debut);
 debut:=position('    CONTINUE WHEN v_new > 0;' IN s);
 IF debut=0 THEN RAISE EXCEPTION 'neutralisation_PA_non_examinee';END IF;
 corps:=$c$
    CONTINUE WHEN v_new > 0;
    -- Le chef garde sa position et son groupe tant que d'autres combattants du
    -- groupe sont engagés. Pas de départ à l'infirmerie emportant ses suiveurs.
    IF (act->>'cib_pj')::boolean AND EXISTS(
      SELECT 1 FROM public.batailles_groupes g JOIN public.batailles_engagements e
      ON e.bataille_id=g.bataille_id AND e.groupe_id=g.groupe_id
      WHERE g.bataille_id=p_bataille_id AND g.leader=act->>'cib_nom'
      AND e.id<>(act->>'cib_eng')::bigint AND e.sorti_round IS NULL) THEN
     UPDATE public.batailles_engagements SET sorti_round=p_round,etat_final='neutralise' WHERE id=(act->>'cib_eng')::bigint;
     UPDATE public.batailles SET contexte=jsonb_set(contexte,'{neutralisations_differees}',
       coalesce(contexte->'neutralisations_differees','[]'::jsonb)||jsonb_build_array(act||jsonb_build_object('round_terminal',p_round))) WHERE id=p_bataille_id;
     CONTINUE;
    END IF;
$c$;
 s:=overlay(s placing corps FROM debut FOR length('    CONTINUE WHEN v_new > 0;'));
 EXECUTE 'CREATE OR REPLACE FUNCTION public.militaire_bataille_appliquer(p_bataille_id bigint,p_actions jsonb,p_round integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS '||quote_literal(s);
END $extraire$;
REVOKE ALL ON FUNCTION public.militaire_bataille_neutralisation_terminale_interne(bigint,jsonb,integer) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.militaire_bataille_finaliser_neutralisations_interne(p_bataille bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE b public.batailles%ROWTYPE;x jsonb;reste jsonb:='[]'::jsonb;
BEGIN
 SELECT * INTO b FROM public.batailles WHERE id=p_bataille FOR UPDATE;
 FOR x IN SELECT value FROM jsonb_array_elements(coalesce(b.contexte->'neutralisations_differees','[]'::jsonb)) LOOP
  IF b.statut='terminee' OR NOT EXISTS(SELECT 1 FROM public.batailles_engagements e JOIN public.batailles_engagements chef
    ON chef.bataille_id=e.bataille_id AND chef.groupe_id=e.groupe_id
    WHERE chef.id=(x->>'cib_eng')::bigint AND e.sorti_round IS NULL) THEN
   PERFORM public.militaire_bataille_neutralisation_terminale_interne(p_bataille,x,(x->>'round_terminal')::integer);
  ELSE reste:=reste||jsonb_build_array(x);END IF;
 END LOOP;
 IF b.contexte ? 'neutralisations_differees' THEN
 UPDATE public.batailles SET contexte=jsonb_set(contexte,'{neutralisations_differees}',reste) WHERE id=p_bataille;END IF;
END $g$;
REVOKE ALL ON FUNCTION public.militaire_bataille_finaliser_neutralisations_interne(bigint) FROM PUBLIC,anon,authenticated,service_role;
DO $fin$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_round(bigint)'::regprocedure);
 IF position('-- combat_fin_neutralisations_v1' IN s)>0 THEN RETURN;END IF;
 a:='  RETURN jsonb_build_object(''ok'', true, ''round'', v_round, ''surprise'', v_surprise,';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'neutralisations_fin_round_non_examinee';END IF;
 EXECUTE replace(s,a,' -- combat_fin_neutralisations_v1'||chr(10)||' PERFORM public.militaire_bataille_finaliser_neutralisations_interne(p_bataille_id);'||chr(10)||a);
END $fin$;

-- Une reddition ou une sortie terminale peut terminer le combat sans nouveau round.
DO $avancer$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_avancer(bigint)'::regprocedure);
 IF position('-- neutralisations_fin_avancer_v1' IN s)>0 THEN RETURN;END IF;
 a:='    RETURN jsonb_build_object(''ok'', true, ''terminee'', true, ''camps_debout'', v_debout);';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'neutralisations_fin_avancer_non_examinee';END IF;
 EXECUTE replace(s,a,' -- neutralisations_fin_avancer_v1'||chr(10)||' PERFORM public.militaire_bataille_finaliser_neutralisations_interne(p_bataille_id);'||chr(10)||a);
END $avancer$;
