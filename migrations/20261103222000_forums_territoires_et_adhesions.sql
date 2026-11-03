-- Forums territoriaux : le pays vient de la fiche serveur, non du navigateur.
-- Sans renommer les identifiants historiques national/local_<ville>, qui sont
-- aussi employés par les publications officielles. Aucune donnée PJ modifiée.
-- RLS : la lecture des sujets ET réponses est interdite hors territoire ou
-- sans adhésion à l'organisation, y compris par appel direct à PostgREST.

CREATE OR REPLACE FUNCTION public.forum_lecture_autorisee(p_forum text, p_pays text)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_nom text := public.mon_personnage();
  v_pays text;
  v_ville text;
BEGIN
  IF p_forum IS NULL THEN RETURN false; END IF;
  IF p_forum LIKE 'org\\_%' ESCAPE '\\' THEN
    IF v_nom IS NULL THEN RETURN false; END IF;
    RETURN EXISTS (
      SELECT 1 FROM public.organisations o
       WHERE o.id = substring(p_forum from 5)
         AND (
           (o.data::jsonb ->> 'chef') = v_nom
           OR EXISTS (
             SELECT 1 FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(o.data::jsonb -> 'membres') = 'array'
                 THEN o.data::jsonb -> 'membres' ELSE '[]'::jsonb END
             ) m(elem)
             WHERE coalesce(m.elem ->> 'nom', m.elem #>> '{}') = v_nom
           )
         )
    );
  END IF;
  IF p_forum = 'national' OR p_forum LIKE 'local\\_%' ESCAPE '\\' THEN
    IF v_nom IS NULL THEN RETURN false; END IF;
    SELECT country, current_city INTO v_pays, v_ville
      FROM public.personnages_donnees WHERE name = v_nom;
    IF v_pays IS DISTINCT FROM p_pays THEN RETURN false; END IF;
    IF p_forum = 'national' THEN RETURN true; END IF;
    RETURN v_ville IS NOT DISTINCT FROM substring(p_forum from 7);
  END IF;
  -- Institutions, presse, international et sport : règles de lecture inchangées.
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.forum_lecture_autorisee(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.forum_lecture_autorisee(text,text) TO anon, authenticated;

DROP POLICY IF EXISTS forum_topics_lecture ON public.forum_topics;
CREATE POLICY forum_topics_lecture ON public.forum_topics
  FOR SELECT TO anon, authenticated
  USING (public.forum_lecture_autorisee(forum_id,country));

DROP POLICY IF EXISTS forum_posts_lecture ON public.forum_posts;
CREATE POLICY forum_posts_lecture ON public.forum_posts
  FOR SELECT TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM public.forum_topics t WHERE t.id = forum_posts.topic_id
  ));

DROP POLICY IF EXISTS forum_topics_creation ON public.forum_topics;
CREATE POLICY forum_topics_creation ON public.forum_topics
  FOR INSERT TO authenticated
  WITH CHECK (
    (author = public.mon_personnage() OR author_real = public.mon_personnage())
    AND public.forum_lecture_autorisee(forum_id,country)
  );

DROP POLICY IF EXISTS forum_posts_creation ON public.forum_posts;
CREATE POLICY forum_posts_creation ON public.forum_posts
  FOR INSERT TO authenticated
  WITH CHECK (
    (author = public.mon_personnage() OR author_real = public.mon_personnage())
    AND EXISTS (SELECT 1 FROM public.forum_topics t WHERE t.id = forum_posts.topic_id)
  );

DROP POLICY IF EXISTS forum_topics_maj_auteur ON public.forum_topics;
CREATE POLICY forum_topics_maj_auteur ON public.forum_topics
  FOR UPDATE TO authenticated
  USING (
    (author = public.mon_personnage() OR author_real = public.mon_personnage())
    AND public.forum_lecture_autorisee(forum_id,country)
  )
  WITH CHECK (
    (author = public.mon_personnage() OR author_real = public.mon_personnage())
    AND public.forum_lecture_autorisee(forum_id,country)
  );

DROP POLICY IF EXISTS forum_posts_maj_auteur ON public.forum_posts;
CREATE POLICY forum_posts_maj_auteur ON public.forum_posts
  FOR UPDATE TO authenticated
  USING (
    (author = public.mon_personnage() OR author_real = public.mon_personnage())
    AND EXISTS (SELECT 1 FROM public.forum_topics t WHERE t.id = forum_posts.topic_id)
  )
  WITH CHECK (
    (author = public.mon_personnage() OR author_real = public.mon_personnage())
    AND EXISTS (SELECT 1 FROM public.forum_topics t WHERE t.id = forum_posts.topic_id)
  );
