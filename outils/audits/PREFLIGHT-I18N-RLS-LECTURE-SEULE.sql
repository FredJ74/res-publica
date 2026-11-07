-- Prévol i18n : vérifier la visibilité RLS réellement appliquée APRÈS #422.
-- Lecture seule. Toute politique SELECT/ALL supplémentaire ou permissive fait échouer
-- le contrôle. Ne fournit jamais un droit de lecture, n'accède à aucune donnée PJ.
WITH attendues(table_name, predicate_normalise) AS (
 VALUES
 ('forum_posts','(exists(select1fromforum_topicstwhere(t.id=forum_posts.topic_id)))'),
 ('forum_topics','forum_lecture_autorisee(forum_id,country)'),
 ('messages_chat','chat_participe(conversation_id,salon)')
), registres AS (
 SELECT a.table_name,a.predicate_normalise,
        c.relrowsecurity AS rls_active,
        COUNT(p.policyname) AS nombre_politiques_lecture,
        COALESCE(bool_and(
          regexp_replace(lower(p.qual),'\s+','','g')=a.predicate_normalise
          AND 'authenticated'=ANY(p.roles)
        ) FILTER (WHERE p.policyname IS NOT NULL),false) AS politiques_conformes,
        string_agg(p.policyname,', ' ORDER BY p.policyname) AS politiques
 FROM attendues a
 JOIN pg_namespace n ON n.nspname='public'
 JOIN pg_class c ON c.relnamespace=n.oid AND c.relname=a.table_name
 LEFT JOIN pg_policies p ON p.schemaname='public'
   AND p.tablename=a.table_name AND p.cmd IN ('SELECT','ALL')
 GROUP BY a.table_name,a.predicate_normalise,c.relrowsecurity
)
SELECT table_name,rls_active,nombre_politiques_lecture,politiques,
 (rls_active AND nombre_politiques_lecture=1 AND politiques_conformes) AS contrat_conforme
FROM registres ORDER BY table_name;
