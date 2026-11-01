-- DESCENTE DANS UN SEAU DISCORDANT (31/10/2026, #219) — LECTURE SEULE.
-- Compagnon de empreinte-catalogue-racine.sql : même définition des objets (CTE recopiée à
-- l'identique, vérifiée par outils/bancs/test-empreinte-catalogue.mjs). Éditer la liste
-- « cible » (catégorie, seau hexadécimal) avec les seaux discordants, jouer des deux côtés et
-- comparer ligne à ligne : la ligne qui diffère est l'objet dont la définition diffère.
BEGIN;
SET TRANSACTION READ ONLY;

WITH
cible(cat, seau) AS (VALUES ('fonctions', '0')),  -- À ÉDITER
acl AS (  -- droits sans le concédant : 'role=privileges' triés
  SELECT a.oid, a.cat, coalesce(string_agg(x.r, ',' ORDER BY x.r), '') AS d
  FROM (SELECT p.oid, 'f'::text AS cat, p.proacl AS acl FROM pg_proc p
        UNION ALL SELECT c.oid, 'r', c.relacl FROM pg_class c) a
  LEFT JOIN LATERAL (SELECT coalesce(nullif(e.grantee::regrole::text, '-'), 'PUBLIC') || '=' || string_agg(e.privilege_type, '' ORDER BY e.privilege_type) AS r
                     FROM aclexplode(a.acl) e GROUP BY e.grantee) x ON true
  GROUP BY a.oid, a.cat
),
objets AS (
  SELECT 'fonctions' AS cat, p.oid::regprocedure::text AS cle,
         md5(concat_ws('|', p.prokind, p.prosecdef, p.provolatile, p.proleakproof, p.proisstrict,
             array_to_string(p.proconfig, ','), p.prorettype::regtype::text, pg_get_function_arguments(p.oid),
             (SELECT d FROM acl WHERE acl.oid = p.oid AND acl.cat = 'f'),
             regexp_replace(regexp_replace(p.prosrc, '--[^\n]*', '', 'g'), '\s+', '', 'g'))) AS h
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public'
  UNION ALL
  SELECT 'relations', c.relname,
         md5(concat_ws('|', c.relkind, c.relrowsecurity, c.relforcerowsecurity,
             (SELECT d FROM acl WHERE acl.oid = c.oid AND acl.cat = 'r'),
             (SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod) || ':' || a.attnotnull || ':'
                                || coalesce(pg_get_expr(ad.adbin, ad.adrelid), ''), ',' ORDER BY a.attnum)
                FROM pg_attribute a LEFT JOIN pg_attrdef ad ON ad.adrelid = a.attrelid AND ad.adnum = a.attnum
               WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped),
             CASE WHEN c.relkind IN ('v', 'm') THEN regexp_replace(pg_get_viewdef(c.oid), '\s+', '', 'g') END))
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
  UNION ALL
  SELECT 'politiques', p.tablename || '.' || p.policyname,
         md5(concat_ws('|', p.permissive, array_to_string(p.roles, ','), p.cmd,
             regexp_replace(coalesce(p.qual, ''), '\s+', '', 'g'), regexp_replace(coalesce(p.with_check, ''), '\s+', '', 'g')))
  FROM pg_policies p WHERE p.schemaname = 'public'
  UNION ALL
  SELECT 'declencheurs', c.relname || '.' || t.tgname, md5(t.tgenabled::text || '|' || pg_get_triggerdef(t.oid))
  FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND NOT t.tgisinternal
  UNION ALL
  SELECT 'contraintes', c.relname || '.' || k.conname, md5(k.contype::text || '|' || pg_get_constraintdef(k.oid))
  FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
  UNION ALL
  SELECT 'index', i.indexname, md5(i.indexdef) FROM pg_indexes i WHERE i.schemaname = 'public'
),
resultat AS (
  SELECT o.cat, o.cle, left(o.h, 12) AS h FROM objets o
  JOIN cible c ON c.cat = o.cat AND c.seau = left(md5(o.cle), 1)
)
SELECT jsonb_object_agg(cat || ':' || cle, h) AS detail FROM resultat;

ROLLBACK;
