-- Forums territoriaux : le pays vient de la fiche serveur, non du navigateur.
-- Sans renommer les identifiants historiques national/local_<ville>, qui sont
-- aussi employés par les publications officielles. Aucune donnée PJ modifiée.
-- RLS : la lecture des sujets ET réponses est interdite hors territoire ou
-- sans adhésion à l'organisation, y compris par appel direct à PostgREST.

-- Empreinte de NOTRE définition préparée, jamais imposée à une autre version.
-- Une politique permissive supplémentaire rendrait les restrictions inopérantes.
DO $prevol_forums$
BEGIN
 IF EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.forum_lecture_autorisee(text,text)')
   AND(md5(prosrc)<>'8c3942ad7d820a9533bb54a5111c87a2'OR NOT prosecdef))THEN
  RAISE EXCEPTION 'forum_definition_non_examinee';END IF;
 IF EXISTS(SELECT 1 FROM pg_class WHERE oid IN('public.forum_topics'::regclass,'public.forum_posts'::regclass)AND NOT relrowsecurity)THEN
  RAISE EXCEPTION 'forum_RLS_inactive';END IF;
 IF EXISTS(SELECT 1 FROM pg_policy WHERE polrelid IN('public.forum_topics'::regclass,'public.forum_posts'::regclass)
   AND polpermissive AND polcmd IN('r','*')AND polname NOT IN('forum_topics_lecture','forum_posts_lecture'))THEN
  RAISE EXCEPTION 'forum_politique_lecture_non_examinee';END IF;
END;$prevol_forums$;

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

-- Quitter le territoire ou l'organisation ferme aussi l'ancienne porte DELETE.
DROP POLICY IF EXISTS forum_topics_suppression_auteur ON public.forum_topics;
CREATE POLICY forum_topics_suppression_auteur ON public.forum_topics
 FOR DELETE TO authenticated
 USING((author=public.mon_personnage()OR author_real=public.mon_personnage())
   AND public.forum_lecture_autorisee(forum_id,country));
DROP POLICY IF EXISTS forum_posts_suppression_auteur ON public.forum_posts;
CREATE POLICY forum_posts_suppression_auteur ON public.forum_posts
 FOR DELETE TO authenticated
 USING((author=public.mon_personnage()OR author_real=public.mon_personnage())
   AND EXISTS(SELECT 1 FROM public.forum_topics t WHERE t.id=forum_posts.topic_id));

-- Après #410 : la publication transactionnelle est SECURITY DEFINER. Elle doit
-- appliquer la même autorité d'accès que les lectures, sans toucher aux jauges.
-- Gardes sur le corps examiné de main ; aucun remplacement d'une version inconnue.
DO $publication_forums$
DECLARE f regprocedure:=to_regprocedure('public.forum_publication_jauges_interne(text,uuid,jsonb)');
 definition text;corps text;
BEGIN
 IF f IS NULL THEN RAISE EXCEPTION 'forum_dependance_publication_absente';END IF;
 SELECT prosrc INTO corps FROM pg_proc WHERE oid=f;
 IF md5(corps)='2a6b4d5f8c468aa12504c2cbf39def54'THEN
  definition:=pg_get_functiondef(f);
  definition:=replace(definition,$avant1$IF f NOT IN('international','sport')AND t.country IS DISTINCT FROM a.country THEN$avant1$,$apres1$IF f NOT IN('international','sport')AND left(f,4)<>'org_'AND t.country IS DISTINCT FROM a.country THEN$apres1$);
  definition:=replace(definition,$avant2$  SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(o->'membres','[]'::jsonb))m WHERE m->>'nom'=a.name)INTO membre;$avant2$,$apres2$  membre:=public.forum_lecture_autorisee(f,a.country);$apres2$);
  definition:=replace(definition,$avant3$ IF f IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','forum_inconnu');END IF;$avant3$,$apres3$ IF f IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','forum_inconnu');END IF;
 IF NOT public.forum_lecture_autorisee(f,CASE WHEN nouveau THEN a.country ELSE t.country END)THEN
  RETURN jsonb_build_object('ok',false,'raison','forum_inaccessible');END IF;$apres3$);
  EXECUTE definition;
 ELSIF md5(corps)<>'536c0751b6cddf32381dcac7a8cbd581'THEN
  RAISE EXCEPTION 'forum_publication_definition_non_examinee';
 END IF;
END;$publication_forums$;
