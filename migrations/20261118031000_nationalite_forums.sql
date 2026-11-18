-- FORUMS ET NATIONALITÉ (Fred, 18/11/2026) : le PJ garde toujours les forums de SON pays (nationalité),
-- où qu'il soit ; en plus il voit ceux du pays où il se trouve : forum national de ce pays en lecture
-- seule, forum local de la ville où il se trouve en lecture et écriture.
-- Forums de son pays : national ; Local de la ville où il se trouve (s'il est chez lui) et Local de sa
-- ville de domicile (si elle est dans son pays). Les autres forums (institutions, presse, international,
-- sport, organisations) sont inchangés. Idempotente.
BEGIN;

CREATE OR REPLACE FUNCTION public.forum_lecture_autorisee(p_forum text, p_pays text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE
  v_nom text := public.mon_personnage();
  v_pays text; v_ville text; v_nat text; v_dom jsonb; v_local text;
BEGIN
  IF p_forum IS NULL THEN RETURN false; END IF;
  IF left(p_forum,4) = 'org_' THEN
    IF v_nom IS NULL THEN RETURN false; END IF;
    RETURN EXISTS (
      SELECT 1 FROM public.organisations o
       WHERE o.id = substring(p_forum from 5)
         AND CASE WHEN o.data IS JSON OBJECT THEN (
           (o.data::jsonb ->> 'chef') = v_nom
           OR EXISTS (
             SELECT 1 FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(o.data::jsonb -> 'membres') = 'array'
                 THEN o.data::jsonb -> 'membres' ELSE '[]'::jsonb END
             ) m(elem)
             WHERE coalesce(m.elem ->> 'nom', m.elem #>> '{}') = v_nom
           )
         ) ELSE false END
    );
  END IF;
  IF p_forum = 'national' OR left(p_forum,6) = 'local_' THEN
    IF v_nom IS NULL THEN RETURN false; END IF;
    SELECT country, current_city, coalesce(nationalite, country), domicile INTO v_pays, v_ville, v_nat, v_dom
      FROM public.personnages_donnees WHERE name = v_nom;
    v_local := substring(p_forum from 7);
    IF p_pays IS NOT DISTINCT FROM v_nat THEN
      IF p_forum = 'national' THEN RETURN true; END IF;
      RETURN (v_pays IS NOT DISTINCT FROM v_nat AND v_ville IS NOT DISTINCT FROM v_local)
          OR (v_dom ->> 'country' IS NOT DISTINCT FROM v_nat AND v_dom ->> 'city' IS NOT DISTINCT FROM v_local);
    ELSIF p_pays IS NOT DISTINCT FROM v_pays THEN
      IF p_forum = 'national' THEN RETURN true; END IF;
      RETURN v_ville IS NOT DISTINCT FROM v_local;
    END IF;
    RETURN false;
  END IF;
  -- Institutions, presse, international et sport : règles de lecture inchangées.
  RETURN true;
END;
$function$;

-- Écriture : comme la lecture, sauf le forum national d'un pays qui n'est pas le sien (lecture seule).
CREATE OR REPLACE FUNCTION public.forum_ecriture_autorisee(p_forum text, p_pays text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
BEGIN
  IF NOT public.forum_lecture_autorisee(p_forum, p_pays) THEN RETURN false; END IF;
  IF p_forum = 'national' AND p_pays IS DISTINCT FROM public.personnage_nationalite(public.mon_personnage()) THEN
    RETURN false;
  END IF;
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.forum_ecriture_autorisee(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.forum_ecriture_autorisee(text, text) TO authenticated;

DROP POLICY IF EXISTS forum_topics_creation ON public.forum_topics;
CREATE POLICY forum_topics_creation ON public.forum_topics FOR INSERT TO authenticated
  WITH CHECK (((author = public.mon_personnage()) OR (author_real = public.mon_personnage())) AND public.forum_ecriture_autorisee(forum_id, country));
DROP POLICY IF EXISTS forum_topics_maj_auteur ON public.forum_topics;
CREATE POLICY forum_topics_maj_auteur ON public.forum_topics FOR UPDATE TO authenticated
  USING (((author = public.mon_personnage()) OR (author_real = public.mon_personnage())) AND public.forum_ecriture_autorisee(forum_id, country))
  WITH CHECK (((author = public.mon_personnage()) OR (author_real = public.mon_personnage())) AND public.forum_ecriture_autorisee(forum_id, country));
DROP POLICY IF EXISTS forum_topics_suppression_auteur ON public.forum_topics;
CREATE POLICY forum_topics_suppression_auteur ON public.forum_topics FOR DELETE TO authenticated
  USING (((author = public.mon_personnage()) OR (author_real = public.mon_personnage())) AND public.forum_ecriture_autorisee(forum_id, country));
DROP POLICY IF EXISTS forum_posts_creation ON public.forum_posts;
CREATE POLICY forum_posts_creation ON public.forum_posts FOR INSERT TO authenticated
  WITH CHECK (((author = public.mon_personnage()) OR (author_real = public.mon_personnage()))
              AND EXISTS (SELECT 1 FROM public.forum_topics t WHERE t.id = forum_posts.topic_id AND public.forum_ecriture_autorisee(t.forum_id, t.country)));

-- Publication par le serveur (forum_publier) : le pays des forums territoriaux est choisi par le joueur
-- parmi sa nationalité et le pays où il se trouve ; l'écriture suit forum_ecriture_autorisee.
DO $publier$
DECLARE d text; a text; b text;
  ancres text[] := ARRAY[
    '''secret'',''icone'']<>''{}''::jsonb THEN',
    'AND t.country IS DISTINCT FROM a.country THEN',
    'IF NOT public.forum_lecture_autorisee(f,CASE WHEN nouveau THEN a.country ELSE t.country END)THEN',
    '''local_''||a.current_city,''tribunal_''||a.current_city)THEN',
    'VALUES(sujet,f,btrim(p_message->>''titre''),auteur,a.country,temps,'];
  remplacements text[] := ARRAY[
    '''secret'',''icone'',''pays'']<>''{}''::jsonb THEN',
    'AND t.country IS DISTINCT FROM a.country AND t.country IS DISTINCT FROM coalesce(a.nationalite, a.country) THEN',
    'IF NOT public.forum_ecriture_autorisee(f,CASE WHEN nouveau THEN CASE WHEN f=''national'' OR left(f,6)=''local_'' THEN coalesce(nullif(p_message->>''pays'',''''), a.country) ELSE a.country END ELSE t.country END)THEN',
    '''local_''||a.current_city,''local_''||coalesce(a.domicile->>''city'',''''),''tribunal_''||a.current_city)THEN',
    'VALUES(sujet,f,btrim(p_message->>''titre''),auteur,CASE WHEN f=''national'' OR left(f,6)=''local_'' THEN coalesce(nullif(p_message->>''pays'',''''), a.country) ELSE a.country END,temps,'];
  i int;
BEGIN
  d := pg_get_functiondef('public.forum_publication_jauges_interne(text,uuid,jsonb)'::regprocedure);
  IF position('forum_ecriture_autorisee' IN d) > 0 THEN RETURN; END IF;
  FOR i IN 1 .. array_length(ancres, 1) LOOP
    a := ancres[i]; b := remplacements[i];
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN
      RAISE EXCEPTION 'forum_publication_jauges_interne : ancrage % introuvable', i;
    END IF;
    d := replace(d, a, b);
  END LOOP;
  EXECUTE d;
END $publier$;

DO $post$
BEGIN
  IF position('forum_ecriture_autorisee' IN pg_get_functiondef('public.forum_publication_jauges_interne(text,uuid,jsonb)'::regprocedure)) = 0
     OR NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.forum_posts'::regclass AND polname = 'forum_posts_creation'
                     AND position('forum_ecriture_autorisee' IN pg_get_expr(polwithcheck, polrelid)) > 0)
  THEN RAISE EXCEPTION 'nationalite_forums : raccords absents'; END IF;
END $post$;

NOTIFY pgrst, 'reload schema';
COMMIT;
