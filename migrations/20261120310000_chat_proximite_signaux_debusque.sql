-- Retours des tests à deux comptes de Fred (20/11/2026).
--  1. Conversations : quand quelqu'un m'écrit (conversation directe, y compris avec un masqué sous son anonymat), un
--     signal sans nom (chat_signaux, lisible par moi seul, temps réel) fait apparaître le point rouge et la notification
--     cliquable. L'identifiant anonyme 'masque:<jeton>' est résolu ICI, jamais chez l'expéditeur.
--  2. Débusquage : l'événement dit aussi si le débusqué est masqué (il le reste) ; l'écran l'inscrit au journal.
--  3. Déplacements du MJ : le signal de position est déjà émis par le déclencheur de la table (zz_personnages_signaux,
--     migration 20261120280000), quelle que soit l'origine de la modification ; vérifié dans l'essai.
--  4. Conversations de PROXIMITÉ : un message direct n'est remis que si l'interlocuteur est dans la même pièce (ou la même
--     rue) au moment de l'envoi, d'après les positions réelles (chat_envoyer ; même contrôle dans la règle d'écriture).
--     Refus : 'interlocuteur_absent', sans jamais dire où il est allé. L'historique reste lisible.
-- Idempotente.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- 2. Débusquage : le débusqué masqué le reste.
SELECT pg_temp.rp_raccorder('public.crim_fouiller_cachettes()'::regprocedure,
  $a$CASE WHEN public.crim_masque_interne(a) THEN jsonb_build_object('par_masque', true) ELSE jsonb_build_object('par', a) END);$a$,
  $b$CASE WHEN public.crim_masque_interne(a) THEN jsonb_build_object('par_masque', true) ELSE jsonb_build_object('par', a) END
          || jsonb_build_object('vous_masque', v_masque)); /* retours_tests_debusque_v1 */$b$,
  'retours_tests_debusque_v1');

-- Participant d'une conversation directe → personnage (identifiant anonyme résolu au serveur).
CREATE OR REPLACE FUNCTION public.chat_personnage_de_interne(p_part text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN p_part LIKE 'masque:%'
              THEN (SELECT j.personnage FROM public.crim_jetons_masque j WHERE j.jeton::text = substr(p_part, 8))
              ELSE p_part END;
$$;
REVOKE ALL ON FUNCTION public.chat_personnage_de_interne(text) FROM PUBLIC, anon, authenticated;

-- 4. Même pièce (ou même rue) que mon interlocuteur, d'après les positions réelles.
CREATE OR REPLACE FUNCTION public.chat_co_presents_interne(p_conversation text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); alias text; p1 text := split_part(p_conversation, '__', 1);
  p2 text := split_part(p_conversation, '__', 2); autre text; a record; b record;
BEGIN
  IF moi IS NULL THEN RETURN false; END IF;
  alias := public.chat_alias_interne(moi);
  autre := CASE WHEN p1 IN (moi, coalesce(alias, '')) THEN p2 ELSE p1 END;
  autre := public.chat_personnage_de_interne(autre);
  IF autre IS NULL OR autre = moi THEN RETURN false; END IF;
  SELECT country, current_city, current_building, current_room, current_street INTO a FROM public.personnages_donnees WHERE name = moi;
  SELECT country, current_city, current_building, current_room, current_street INTO b FROM public.personnages_donnees WHERE name = autre;
  IF NOT FOUND THEN RETURN false; END IF;
  RETURN a.country IS NOT DISTINCT FROM b.country AND a.current_city IS NOT DISTINCT FROM b.current_city
     AND a.current_building IS NOT DISTINCT FROM b.current_building
     AND CASE WHEN a.current_building IS NULL THEN a.current_street IS NOT DISTINCT FROM b.current_street AND a.current_street IS NOT NULL
              ELSE a.current_room IS NOT DISTINCT FROM b.current_room END;
END $$;
GRANT EXECUTE ON FUNCTION public.chat_co_presents_interne(text) TO authenticated;

DROP POLICY IF EXISTS messages_chat_envoi ON public.messages_chat;
CREATE POLICY messages_chat_envoi ON public.messages_chat FOR INSERT
  WITH CHECK (auteur = public.chat_auteur_attendu_interne(conversation_id, salon) AND public.chat_participe(conversation_id, salon)
              AND (coalesce(salon, false) OR public.chat_co_presents_interne(conversation_id)));

-- Envoi d'un message : refus explicite si l'interlocuteur n'est plus là.
CREATE OR REPLACE FUNCTION public.chat_envoyer(p_conversation text, p_message text, p_salon boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); v_id text; v_msg text := left(btrim(coalesce(p_message, '')), 2000);
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_msg = '' OR coalesce(p_conversation, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'message_vide'); END IF;
  IF NOT public.chat_participe(p_conversation, p_salon) THEN RETURN jsonb_build_object('ok', false, 'raison', 'conversation_interdite'); END IF;
  IF NOT coalesce(p_salon, false) AND NOT public.chat_co_presents_interne(p_conversation) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'interlocuteur_absent');
  END IF;
  v_id := 'msg-' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint || '-' || substr(md5(random()::text), 1, 5);
  INSERT INTO public.messages_chat (id, conversation_id, auteur, message, salon, created_at)
  VALUES (v_id, p_conversation, public.chat_auteur_attendu_interne(p_conversation, p_salon), v_msg, coalesce(p_salon, false), now());
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END $$;
REVOKE ALL ON FUNCTION public.chat_envoyer(text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chat_envoyer(text, text, boolean) TO authenticated;

-- 1. Signal « on vous parle » : une ligne par destinataire, lisible par lui seul, publiée en temps réel.
CREATE TABLE IF NOT EXISTS public.chat_signaux (
  personnage text PRIMARY KEY, version bigint NOT NULL DEFAULT 1, maj timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.chat_signaux ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.chat_signaux FROM anon, authenticated;
GRANT SELECT ON public.chat_signaux TO authenticated;
DROP POLICY IF EXISTS chat_signaux_soi ON public.chat_signaux;
CREATE POLICY chat_signaux_soi ON public.chat_signaux FOR SELECT TO authenticated USING (personnage = public.mon_personnage());

CREATE OR REPLACE FUNCTION public.chat_signaux_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p text; dest text;
BEGIN
  IF coalesce(NEW.salon, false) THEN RETURN NEW; END IF;
  FOREACH p IN ARRAY string_to_array(NEW.conversation_id, '__') LOOP
    IF p IS DISTINCT FROM NEW.auteur THEN
      dest := public.chat_personnage_de_interne(p);
      IF dest IS NOT NULL THEN
        INSERT INTO public.chat_signaux (personnage) VALUES (dest)
        ON CONFLICT (personnage) DO UPDATE SET version = public.chat_signaux.version + 1, maj = now();
      END IF;
    END IF;
  END LOOP;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.chat_signaux_trg() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS zz_chat_signaux ON public.messages_chat;
CREATE TRIGGER zz_chat_signaux AFTER INSERT ON public.messages_chat FOR EACH ROW EXECUTE FUNCTION public.chat_signaux_trg();

DO $p$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'chat_signaux') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_signaux; END IF;
END $p$;

COMMIT;
