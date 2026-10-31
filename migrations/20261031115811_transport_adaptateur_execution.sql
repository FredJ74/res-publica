-- #219 : réutiliser la même exécution judiciaire sans substituer un JWT.
-- Corps historique retrouvé à bfae7cf0 ; ne pas le prétendre relevé vivant.
DO $prevol$
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.justice_executer_condamnation_soi(text)'::regprocedure)
 NOT IN ('00334c44320507c0acd0c60d24c61d1b','9bf0dd138d93d0da67b99022d63b81d2') THEN RAISE EXCEPTION 'execution_judiciaire_vivante_non_examinee';END IF;
 IF to_regprocedure('public.douane_condamnation_executer_interne(text,text)') IS NOT NULL
 AND (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.douane_condamnation_executer_interne(text,text)'))<>'7f8704792b8abb6e66233292295d019f'
 THEN RAISE EXCEPTION 'execution_judiciaire_interne_non_examinee';END IF;
END $prevol$;
CREATE OR REPLACE FUNCTION public.douane_condamnation_executer_interne(p_jugement_id text,p_nom text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acteur text;
  v_j public.jugements%ROWTYPE;
  v_city text;
  v_jours integer;
  v_res jsonb;
BEGIN
  v_acteur := p_nom;
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_authentifie');
  END IF;
  SELECT current_city INTO v_city FROM public.personnages_donnees WHERE name = v_acteur;
  IF v_city IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ville_inconnue');
  END IF;
  SELECT * INTO v_j FROM public.jugements
   WHERE id = p_jugement_id AND accuse = v_acteur FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'condamnation_non_autorisee');
  END IF;
  IF v_j.executee THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_executee');
  END IF;
  IF EXISTS (SELECT 1 FROM public.detention_active(v_acteur)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_detenu');
  END IF;
  SELECT coalesce(sum((m->>'jours')::integer),0) INTO v_jours
    FROM jsonb_array_elements(coalesce(v_j.data->'motifs','[]'::jsonb)) m;
  IF v_jours <= 0 THEN v_jours := 3; END IF;
  v_res := public.detention_ouvrir_interne(
    v_acteur, coalesce(v_j.motif,'Condamnation'), v_jours,
    v_city, v_j.country, coalesce(v_j.data->'motifs','[]'::jsonb),
    'interception_policiere', coalesce(v_j.data->>'issue_judiciaire','condamnation_executee'));
  IF NOT coalesce((v_res->>'ok')::boolean,false) THEN RETURN v_res; END IF;
  UPDATE public.jugements SET executee = true WHERE id = v_j.id;
  RETURN jsonb_build_object('ok',true,'jours',v_jours,'detention_id',v_res->>'detention_id',
    'motif',coalesce(v_j.motif,'Condamnation'));
END;
$function$;
REVOKE ALL ON FUNCTION public.douane_condamnation_executer_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.justice_executer_condamnation_soi(p_jugement_id text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $function$
 SELECT public.douane_condamnation_executer_interne(p_jugement_id,public.mon_personnage());
$function$;
