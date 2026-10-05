-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913125527
-- Nom original      : sauvegarde_integrale_avant_reset_beta
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 12:55:27 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4ea0699aeca7e1239289f8195ff4bb3c
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
-- ============================================================================
-- SAUVEGARDE INTEGRALE AVANT REINITIALISATION DE LA BETA
-- 13 septembre 2026. Feu vert donne, beta-testeurs prevenus sur Discord.
-- ============================================================================
-- POURQUOI DANS LA BASE ET PAS UN FICHIER. Je n'ai pas de connexion directe
-- permettant un pg_dump : mes outils n'exposent que du SQL. Une copie de schema
-- a schema est donc la sauvegarde la PLUS complete dont je dispose -- elle prend
-- tout, y compris les 49 360 lignes d'historique_deplacements, sans passer par
-- un transport texte qui pourrait tronquer ou reencoder quoi que ce soit.
-- Elle est immediatement exploitable : un INSERT ... SELECT suffit a restaurer.
--
-- PORTEE : TOUTES les tables du schema public, pas seulement celles que le reset
-- va toucher. Une sauvegarde partielle ne protege que ce qu'on avait prevu de
-- casser -- ce qui est exactement ce dont on n'a pas besoin.
DROP SCHEMA IF EXISTS sauvegarde_beta_20260913 CASCADE;
CREATE SCHEMA sauvegarde_beta_20260913;

DO $$
DECLARE r record; n bigint; total bigint := 0; tables int := 0;
BEGIN
  FOR r IN
    SELECT c.relname AS t
    FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
    WHERE ns.nspname = 'public' AND c.relkind = 'r'
    ORDER BY c.relname
  LOOP
    EXECUTE format('CREATE TABLE sauvegarde_beta_20260913.%I AS TABLE public.%I', r.t, r.t);
    EXECUTE format('SELECT count(*) FROM sauvegarde_beta_20260913.%I', r.t) INTO n;
    total := total + n; tables := tables + 1;
  END LOOP;
  RAISE NOTICE 'Sauvegarde : % tables, % lignes', tables, total;
END $$;

-- La sauvegarde n'est accessible qu'au serveur : ni anon ni authenticated ne
-- doivent pouvoir relire les donnees qu'on vient justement de mettre a l'abri.
REVOKE ALL ON SCHEMA sauvegarde_beta_20260913 FROM PUBLIC, anon, authenticated;

COMMENT ON SCHEMA sauvegarde_beta_20260913 IS
  'Sauvegarde integrale du 13 septembre 2026, prise juste avant la reinitialisation de la beta. Restauration : INSERT INTO public.<t> SELECT * FROM sauvegarde_beta_20260913.<t>.';