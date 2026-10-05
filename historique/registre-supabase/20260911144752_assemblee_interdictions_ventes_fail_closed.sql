-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260911144752
-- Nom original      : assemblee_interdictions_ventes_fail_closed
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-11 14:47:52 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 201e1e51bd1d8a2ee0fed4da3626df51
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- Correctif de migration_assemblee_interdictions_ventes.sql (le fichier porte la version finale) :
-- assemblee_verifier_vente refuse une entree qui n'est pas un tableau au lieu de la lire comme
-- « rien a vendre ».
CREATE OR REPLACE FUNCTION public.assemblee_verifier_vente(p_objets jsonb, p_country text DEFAULT 'republic')
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  WITH o AS (
    SELECT (t.ord - 1)::integer AS idx,
           public.assemblee_loi_en_vigueur(p_country, t.val, now()) AS loi
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_objets) = 'array' THEN p_objets ELSE '[]'::jsonb END)
           WITH ORDINALITY AS t(val, ord)
  )
  SELECT CASE WHEN jsonb_typeof(p_objets) IS DISTINCT FROM 'array'
    THEN jsonb_build_object('ok', false, 'instant', now(), 'raison', 'objets_invalides', 'interdits', '[]'::jsonb)
    ELSE jsonb_build_object(
           'ok', NOT EXISTS (SELECT 1 FROM o WHERE loi IS NOT NULL),
           'instant', now(),
           'interdits', COALESCE((SELECT jsonb_agg(jsonb_build_object('index', idx, 'loi', loi) ORDER BY idx)
                                    FROM o WHERE loi IS NOT NULL), '[]'::jsonb))
  END;
$$;
REVOKE ALL ON FUNCTION public.assemblee_verifier_vente(jsonb, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_verifier_vente(jsonb, text) TO anon, authenticated, service_role;
