-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913203139
-- Nom original      : chantier_c_phase3_miroirs_entreprises
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 20:31:39 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 46a38a8ccc74a3c289aca4281ca692a8
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
-- CHANTIER C / PHASE 3 (13 septembre 2026) — MIROIRS DU CATALOGUE D'ENTREPRISE.
--
-- Meme doctrine que ordres_couts / ressources_economie en phase 2 : le serveur ne peut arbitrer
-- une production, un prix ou une dotation que s'il connait le catalogue REEL. Ces tables ne sont
-- jamais saisies a la main : .scratch/generer_miroirs_entreprises.py charge data.js et
-- plateau-actions-illegales-rumeurs.js dans JavaScriptCore et les regenere. Les dotations
-- pilotes etant des FONCTIONS, le generateur capture leur effet sur un defaut vierge.
--
-- A REJOUER apres toute modification de RECETTES_PRODUCTION, RECETTES_ALIMENTAIRES,
-- DOTATIONS_COMMERCE_PILOTE ou BUILDING_COMMERCE_TYPE.

CREATE TABLE IF NOT EXISTS public.recettes_production (
  id text PRIMARY KEY, ut integer NOT NULL, label text NOT NULL DEFAULT '',
  pays text NOT NULL DEFAULT '', materiaux jsonb NOT NULL DEFAULT '{}'::jsonb);

CREATE TABLE IF NOT EXISTS public.recettes_alimentaires (
  id text PRIMARY KEY, label text NOT NULL DEFAULT '', pa integer NOT NULL DEFAULT 0,
  portions integer NOT NULL DEFAULT 1, materiaux jsonb NOT NULL DEFAULT '{}'::jsonb,
  prix_fixe numeric, type_objet text);

CREATE TABLE IF NOT EXISTS public.commerces_types (
  cle text PRIMARY KEY, type text NOT NULL);

CREATE TABLE IF NOT EXISTS public.commerces_dotations (
  cle text PRIMARY KEY, type text NOT NULL, caisse numeric NOT NULL DEFAULT 0,
  stock_matieres jsonb NOT NULL DEFAULT '{}'::jsonb,
  cout_moyen_matieres jsonb NOT NULL DEFAULT '{}'::jsonb,
  carte jsonb NOT NULL DEFAULT '[]'::jsonb,
  parametres jsonb NOT NULL DEFAULT '{}'::jsonb);

CREATE TABLE IF NOT EXISTS public.armureries_dotations (
  pays text PRIMARY KEY, caisse numeric NOT NULL DEFAULT 0,
  stock_matieres jsonb NOT NULL DEFAULT '{}'::jsonb,
  parametres jsonb NOT NULL DEFAULT '{}'::jsonb);

CREATE TABLE IF NOT EXISTS public.entreprises_constantes (
  cle text PRIMARY KEY, valeur numeric NOT NULL);

-- Miroirs : lecture ouverte (le client affiche deja ces catalogues, ils ne sont pas secrets),
-- ecriture reservee au workflow de migration.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['recettes_production','recettes_alimentaires','commerces_types',
                           'commerces_dotations','armureries_dotations','entreprises_constantes']
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || ' lecture', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT USING (true)', t || ' lecture', t);
    EXECUTE format('REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.%I FROM anon, authenticated', t);
    EXECUTE format('GRANT SELECT ON public.%I TO anon, authenticated', t);
  END LOOP;
END $$;
