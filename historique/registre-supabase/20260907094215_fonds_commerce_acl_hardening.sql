-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260907094215
-- Nom original      : fonds_commerce_acl_hardening
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-07 09:42:15 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : bbdb5a78b8b57a041e819731a487adc4
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
REVOKE EXECUTE ON FUNCTION mouvement_titulaire(text, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION mouvement_titulaire(text, numeric) TO service_role;

REVOKE EXECUTE ON FUNCTION vendre_fonds_commerce(text, text, text, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION vendre_fonds_commerce(text, text, text, integer) TO service_role;

REVOKE EXECUTE ON FUNCTION terminer_bail(text, text, text, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION terminer_bail(text, text, text, integer) TO service_role;