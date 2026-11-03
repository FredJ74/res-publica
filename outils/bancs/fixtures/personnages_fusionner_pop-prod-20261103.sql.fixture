-- Document de contre-épreuve : fonction vivante lue le 03/11/2026.
-- md5(prosrc)=248b3f7f5e8c24148afa624649ee3f47. NE PAS DÉPLOYER.
CREATE OR REPLACE FUNCTION public.personnages_fusionner_pop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_base numeric;
  v_old  numeric;
  v_client boolean := NOT public.est_appel_serveur()
                       AND coalesce(current_setting('request.path', true), '') NOT LIKE '/rpc/%';
BEGIN
  IF jsonb_typeof(NEW.resources) = 'object' AND NEW.resources ? 'popBase' THEN
    v_base := CASE WHEN jsonb_typeof(NEW.resources -> 'popBase') = 'number' THEN (NEW.resources ->> 'popBase')::numeric END;
    NEW.resources := NEW.resources - 'popBase';
    IF TG_OP = 'UPDATE' AND v_base IS NOT NULL AND jsonb_typeof(NEW.resources -> 'pop') = 'number' THEN
      v_old := CASE WHEN jsonb_typeof(OLD.resources -> 'pop') = 'number' THEN (OLD.resources ->> 'pop')::numeric ELSE v_base END;
      NEW.resources := jsonb_set(NEW.resources, '{pop}',
        to_jsonb(GREATEST(0, LEAST(100, v_old + ((NEW.resources ->> 'pop')::numeric - v_base)))));
    END IF;
  ELSIF TG_OP = 'UPDATE' AND v_client AND jsonb_typeof(NEW.resources) = 'object' THEN
    -- Pas de base annoncee : le navigateur ne decide pas d'une valeur absolue.
    IF jsonb_typeof(OLD.resources -> 'pop') = 'number' THEN
      NEW.resources := jsonb_set(NEW.resources, '{pop}', OLD.resources -> 'pop');
    ELSE
      NEW.resources := NEW.resources - 'pop';
    END IF;
  END IF;

  IF jsonb_typeof(NEW.resources) = 'object' AND NEW.resources ? 'infBase' THEN
    v_base := CASE WHEN jsonb_typeof(NEW.resources -> 'infBase') = 'number' THEN (NEW.resources ->> 'infBase')::numeric END;
    NEW.resources := NEW.resources - 'infBase';
    IF TG_OP = 'UPDATE' AND v_base IS NOT NULL AND jsonb_typeof(NEW.resources -> 'inf') = 'number' THEN
      v_old := CASE WHEN jsonb_typeof(OLD.resources -> 'inf') = 'number' THEN (OLD.resources ->> 'inf')::numeric ELSE v_base END;
      NEW.resources := jsonb_set(NEW.resources, '{inf}',
        to_jsonb(GREATEST(0, LEAST(100, v_old + ((NEW.resources ->> 'inf')::numeric - v_base)))));
    END IF;
  ELSIF TG_OP = 'UPDATE' AND v_client AND jsonb_typeof(NEW.resources) = 'object' THEN
    IF jsonb_typeof(OLD.resources -> 'inf') = 'number' THEN
      NEW.resources := jsonb_set(NEW.resources, '{inf}', OLD.resources -> 'inf');
    ELSE
      NEW.resources := NEW.resources - 'inf';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$

