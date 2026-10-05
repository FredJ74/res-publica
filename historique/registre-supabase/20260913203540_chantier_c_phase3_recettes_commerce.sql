-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913203540
-- Nom original      : chantier_c_phase3_recettes_commerce
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 20:35:40 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3c3dc683172d5645a9bd77cc06945396
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
-- resoudreProduitCommerce() lit DEUX catalogues (RECETTES_ALIMENTAIRES puis PRODUITS_MARCHE) :
-- le miroir les fusionne comme le jeu le fait, en gardant la source et les restrictions de lieu,
-- qui decident de ce qu'un commerce donne a le droit de produire et de vendre.
DROP TABLE IF EXISTS public.recettes_alimentaires;

CREATE TABLE IF NOT EXISTS public.recettes_commerce (
  id text PRIMARY KEY,
  source text NOT NULL,
  label text NOT NULL DEFAULT '',
  pa integer NOT NULL DEFAULT 0,
  portions integer NOT NULL DEFAULT 1,
  materiaux jsonb NOT NULL DEFAULT '{}'::jsonb,
  prix_fixe numeric,
  categorie text,
  types_autorises jsonb,
  pays_autorises jsonb,
  villes_autorisees jsonb,
  buildings_autorises jsonb);

ALTER TABLE public.recettes_commerce ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "recettes_commerce lecture" ON public.recettes_commerce;
CREATE POLICY "recettes_commerce lecture" ON public.recettes_commerce FOR SELECT USING (true);
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.recettes_commerce FROM anon, authenticated;
GRANT SELECT ON public.recettes_commerce TO anon, authenticated;
