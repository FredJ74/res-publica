-- HG #379 : garde serveur contre les deltas POP/INF issus d'un ancien navigateur.
-- Ce lot est un garde de concurrence. Il ne dispense pas de raccorder les
-- producteurs restants, ni de fermer finalement les Ã©critures client.
-- PrÃ©vol : ne remplacer que le corps vivant exact certifiÃ© le 03/11/2026.
DO $prevol$
BEGIN
 IF NOT EXISTS(
   SELECT 1 FROM pg_proc
   WHERE oid='public.personnages_fusionner_pop()'::regprocedure
     AND md5(prosrc)='248b3f7f5e8c24148afa624649ee3f47'
 ) THEN
   RAISE EXCEPTION '379_fusion_pop_definition_divergente';
 END IF;
END $prevol$;

CREATE OR REPLACE FUNCTION public.personnages_fusionner_pop()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO public,pg_temp
AS $f$
DECLARE
  v_base numeric;
  v_old numeric;
  v_nouveau numeric;
  v_client boolean := NOT public.est_appel_serveur()
    AND coalesce(current_setting('request.path', true),'') NOT LIKE '/rpc/%';
BEGIN
  -- POP : le delta n'est applicable qu'a la photographie reellement lue.
  IF jsonb_typeof(NEW.resources) = 'object' AND NEW.resources ? 'popBase' THEN
    IF jsonb_typeof(NEW.resources -> 'popBase') IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION '379_pop_base_invalide' USING ERRCODE='22023';
    END IF;
    v_base := (NEW.resources ->> 'popBase')::numeric;
    NEW.resources := NEW.resources - 'popBase';
    IF TG_OP = 'UPDATE' AND jsonb_typeof(NEW.resources -> 'pop')='number' THEN
      v_old := CASE WHEN jsonb_typeof(OLD.resources -> 'pop')='number'
    ¶»§q«^