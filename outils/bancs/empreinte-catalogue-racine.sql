-- EMPREINTE ARBORESCENTE DU CATALOGUE (31/10/2026, clôture Luthécia, #219) — LECTURE SEULE.
--
-- But : prouver qu'un catalogue reconstruit en local est IDENTIQUE à la production, objet par
-- objet, sans exporter les 2,5 Mo de définitions. Chaque objet du schéma public est réduit à une
-- empreinte de sa définition COMPLÈTE (corps normalisé, signature, retour, sécurité, config,
-- droits ; colonnes, types, défauts, RLS, droits ; politiques ; déclencheurs ; contraintes ;
-- index ; vues). Les empreintes sont regroupées en 16 seaux par catégorie (premier caractère
-- hexadécimal du md5 du nom). Deux catalogues dont toutes les racines concordent sont identiques
-- sur ces familles ; un seau discordant se descend avec empreinte-catalogue-detail.sql.
--
-- Normalisation unique, la même des deux côtés : commentaires « -- » retirés puis tous les blancs
-- (l'application par Supabase supprime les commentaires du corps des fonctions). Le propriétaire
-- et le concédant des droits sont écartés (rôle d'installation différent en local) ; les droits
-- sont comparés par (rôle bénéficiaire, privilèges).
-- À jouer tel quel en production (execute_sql) ET sur le catalogue local en PostgreSQL 17.6.
BEGIN;
SET TRANSACTION READ ONLY;

WITH
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
seaux AS (
  SELECT cat, left(md5(cle), 1) AS seau, count(*) AS n, md5(string_agg(cle || '=' || h, E'\n' ORDER BY cle COLLATE "C")) AS h
  FROM objets GROUP BY cat, left(md5(cle), 1)
)
SELECT jsonb_build_object(
  'version_serveur', current_setting('server_version'),
  'registre', (SELECT jsonb_build_object('lignes', count(*), 'derniere', max(version)) FROM supabase_migrations.schema_migrations),
  'categories', (SELECT jsonb_object_agg(cat, x) FROM (
      SELECT cat, jsonb_build_object('objets', sum(n), 'racine', md5(string_agg(seau || ':' || h, ',' ORDER BY seau)),
                                     'seaux', jsonb_object_agg(seau, n::text || ':' || left(h, 12))) AS x
      FROM seaux GROUP BY cat) s)
) AS empreinte;

ROLLBACK;
