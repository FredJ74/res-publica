-- Inscription : un compte dont l'adresse n'est pas encore confirmée joue immédiatement sur l'appareil où il a été créé
-- (retour testeur du 20/11/2026, demande de Fred). Rappel de conception (creation.js, validerIdentifiants ; auth.js,
-- rpAuthSecuriserCompte) : la session est ouverte, puis l'adresse et le mot de passe sont posés sur le même compte ;
-- la confirmation ne sert qu'à se reconnecter plus tard ou depuis un autre appareil.
--
-- Cause : depuis le 17/11 (migration 20261117020000, « il faut un compte et s'identifier »), mon_personnage(),
-- est_mon_personnage() et ia_quota_consommer() refusent tout jeton `is_anonymous`. Or GoTrue garde ce drapeau tant que
-- l'adresse n'est pas confirmée : le personnage tout juste créé n'appartenait plus à personne (403 à l'entrée du jeu).
-- Correctif : est accepté un jeton non anonyme, OU un compte qui a déjà posé un mot de passe et une adresse (en attente
-- ou confirmée). Le compte purement anonyme, visé par l'audit du 16/11, reste refusé.
-- Idempotente (raccords marqués compte_identifiants_20261120). Essayée d'abord dans une transaction annulée.
BEGIN;

CREATE OR REPLACE FUNCTION public.compte_identifiants_poses_interne()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
      OR EXISTS (SELECT 1 FROM auth.users u
                  WHERE u.id = auth.uid() AND coalesce(u.encrypted_password, '') <> ''
                    AND (coalesce(u.email_change, '') <> '' OR coalesce(u.email, '') <> ''));
$$;
REVOKE ALL ON FUNCTION public.compte_identifiants_poses_interne() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.compte_identifiants_poses_interne() TO authenticated;

DO $mig$
DECLARE v_def text; v_new text; f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['public.mon_personnage()', 'public.est_mon_personnage(text)'] LOOP
    v_def := pg_get_functiondef(f::regprocedure);
    CONTINUE WHEN position('compte_identifiants_20261120' IN v_def) > 0;
    v_new := replace(v_def, $a$coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false$a$,
                     $n$public.compte_identifiants_poses_interne() /* compte_identifiants_20261120 */$n$);
    IF v_new = v_def THEN RAISE EXCEPTION 'raccord non appliqué : %', f; END IF;
    EXECUTE v_new;
  END LOOP;
  v_def := pg_get_functiondef('public.ia_quota_consommer()'::regprocedure);
  IF position('compte_identifiants_20261120' IN v_def) = 0 THEN
    v_new := replace(v_def, $a$IF coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) THEN$a$,
                     $n$IF NOT public.compte_identifiants_poses_interne() /* compte_identifiants_20261120 */ THEN$n$);
    IF v_new = v_def THEN RAISE EXCEPTION 'raccord non appliqué : ia_quota_consommer'; END IF;
    EXECUTE v_new;
  END IF;
END $mig$;

COMMIT;
