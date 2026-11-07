-- Prévol RLS des sources de traduction — LECTURE SEULE, aucune donnée personnelle.
-- Contrôle à relancer avant tout raccordement public d'un service de traduction.
WITH sources(table_name,expected_predicate) AS (
 VALUES ('forum_posts','true'),('forum_topics','true'),
        ('messages_chat','chat_participe(conversation_id, salon)')
), actual AS (
 SELECT s.table_name,s.expected_predicate,p.policyname,p.qual,p.cmd,
        c.relrowsecurity AS rls_enabled
 FROM sources s
 JOIN pg_class c ON c.relname=s.table_name
 JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public'
 LEFT JOIN pg_policies p ON p.schemaname='public' AND p.tablename=s.table_name AND p.cmd='SELECT'
)
SELECT table_name,rls_enabled,policyname,qual,
  (rls_enabled AND qual=expected_predicate) AS contrat_conforme
FROM actual ORDER BY table_name;
