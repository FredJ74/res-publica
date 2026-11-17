-- Fin du jeu anonyme et plafond d'appels à l'IA (failles de l'audit du 16/11/2026, décision de Fred du 17/11 :
-- « il faut un compte et s'identifier »).
--
-- 1. `mon_personnage()` et `est_mon_personnage()` ne reconnaissent plus un compte anonyme (jeton
--    `is_anonymous = true`) : aucun ordre, vote, don ni commerce n'est possible tant que l'adresse n'est
--    pas confirmée. La création du personnage et sa lecture restent possibles (politique `user_id = auth.uid()`),
--    pour que l'écran puisse demander la confirmation du compte.
-- 2. `ia_appels_jour` + `ia_quota_consommer()` : chaque compte confirmé dispose de 300 appels à l'IA par jour
--    (dialogues des PNJ, rédaction, conférences, aide, renseignements). Au-delà, la route refuse poliment.
--
-- Idempotente : patchs marqués `compte_confirme_20261117`, table en IF NOT EXISTS, fonction en CREATE OR REPLACE.

DO $mig$
DECLARE v_def text; v_new text; f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['public.mon_personnage()', 'public.est_mon_personnage(text)'] LOOP
    v_def := pg_get_functiondef(f::regprocedure);
    IF position('compte_confirme_20261117' in v_def) > 0 THEN
      CONTINUE;
    END IF;
    v_new := replace(v_def, $a$p.user_id = auth.uid()$a$,
      $n$p.user_id = auth.uid() /* compte_confirme_20261117 */ AND coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false$n$);
    IF v_new = v_def THEN
      RAISE EXCEPTION 'patch non applique : % ne contient pas le fragment attendu', f;
    END IF;
    EXECUTE v_new;
  END LOOP;
END $mig$;

CREATE TABLE IF NOT EXISTS public.ia_appels_jour (
  user_id uuid NOT NULL,
  jour    date NOT NULL,
  appels  integer NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, jour)
);
ALTER TABLE public.ia_appels_jour ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.ia_appels_jour FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.ia_appels_jour TO service_role;

CREATE OR REPLACE FUNCTION public.ia_quota_consommer()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_plafond constant integer := 300;
  v_uid uuid := auth.uid();
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_non_confirme');
  END IF;
  INSERT INTO public.ia_appels_jour (user_id, jour, appels) VALUES (v_uid, v_jour, 1)
  ON CONFLICT (user_id, jour) DO UPDATE SET appels = public.ia_appels_jour.appels + 1
  RETURNING appels INTO v_n;
  IF v_n > c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quota_ia_atteint', 'plafond', c_plafond);
  END IF;
  RETURN jsonb_build_object('ok', true, 'appels', v_n, 'plafond', c_plafond);
END;
$function$;

REVOKE ALL ON FUNCTION public.ia_quota_consommer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ia_quota_consommer() TO authenticated, service_role;
