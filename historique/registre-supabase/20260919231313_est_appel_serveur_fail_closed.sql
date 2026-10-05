-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919231313
-- Nom original      : est_appel_serveur_fail_closed
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 23:13:13 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 595e8deb17f94d25358aa7cfed57fc48
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
-- =====================================================================
-- est_appel_serveur() — SUPPRESSION DU FAIL-OPEN
-- =====================================================================
-- AVANT :
--   coalesce(claim.role, claims->>'role', 'service_role') = 'service_role'
-- Le repli etait 'service_role' : EN L'ABSENCE DE CLAIMS, TOUT APPELANT ETAIT
-- REPUTE SERVEUR. 31 fonctions en dependent, dont les trois declencheurs de la
-- vue personnages, l'attestation de poste, les verrous de forum et les
-- primitives de caisse. Tout chemin sans claims (connexion Postgres directe,
-- declencheur hors contexte HTTP) desarmait donc l'ensemble.
--
-- APRES, dans cet ordre :
--   1. LE ROLE POSTGRESQL EFFECTIF FAIT FOI. anon et authenticated ne sont
--      JAMAIS le serveur, quoi que disent les claims -- une claim forgee ne
--      peut donc plus elever. Inversement postgres / supabase_admin /
--      service_role LE SONT, sans avoir besoin de claims : c'est ce qui garde
--      les migrations et la maintenance fonctionnelles.
--   2. Pour tout autre role, les claims decident -- avec un repli 'anon',
--      c'est-a-dire FERME.
--
-- POURQUOI LE ROLE PLUTOT QUE current_user : dans une fonction SECURITY
-- DEFINER, current_user vaut le PROPRIETAIRE (postgres) et ne dit donc rien de
-- l'appelant. Le GUC 'role' reflete le SET ROLE reellement pose par PostgREST
-- et traverse les SECURITY DEFINER -- c'est le meme raisonnement que celui
-- deja retenu pour le declencheur d'archivage des suppressions.
CREATE OR REPLACE FUNCTION public.est_appel_serveur()
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public', 'pg_temp'
AS $fn$
  SELECT CASE
    WHEN coalesce(nullif(current_setting('role', true), 'none'), session_user)
         IN ('anon', 'authenticated')
      THEN false
    WHEN coalesce(nullif(current_setting('role', true), 'none'), session_user)
         IN ('postgres', 'supabase_admin', 'service_role', 'supabase_auth_admin')
      THEN true
    ELSE coalesce(
           nullif(current_setting('request.jwt.claim.role', true), ''),
           (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'),
           'anon'
         ) = 'service_role'
  END;
$fn$;