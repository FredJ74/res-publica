-- BROUILLON I18N — NE PAS APPLIQUER EN PRODUCTION, NE PAS FUSIONNER
-- avant la revue RLS, les essais PostgreSQL annulés et l'accord du game designer.
-- Ce fichier n'est PAS dans migrations/. Quota désactivé par défaut.
-- Le lecteur est vérifié AVANT ces RPC par l'API sous son JWT + RLS.
-- Service_role n'est employé qu'au cache et aux compteurs internes.
BEGIN;

CREATE TABLE IF NOT EXISTS public.rp_i18n_configuration (
 singleton integer PRIMARY KEY DEFAULT 1 CHECK (singleton=1),
 enabled boolean NOT NULL DEFAULT false,
 daily_requests integer NOT NULL DEFAULT 0 CHECK (daily_requests>=0),
 daily_characters integer NOT NULL DEFAULT 0 CHECK (daily_characters>=0),
 updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.rp_i18n_configuration(singleton,enabled,daily_requests,daily_characters)
 VALUES (1,false,0,0) ON CONFLICT(singleton) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.rp_i18n_cache (
 cache_key text PRIMARY KEY CHECK(cache_key ~ '^[0-9a-f]{64}$'),
 translated_text text NOT NULL CHECK(length(translated_text) BETWEEN 1 AND 4000),
 created_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL DEFAULT (now()+interval '7 days')
);
CREATE INDEX IF NOT EXISTS rp_i18n_cache_expiry
 ON public.rp_i18n_cache(expires_at);

CREATE TABLE IF NOT EXISTS public.rp_i18n_usage (
 uid uuid NOT NULL,
 usage_day date NOT NULL,
 request_count integer NOT NULL DEFAULT 0 CHECK(request_count>=0),
 character_count bigint NOT NULL DEFAULT 0 CHECK(character_count>=0),
 PRIMARY KEY(uid,usage_day)
);
CREATE TABLE IF NOT EXISTS public.rp_i18n_reservations (
 uid uuid NOT NULL,
 usage_day date NOT NULL,
 cache_key text NOT NULL CHECK(cache_key ~ '^[0-9a-f]{64}$'),
 characters integer NOT NULL CHECK(characters BETWEEN 1 AND 1800),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(uid,usage_day,cache_key),
 FOREIGN KEY(uid,usage_day) REFERENCES public.rp_i18n_usage(uid,usage_day) ON DELETE CASCADE
);

-- Les tables ne contiennent jamais les originaux des joueurs.
-- En défense profonde : aucune policy cliente, RLS sur toutes les tables.
ALTER TABLE public.rp_i18n_configuration ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rp_i18n_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rp_i18n_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rp_i18n_reservations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rp_i18n_configuration,public.rp_i18n_cache,
 public.rp_i18n_usage,public.rp_i18n_reservations FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.rp_i18n_configuration,
 public.rp_i18n_cache,public.rp_i18n_usage,public.rp_i18n_reservations TO service_role;

-- Aucun privilège supplémentaire pour l'utilisateur final.
-- Contrainte de quota atomique et idempotente dans la transaction SQL :
-- même UID+jour+texte ne peut déclencher qu'UNE réservation ce jour-là.
CREATE OR REPLACE FUNCTION public.rp_i18n_budget_reserver(
 p_uid uuid,p_cache_key text,p_characters integer
) RETURNS boolean LANGUAGE plpgsql SECURITY INVOKER
 SET search_path=pg_catalog,public AS $$
DECLARE
 v_day date := (clock_timestamp() AT TIME ZONE 'UTC')::date;
 v_enabled boolean;
 v_max_calls integer;
 v_max_chars integer;
 v_calls integer;
 v_chars bigint;
BEGIN
 IF p_uid IS NULL OR p_cache_key IS NULL OR
    p_cache_key !~ '^[0-9a-f]{64}$' OR p_characters IS NULL OR
    p_characters NOT BETWEEN 1 AND 1800 THEN
  RETURN false;
 END IF;
 SELECT enabled,daily_requests,daily_characters
 INTO v_enabled,v_max_calls,v_max_chars
 FROM public.rp_i18n_configuration WHERE singleton=1;
 IF NOT FOUND OR v_enabled IS DISTINCT FROM true OR v_max_calls<=0 OR v_max_chars<=0 THEN
  RETURN false; -- désactivé par défaut
 END IF;
 INSERT INTO public.rp_i18n_usage(uid,usage_day,request_count,character_count)
 VALUES(p_uid,v_day,0,0) ON CONFLICT(uid,usage_day) DO NOTHING;
 SELECT request_count,character_count INTO v_calls,v_chars
 FROM public.rp_i18n_usage WHERE uid=p_uid AND usage_day=v_day FOR UPDATE;
 IF NOT FOUND THEN RETURN false; END IF;
 IF EXISTS(SELECT 1 FROM public.rp_i18n_reservations
           WHERE uid=p_uid AND usage_day=v_day AND cache_key=p_cache_key) THEN
  RETURN false; -- jamais de second appel payant sur la même clé le même jour
 END IF;
 IF v_calls>=v_max_calls OR v_chars+p_characters>v_max_chars THEN
  RETURN false;
 END IF;
 UPDATE public.rp_i18n_usage SET request_count=v_calls+1,
  character_count=v_chars+p_characters WHERE uid=p_uid AND usage_day=v_day;
 INSERT INTO public.rp_i18n_reservations(uid,usage_day,cache_key,characters)
 VALUES(p_uid,v_day,p_cache_key,p_characters);
 RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.rp_i18n_cache_lire(p_cache_key text)
RETURNS text LANGUAGE sql STABLE SECURITY INVOKER
SET search_path=pg_catalog,public AS $$
 SELECT translated_text FROM public.rp_i18n_cache
 WHERE cache_key=p_cache_key AND expires_at>now()
 LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.rp_i18n_cache_ecrire(p_cache_key text,p_text text)
RETURNS boolean LANGUAGE plpgsql SECURITY INVOKER
SET search_path=pg_catalog,public AS $$
BEGIN
 IF p_cache_key IS NULL OR p_cache_key !~ '^[0-9a-f]{64}$' OR
    p_text IS NULL OR length(trim(p_text))=0 OR length(p_text)>4000 THEN
  RETURN false;
 END IF;
 INSERT INTO public.rp_i18n_cache(cache_key,translated_text,expires_at)
 VALUES(p_cache_key,p_text,now()+interval '7 days')
 ON CONFLICT(cache_key) DO UPDATE SET translated_text=EXCLUDED.translated_text,
  expires_at=EXCLUDED.expires_at;
 RETURN true;
END;
$$;

-- Les RPC dans public ne doivent PAS être appelables depuis un JWT client.
REVOKE ALL ON FUNCTION public.rp_i18n_budget_reserver(uuid,text,integer) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.rp_i18n_cache_lire(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.rp_i18n_cache_ecrire(text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.rp_i18n_budget_reserver(uuid,text,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.rp_i18n_cache_lire(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.rp_i18n_cache_ecrire(text,text) TO service_role;

COMMIT;
-- Étapes non exécutées : essais PostgreSQL transactionnels annulés,
-- test en isolation contre appels simultanés, RLS/ACL vérifiées,
-- coût réel DeepSeek, purge des lignes expirées, configuration des limites.
-- NE PAS ACTIVER l'API HTTP tant que ces preuves et l'autorisation manquent.
