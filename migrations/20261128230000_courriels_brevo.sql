-- E-mails du jeu par Brevo (chantier 2 de Fred, 28/11/2026 au soir).
--   1. courriel_echecs : chaque échec d'envoi (clé absente, refusée ou expirée, refus de Brevo, panne) est consigné par le
--      serveur (courriel_echec_noter_service), une ligne par raison, avec un compteur ; la page MJ l'affiche en alerte
--      (admin_courriel_echecs_lire) jusqu'à ce que le MJ la marque comme lue (admin_courriel_echecs_acquitter).
--   2. Notification de sanction aussi par e-mail (adresse de réponse contact@human-gambit.com) :
--      admin_sanction_courriel_preparer rend l'adresse du joueur et le texte déjà posé en courrier, dans sa langue.
--   3. E-mail de test : à l'adresse du compte MJ (admin_courriel_test_adresse), ou par un jeton à usage unique posé en base
--      par l'exploitant (courriel_tests, dont l'adresse n'est jamais dans le dépôt) et lu par courriel_test_jeton_service.
-- Contrôle :
--   SELECT to_regclass('public.courriel_echecs') IS NOT NULL AND position('courriels_brevo_v1' in
--     pg_get_functiondef('public.courriel_echec_noter_service(text,text,text)'::regprocedure)) > 0;
BEGIN;

CREATE TABLE IF NOT EXISTS public.courriel_echecs (
  raison text PRIMARY KEY CHECK (length(raison) BETWEEN 1 AND 60),
  premier_le timestamptz NOT NULL DEFAULT now(),
  dernier_le timestamptz NOT NULL DEFAULT now(),
  compteur integer NOT NULL DEFAULT 1,
  dernier_contexte text,
  detail text,
  acquitte_le timestamptz
);
ALTER TABLE public.courriel_echecs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.courriel_echecs FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS public.courriel_tests (
  jeton_hash text PRIMARY KEY CHECK (jeton_hash ~ '^[0-9a-f]{64}$'),
  email text NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  expire_le timestamptz NOT NULL DEFAULT now() + interval '1 hour',
  utilise_le timestamptz,
  message_id text
);
ALTER TABLE public.courriel_tests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.courriel_tests FROM anon, authenticated;

-- Consigner un échec (serveur seulement). Une ligne par raison ; un échec après acquittement rouvre l'alerte.
CREATE OR REPLACE FUNCTION public.courriel_echec_noter_service(p_raison text, p_contexte text, p_detail text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
-- courriels_brevo_v1
DECLARE v_raison text := left(coalesce(nullif(btrim(p_raison), ''), 'inconnue'), 60);
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  INSERT INTO public.courriel_echecs AS e (raison, dernier_contexte, detail)
  VALUES (v_raison, left(p_contexte, 100), left(p_detail, 500))
  ON CONFLICT (raison) DO UPDATE SET
    dernier_le = now(),
    compteur = CASE WHEN e.acquitte_le IS NULL THEN e.compteur + 1 ELSE 1 END,
    premier_le = CASE WHEN e.acquitte_le IS NULL THEN e.premier_le ELSE now() END,
    dernier_contexte = excluded.dernier_contexte, detail = excluded.detail, acquitte_le = NULL;
  RETURN jsonb_build_object('ok', true);
END $$;

CREATE OR REPLACE FUNCTION public.admin_courriel_echecs_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true, 'echecs', coalesce((
    SELECT jsonb_agg(jsonb_build_object('raison', e.raison, 'premier_le', e.premier_le, 'dernier_le', e.dernier_le,
             'compteur', e.compteur, 'contexte', e.dernier_contexte, 'detail', e.detail) ORDER BY e.dernier_le DESC)
      FROM public.courriel_echecs e WHERE e.acquitte_le IS NULL), '[]'::jsonb));
END $$;

CREATE OR REPLACE FUNCTION public.admin_courriel_echecs_acquitter()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE n integer;
BEGIN
  PERFORM public.admin_exiger();
  UPDATE public.courriel_echecs SET acquitte_le = now() WHERE acquitte_le IS NULL;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'acquittes', n);
