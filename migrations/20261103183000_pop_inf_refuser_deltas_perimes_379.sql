-- HG #379 : garde serveur contre les deltas POP/INF issus d'un ancien navigateur.
-- Ce lot est un garde de concurrence. Il ne dispense pas de raccorder les
-- producteurs restants, ni de fermer finalement les écritures client.
-- Prévol : ne remplacer que le corps vivant exact certifié le 03/11/2026.
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
        THEN (OLD.resources ->> 'pop')::numeric ELSE v_base END;
      v_nouveau := (NEW.resources ->> 'pop')::numeric;
      IF v_old IS DISTINCT FROM v_base AND v_nouveau IS DISTINCT FROM v_base THEN
        -- Une réponse perdue, ou deux onglets, rendraient cet effet ambigu.
        -- Refuser la sauvegarde ENTIÈRE, sans consommer un gain legitimement non confirme.
        RAISE EXCEPTION '379_pop_base_perimee' USING ERRCODE='40001';
      END IF;
      NEW.resources := jsonb_set(NEW.resources,'{pop}',
        to_jsonb(greatest(0,least(100,v_old+(v_nouveau-v_base)))));
    END IF;
  ELSIF TG_OP='UPDATE' AND v_client AND jsonb_typeof(NEW.resources)='object' THEN
    IF jsonb_typeof(OLD.resources -> 'pop')='number' THEN
      NEW.resources := jsonb_set(NEW.resources,'{pop}',OLD.resources -> 'pop');
    ELSE
      NEW.resources := NEW.resources - 'pop';
    END IF;
  END IF;

  -- INF : meme contrôle, sans exception qui permettrait un delta ancien.
  IF jsonb_typeof(NEW.resources)='object' AND NEW.resources ? 'infBase' THEN
    IF jsonb_typeof(NEW.resources -> 'infBase') IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION '379_inf_base_invalide' USING ERRCODE='22023';
    END IF;
    v_base := (NEW.resources ->> 'infBase')::numeric;
    NEW.resources := NEW.resources - 'infBase';
    IF TG_OP='UPDATE' AND jsonb_typeof(NEW.resources -> 'inf')='number' THEN
      v_old := CASE WHEN jsonb_typeof(OLD.resources -> 'inf')='number'
        THEN (OLD.resources ->> 'inf')::numeric ELSE v_base END;
      v_nouveau := (NEW.resources ->> 'inf')::numeric;
      IF v_old IS DISTINCT FROM v_base AND v_nouveau IS DISTINCT FROM v_base THEN
        RAISE EXCEPTION '379_inf_base_perimee' USING ERRCODE='40001';
      END IF;
      NEW.resources := jsonb_set(NEW.resources,'{inf}',
        to_jsonb(greatest(0,least(100,v_old+(v_nouveau-v_base)))));
    END IF;
  ELSIF TG_OP='UPDATE' AND v_client AND jsonb_typeof(NEW.resources)='object' THEN
    IF jsonb_typeof(OLD.resources -> 'inf')='number' THEN
      NEW.resources := jsonb_set(NEW.resources,'{inf}',OLD.resources -> 'inf');
    ELSE
      NEW.resources := NEW.resources - 'inf';
    END IF;
  END IF;
  RETURN NEW;
END $f$;
