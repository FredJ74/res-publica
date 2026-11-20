-- Interactions avec un personnage MASQUÉ, sous son identité anonyme (décision de Fred du 20/11/2026 : par exemple un bal
-- masqué entre joueurs). GAME-DESIGN-CRIMINALITE.md, « Personnage masqué : parler et rejoindre ».
--  • « Parler » : la conversation privée porte l'identifiant anonyme 'masque:<jeton>' (jeton de crim_jetons_masque,
--    renouvelé à chaque masque revêtu, déjà donné aux présents par crim_presents) à la place du vrai nom ; le masqué y
--    écrit sous ce même identifiant (exigé par la règle d'écriture de messages_chat). Le vrai nom n'est jamais écrit dans
--    la conversation : ni identifiant, ni auteur. Les lectures (lectures_chat) ne sont lisibles que par leur auteur.
--  • « Rejoindre » : groupe_pj_rejoindre_masque(jeton). La demande par le VRAI nom d'un masqué présent répond toujours
--    comme s'il était absent (pas_co_presents, correctif crim_groupe_masque_v1 conservé). Un caché reste inaccessible.
--  • Dans le groupe (groupe_pj_lire) et dans les réponses des déplacements de groupe, un membre masqué apparaît comme
--    « Individu masqué n°X » (numéro de la pièce de celui qui regarde) tant qu'il reste masqué.
--  • « Envoyer un mail » reste impossible : le courrier passe par le vrai nom.
-- Idempotente (marques masques_interactions_v1).
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

-- Identifiant anonyme d'un personnage pour le chat : 'masque:<jeton>' (le dernier masque revêtu), ou NULL.
CREATE OR REPLACE FUNCTION public.chat_alias_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT 'masque:' || j.jeton::text FROM public.crim_jetons_masque j WHERE j.personnage = p_nom;
$$;
REVOKE ALL ON FUNCTION public.chat_alias_interne(text) FROM PUBLIC, anon, authenticated;

-- Nom montré à un observateur : le vrai nom, sauf pour un autre que lui qui est masqué.
CREATE OR REPLACE FUNCTION public.crim_nom_pour_interne(p_nom text, p_observateur text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN p_nom IS NULL OR p_nom IS NOT DISTINCT FROM p_observateur OR NOT public.crim_masque_interne(p_nom) THEN p_nom
    ELSE 'Individu masqué' || coalesce(' n°' || (
      SELECT m.numero::text FROM public.personnages_donnees d,
             public.crim_masques_piece_interne(d.country, d.current_city, d.current_building, d.current_room) m
       WHERE d.name = p_observateur AND m.nom = p_nom LIMIT 1), '') END;
$$;
REVOKE ALL ON FUNCTION public.crim_nom_pour_interne(text, text) FROM PUBLIC, anon, authenticated;

-- Mon identifiant anonyme, pour que l'écran du masqué retrouve et signe ses conversations.
CREATE OR REPLACE FUNCTION public.crim_mon_alias_masque()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true, 'masque', public.crim_masque_interne(a), 'alias', public.chat_alias_interne(a));
END $$;
REVOKE ALL ON FUNCTION public.crim_mon_alias_masque() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crim_mon_alias_masque() TO authenticated;

-- Participer à une conversation privée : sous son nom, ou sous son identifiant anonyme.
CREATE OR REPLACE FUNCTION public.chat_participe(p_conversation text, p_salon boolean)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN public.mon_personnage() IS NULL THEN false
    WHEN coalesce(p_salon, false) THEN public.chat_est_membre_salon(p_conversation)
    ELSE public.mon_personnage() IN (split_part(p_conversation, '__', 1), split_part(p_conversation, '__', 2))
      OR coalesce(public.chat_alias_interne(public.mon_personnage()) IN (split_part(p_conversation, '__', 1),
                                                                        split_part(p_conversation, '__', 2)), false) /* masques_interactions_v1 */
  END;
$function$;

-- Écrire : dans une conversation ouverte à son identifiant anonyme, on signe de cet identifiant, jamais de son nom.
CREATE OR REPLACE FUNCTION public.chat_auteur_attendu_interne(p_conversation text, p_salon boolean)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN NOT coalesce(p_salon, false)
                AND public.chat_alias_interne(public.mon_personnage()) IN (split_part(p_conversation, '__', 1), split_part(p_conversation, '__', 2))
              THEN public.chat_alias_interne(public.mon_personnage())
              ELSE public.mon_personnage() END;
$$;
GRANT EXECUTE ON FUNCTION public.chat_auteur_attendu_interne(text, boolean) TO authenticated;
DROP POLICY IF EXISTS messages_chat_envoi ON public.messages_chat;
CREATE POLICY messages_chat_envoi ON public.messages_chat FOR INSERT
  WITH CHECK (auteur = public.chat_auteur_attendu_interne(conversation_id, salon) AND public.chat_participe(conversation_id, salon));

-- Rejoindre un masqué : par son jeton seulement.
SELECT pg_temp.rp_raccorder('public.groupe_pj_rejoindre(text)'::regprocedure,
  $a$ IF coalesce(public.crim_mode_action_interne(p_chef), 'decouvert') <> 'decouvert' /* crim_groupe_masque_v1 */ THEN$a$,
  $b$ IF coalesce(public.crim_mode_action_interne(p_chef), 'decouvert') <> 'decouvert' /* crim_groupe_masque_v1 */
    AND NOT (public.crim_mode_action_interne(p_chef) = 'masque'
             AND coalesce(current_setting('rp.groupe_par_jeton', true), '') = 'on') /* masques_interactions_v1 */ THEN$b$,
  'masques_interactions_v1');

CREATE OR REPLACE FUNCTION public.groupe_pj_rejoindre_masque(p_jeton text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_chef text := public.crim_jeton_resoudre_interne(p_jeton); r jsonb;
BEGIN
  IF public.mon_personnage() IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_authentifie'); END IF;
  -- Jeton inconnu, périmé, ou masque retiré : même réponse qu'une personne absente.
  IF v_chef IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents'); END IF;
  PERFORM set_config('rp.groupe_par_jeton', 'on', true);
  r := public.groupe_pj_rejoindre(v_chef);
  PERFORM set_config('rp.groupe_par_jeton', '', true);
  RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.groupe_pj_rejoindre_masque(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.groupe_pj_rejoindre_masque(text) TO authenticated;

-- Le groupe vu par chacun : « Individu masqué n°X » tant que la personne reste masquée.
SELECT pg_temp.rp_raccorder('public.groupe_pj_lire()'::regprocedure,
  $a$'chef',chef_courant,'membres',
    (SELECT coalesce(jsonb_agg(membre ORDER BY membre),'[]'::jsonb) FROM ($a$,
  $b$'chef',public.crim_nom_pour_interne(chef_courant,moi),'membres', /* masques_interactions_v1 */
    (SELECT coalesce(jsonb_agg(public.crim_nom_pour_interne(membre,moi) ORDER BY public.crim_nom_pour_interne(membre,moi)),'[]'::jsonb) FROM ($b$,
  'masques_interactions_v1');

-- Déplacements de groupe : ni les membres, ni les positions, ni un refus ne nomment un masqué.
DO $m$
DECLARE d text := pg_get_functiondef('public.navigation_commander_personnage_interne(text,text,text,text)'::regprocedure);
BEGIN
  IF position('masques_interactions_v1' IN d) > 0 THEN RETURN; END IF;
  IF position($x$jsonb_build_object('membre',nom)$x$ IN d) = 0
     OR position($x$'chef',moi,'membres',to_jsonb(ids),'positions',positions);$x$ IN d) = 0
     OR position($x$jsonb_agg(jsonb_build_object('name',name,$x$ IN d) = 0 THEN
    RAISE EXCEPTION 'navigation_commander_personnage_interne : ancrages introuvables'; END IF;
  d := replace(d, $x$jsonb_build_object('membre',nom)$x$, $x$jsonb_build_object('membre',public.crim_nom_pour_interne(nom,moi))$x$);
  d := replace(d, $x$'chef',moi,'membres',to_jsonb(ids),'positions',positions);$x$,
    $x$'chef',moi,'membres',(SELECT jsonb_agg(public.crim_nom_pour_interne(x,moi)) FROM unnest(ids) x),'positions',positions); /* masques_interactions_v1 */$x$);
  d := replace(d, $x$jsonb_agg(jsonb_build_object('name',name,$x$, $x$jsonb_agg(jsonb_build_object('name',public.crim_nom_pour_interne(name,moi),$x$);
  EXECUTE d;
END $m$;

COMMIT;