END $$;

-- Adresse et texte de la notification d'une sanction (déjà posée en courrier), dans la langue du compte.
CREATE OR REPLACE FUNCTION public.admin_sanction_courriel_preparer(p_id bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE s public.moderation_sanctions; v_email text; v_langue text; v_txt jsonb;
BEGIN
  PERFORM public.admin_exiger();
  SELECT * INTO s FROM public.moderation_sanctions WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'sanction_introuvable'); END IF;
  SELECT u.email INTO v_email FROM auth.users u WHERE u.id = s.user_id;
  IF coalesce(v_email, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'sans_adresse'); END IF;
  v_langue := public.juridique_langue_compte_interne(s.user_id);
  v_txt := public.moderation_notification_texte_interne(v_langue, s);
  RETURN jsonb_build_object('ok', true, 'email', v_email, 'langue', v_langue, 'sujet', 'Human Gambit — ' || (v_txt ->> 'sujet'),
    'texte', v_txt ->> 'corps');
END $$;

-- Adresse du compte MJ connecté (destinataire de l'e-mail de test lancé depuis la page MJ).
CREATE OR REPLACE FUNCTION public.admin_courriel_test_adresse()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_uid uuid := public.admin_exiger(); v_email text;
BEGIN
  SELECT u.email INTO v_email FROM auth.users u WHERE u.id = v_uid;
  IF coalesce(v_email, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'sans_adresse'); END IF;
  RETURN jsonb_build_object('ok', true, 'email', v_email);
END $$;

-- Jeton de test à usage unique (serveur seulement) : le jeton n'est stocké que haché (SHA-256).
--   p_message_id NULL : consommer le jeton pour un envoi (refusé s'il a déjà servi ou a expiré) ;
--   p_message_id non NULL : noter l'identifiant du message envoyé ;
--   p_lire : relire l'adresse et l'identifiant (vérification de livraison), jusqu'à 24 h après la création.
CREATE OR REPLACE FUNCTION public.courriel_test_jeton_service(p_jeton text, p_message_id text DEFAULT NULL, p_lire boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_hash text := encode(sha256(convert_to(coalesce(p_jeton, ''), 'UTF8')), 'hex'); t public.courriel_tests;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  IF length(coalesce(p_jeton, '')) < 32 THEN RETURN jsonb_build_object('ok', false, 'raison', 'jeton_invalide'); END IF;
  SELECT * INTO t FROM public.courriel_tests WHERE jeton_hash = v_hash FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'jeton_invalide'); END IF;
  IF p_lire THEN
    IF t.cree_le < now() - interval '24 hours' THEN RETURN jsonb_build_object('ok', false, 'raison', 'jeton_expire'); END IF;
    RETURN jsonb_build_object('ok', true, 'email', t.email, 'message_id', t.message_id);
  END IF;
  IF p_message_id IS NOT NULL THEN
    UPDATE public.courriel_tests SET message_id = left(p_message_id, 300) WHERE jeton_hash = v_hash;
    RETURN jsonb_build_object('ok', true);
  END IF;
  IF t.utilise_le IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'jeton_deja_utilise'); END IF;
  IF t.expire_le < now() THEN RETURN jsonb_build_object('ok', false, 'raison', 'jeton_expire'); END IF;
  UPDATE public.courriel_tests SET utilise_le = now() WHERE jeton_hash = v_hash;
  RETURN jsonb_build_object('ok', true, 'email', t.email);
END $$;

REVOKE ALL ON FUNCTION public.courriel_echec_noter_service(text, text, text), public.courriel_test_jeton_service(text, text, boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.courriel_echec_noter_service(text, text, text), public.courriel_test_jeton_service(text, text, boolean)
  TO service_role;
REVOKE ALL ON FUNCTION public.admin_courriel_echecs_lire(), public.admin_courriel_echecs_acquitter(),
  public.admin_sanction_courriel_preparer(bigint), public.admin_courriel_test_adresse() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_courriel_echecs_lire(), public.admin_courriel_echecs_acquitter(),
  public.admin_sanction_courriel_preparer(bigint), public.admin_courriel_test_adresse() TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
