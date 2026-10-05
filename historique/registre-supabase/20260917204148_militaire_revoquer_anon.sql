-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917204148
-- Nom original      : militaire_revoquer_anon
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 20:41:48 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 32a4787c7feb90b84de079460d839cc5
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
-- Le role anon n'a aucun usage legitime sur une RPC mutante : un client en role anon ne peut pas
-- sauvegarder de personnage (personnages_donnees n'accorde INSERT/UPDATE/DELETE qu'a authenticated),
-- donc pas jouer. Les comptes anonymes du jeu portent une session JWT et le role authenticated.
-- Ces deux fonctions sont deja protegees par exiger_acteur (qui echouerait de toute facon sans
-- auth.uid()) : ce retrait supprime une surface heritee, il ne change aucun comportement legitime.
-- PUBLIC est nomme explicitement : PostgreSQL accorde EXECUTE a PUBLIC par defaut.
REVOKE ALL ON FUNCTION public.militaire_retrait(text, text, integer, text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_retrait(text, text, integer, text, text, integer) FROM anon;

REVOKE ALL ON FUNCTION public.militaire_subtiliser(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_subtiliser(text, text) FROM anon;