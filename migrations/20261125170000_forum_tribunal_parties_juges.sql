-- Mission de jour du 25/11/2026 (Claude), bloc 1.4 — NON APPLIQUÉE : Fred la valide à son retour. Après 20261124110000.
-- Décision de Fred (question B de la Purge) : forum du tribunal (tribunal_<ville>, sujets rangés par pays dans
-- forum_topics.country) — les PARTIES à l'affaire et les JUGES y lisent et écrivent où qu'ils soient ; tous les autres
-- joueurs le lisent sans y écrire (suivre un procès à distance, rappeler les jours d'audience). Règle tenue par le serveur.
-- • Partie (forum_tribunal_partie_interne) : nommée dans une affaire de ce tribunal (même pays, même ville) encore au rôle —
--   plaintes_en_cours (cible, auteur de la plainte, victime, plaignant) ou crim_affaires non archivée rattachée à une
--   plainte (cible, auteur identifié).
-- • Juge (forum_tribunal_juge_interne) : poste_detenu(nom, 'juge', pays, ville) (fonction unique des postes), ou le juge
--   PNJ incarné par l'administration (juge_moi). Le commissaire de la ville garde l'écriture : c'est lui qui y publie la
--   transmission d'une affaire (« ⚖️ [AFFAIRE] … »), sans quoi cette annonce serait refusée.
-- • forum_ecriture_autorisee : réécrite (reprise de 20261124110000 + la branche du tribunal) ; la lecture reste ouverte à
--   tous (forum_lecture_autorisee inchangée). Les politiques RLS de forum_topics / forum_posts l'appellent déjà.
-- • forum_publication_jauges_interne : remplacements contrôlés (marque tribunal_forum_v1, 4 occurrences) : le tribunal
--   d'une autre ville que celle où l'on se trouve est accepté, une réponse n'exige pas d'être du pays du sujet (le droit
--   est jugé par forum_ecriture_autorisee), et un nouveau sujet est rangé dans le pays choisi (pays du tribunal).
-- • forum_tribunal_droits() : pour l'écran — tribunaux où le joueur écrit (parties, juge, commissaire) et droit
--   d'écriture au tribunal de la ville où il se trouve. Sans la migration, l'écran garde le comportement actuel.
--
-- Contrôles en lecture après application :
--   SELECT (length(d) - length(replace(d, 'tribunal_forum_v1', ''))) / 17 FROM (SELECT pg_get_functiondef(
--     'public.forum_publication_jauges_interne(text,uuid,jsonb)'::regprocedure) d) x;                          -- 4
--   SELECT position('tribunal_forum_v1' in pg_get_functiondef('public.forum_ecriture_autorisee(text,text)'::regprocedure)) > 0;  -- vrai
--   SELECT has_function_privilege('authenticated', 'public.forum_tribunal_droits()', 'EXECUTE');                -- vrai
--   SELECT has_function_privilege('authenticated', 'public.forum_tribunal_partie_interne(text,text,text)', 'EXECUTE');  -- faux
BEGIN;

CREATE OR REPLACE FUNCTION public.forum_tribunal_partie_interne(p_nom text, p_pays text, p_ville text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
  SELECT p_nom IS NOT NULL AND (
    EXISTS (SELECT 1 FROM public.plaintes_en_cours p
             WHERE p.country = p_pays AND coalesce(p.city, 'capitale') = p_ville AND p.data IS JSON OBJECT
               AND p_nom IN (p.data::jsonb ->> 'cible', p.data::jsonb ->> 'auteur', p.data::jsonb ->> 'victime', p.data::jsonb ->> 'plaignant'))
 OR EXISTS (SELECT 1 FROM public.crim_affaires c
             WHERE c.pays = p_pays AND coalesce(c.ville, 'capitale') = p_ville AND c.archivee_le IS NULL AND c.plainte_id IS NOT NULL
               AND (c.cible = p_nom OR (c.auteur = p_nom AND c.identifie)))) /* tribunal_forum_v1 */
$function$;

CREATE OR REPLACE FUNCTION public.forum_tribunal_juge_interne(p_nom text, p_pays text, p_ville text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
BEGIN
  IF p_nom IS NULL THEN RETURN false; END IF;
  IF public.poste_detenu(p_nom, 'juge', p_pays, p_ville) OR public.poste_detenu(p_nom, 'commissaire', p_pays, p_ville) THEN RETURN true; END IF;
  -- Le juge PNJ incarné par l'administration (résolveur unique du juge).
  RETURN EXISTS (SELECT 1 FROM public.juge_moi() j WHERE j.ville IS NOT DISTINCT FROM p_ville); /* tribunal_forum_v1 */
EXCEPTION WHEN undefined_function THEN RETURN false;
END $function$;

CREATE OR REPLACE FUNCTION public.forum_ecriture_autorisee(p_forum text, p_pays text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_nom text;
BEGIN
  IF NOT public.forum_lecture_autorisee(p_forum, p_pays) THEN RETURN false; END IF;
  IF p_forum IN ('national','presidence','assemblee','gouvernement','presse')
     AND p_pays IS DISTINCT FROM public.personnage_nationalite(public.mon_personnage()) THEN
    RETURN false;
  END IF;
  -- Tribunal : les parties aux affaires et les juges de ce tribunal écrivent, où qu'ils soient ; les autres lisent.
  IF left(p_forum, 9) = 'tribunal_' THEN
    v_nom := public.mon_personnage();
    IF v_nom IS NULL OR p_pays IS NULL THEN RETURN false; END IF;
    RETURN public.forum_tribunal_juge_interne(v_nom, p_pays, substring(p_forum from 10))
        OR public.forum_tribunal_partie_interne(v_nom, p_pays, substring(p_forum from 10)); /* tribunal_forum_v1 */
  END IF;
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.forum_ecriture_autorisee(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.forum_ecriture_autorisee(text, text) TO authenticated;

-- Droits de l'écran : tribunaux où le joueur écrit, et celui de la ville où il se trouve.
CREATE OR REPLACE FUNCTION public.forum_tribunal_droits()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_nom text := public.mon_personnage(); d record; v_liste jsonb;
BEGIN
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, coalesce(current_city, 'capitale') AS ville INTO d FROM public.personnages_donnees WHERE name = v_nom;
  SELECT coalesce(jsonb_agg(DISTINCT jsonb_build_object('pays', x.pays, 'ville', x.ville)), '[]'::jsonb) INTO v_liste FROM (
    SELECT p.country AS pays, coalesce(p.city, 'capitale') AS ville FROM public.plaintes_en_cours p
     WHERE p.data IS JSON OBJECT AND v_nom IN (p.data::jsonb ->> 'cible', p.data::jsonb ->> 'auteur', p.data::jsonb ->> 'victime', p.data::jsonb ->> 'plaignant')
    UNION
    SELECT c.pays, coalesce(c.ville, 'capitale') FROM public.crim_affaires c
     WHERE c.archivee_le IS NULL AND c.plainte_id IS NOT NULL AND (c.cible = v_nom OR (c.auteur = v_nom AND c.identifie))
    UNION
    SELECT public.poste_pays_de(v_nom), p.poste ->> 'city' FROM public.personnages_donnees p
     WHERE p.name = v_nom AND public.poste_detenu(v_nom, coalesce(p.poste ->> 'id', ''), public.poste_pays_de(v_nom), p.poste ->> 'city')
       AND p.poste ->> 'id' IN ('juge', 'commissaire') AND p.poste ->> 'city' IS NOT NULL) x
   WHERE x.pays IS NOT NULL AND x.ville IS NOT NULL;
  RETURN jsonb_build_object('ok', true, 'tribunaux', v_liste,
    'ici', jsonb_build_object('pays', d.country, 'ville', d.ville,
      'ecriture', public.forum_tribunal_juge_interne(v_nom, d.country, d.ville) OR public.forum_tribunal_partie_interne(v_nom, d.country, d.ville))); /* tribunal_forum_v1 */
END $function$;

DO $publier$
DECLARE d text; a text; b text; n int; i int;
  ancres text[] := ARRAY[
    '''tribunal_''||a.current_city)THEN',
    '/*purge_b1*/ OR left(f,6)=''local_'' THEN',
    'a.domicile->>''country''/*purge_b1*/ THEN'];
  remplacements text[] := ARRAY[
    '''tribunal_''||a.current_city)AND left(f,9)<>''tribunal_''/*tribunal_forum_v1*/THEN',
    '/*purge_b1*/ OR left(f,6)=''local_'' OR left(f,9)=''tribunal_''/*tribunal_forum_v1*/ THEN',
    'a.domicile->>''country''/*purge_b1*/ AND left(f,9)<>''tribunal_''/*tribunal_forum_v1*/ THEN'];
  attendus int[] := ARRAY[1, 2, 1];
BEGIN
  d := pg_get_functiondef('public.forum_publication_jauges_interne(text,uuid,jsonb)'::regprocedure);
  IF position('tribunal_forum_v1' IN d) > 0 THEN RETURN; END IF;
  FOR i IN 1 .. array_length(ancres, 1) LOOP
    a := ancres[i]; b := remplacements[i];
    n := (length(d) - length(replace(d, a, ''))) / length(a);
    IF n <> attendus[i] THEN
      RAISE EXCEPTION 'forum_publication_jauges_interne : ancrage % trouvé % fois (attendu %)', i, n, attendus[i];
    END IF;
    d := replace(d, a, b);
  END LOOP;
  EXECUTE d;
  IF (length(pg_get_functiondef('public.forum_publication_jauges_interne(text,uuid,jsonb)'::regprocedure))
      - length(replace(pg_get_functiondef('public.forum_publication_jauges_interne(text,uuid,jsonb)'::regprocedure), 'tribunal_forum_v1', ''))) / 17 <> 4 THEN
    RAISE EXCEPTION 'forum_tribunal : raccords absents';
  END IF;
END $publier$;

REVOKE ALL ON FUNCTION public.forum_tribunal_partie_interne(text, text, text), public.forum_tribunal_juge_interne(text, text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.forum_tribunal_droits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.forum_tribunal_droits() TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
