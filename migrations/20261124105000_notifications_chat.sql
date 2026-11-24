-- Purge, bloc A, point A.8 (Fred, 24/11/2026) : notifications du navigateur, pour le chat uniquement. NON APPLIQUÉE.
-- Rejouable. Rien du goulag. Pas de courriel.
--  • notifications_chat (personnage, active, proposee_le) : le réglage du joueur (activer / couper) et la mémoire de la
--    proposition (la bulle n'est proposée qu'une fois). La permission elle-même appartient au navigateur.
--  • notifications_chat_lire() : {active, proposee, a_proposer}. « a_proposer » est faux pendant la première heure de jeu
--    d'un nouveau venu (calendrier A.3) : la bulle attend la fin de cette heure.
--  • notifications_chat_fixer(p_active) : enregistre le choix (et la proposition).
-- Le contenu d'un message n'est jamais lu ici ni envoyé dans une notification : l'écran n'affiche que le nom et le lieu,
-- ou « Quelqu'un vous a parlé » pour un interlocuteur caché ou anonyme. Les messages du PNJ guide n'en déclenchent pas.

CREATE TABLE IF NOT EXISTS public.notifications_chat (
  personnage text PRIMARY KEY,
  active boolean NOT NULL DEFAULT false,
  proposee_le timestamptz,
  maj_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.notifications_chat ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.notifications_chat FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.notifications_chat TO service_role;

CREATE OR REPLACE FUNCTION public.notifications_chat_lire()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); n public.notifications_chat; v_premiere boolean := false; r record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO n FROM public.notifications_chat WHERE personnage = a;
  IF to_regclass('public.accueil_personnages') IS NOT NULL THEN
    SELECT calendrier, heure_finie_le, secondes_jeu INTO r FROM public.accueil_personnages WHERE personnage = a;
    v_premiere := FOUND AND r.calendrier AND r.heure_finie_le IS NULL
                  AND r.secondes_jeu < public.accueil_param('premiere_heure_s', 3600);
  END IF;
  RETURN jsonb_build_object('ok', true, 'active', coalesce(n.active, false), 'proposee', n.proposee_le IS NOT NULL,
    'a_proposer', n.proposee_le IS NULL AND NOT v_premiere, 'premiere_heure', v_premiere); /* notifications_chat_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.notifications_chat_fixer(p_active boolean)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  INSERT INTO public.notifications_chat (personnage, active, proposee_le) VALUES (a, coalesce(p_active, false), now())
  ON CONFLICT (personnage) DO UPDATE SET active = coalesce(p_active, false),
    proposee_le = coalesce(public.notifications_chat.proposee_le, now()), maj_le = now();
  RETURN public.notifications_chat_lire(); /* notifications_chat_v1 */
END $function$;

REVOKE ALL ON FUNCTION public.notifications_chat_lire() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.notifications_chat_fixer(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.notifications_chat_lire(), public.notifications_chat_fixer(boolean) TO authenticated;
