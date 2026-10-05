-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913004631
-- Nom original      : effort_guerre_durcissement_droits_rpc
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 00:46:31 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 050088a3cb5f47992e88deb8af78951c
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
-- DURCISSEMENT DES DROITS.
-- Supabase applique des ALTER DEFAULT PRIVILEGES qui accordent EXECUTE a anon et authenticated
-- sur toute nouvelle fonction du schema public. Un simple « REVOKE ALL FROM PUBLIC » ne les
-- retire donc PAS : il faut nommer les roles. Sans cela, les trois operations purement nocturnes
-- (mouvement brut de stock militaire, ravitaillement, production) auraient ete appelables
-- directement avec la cle anon, c'est-a-dire depuis n'importe quel navigateur.
REVOKE EXECUTE ON FUNCTION public.caserne_stock_mouvement(text, text, integer, text)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.effort_ravitailler(text, jsonb, jsonb, jsonb)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.effort_produire_lot(text, text, text, jsonb, jsonb, numeric, text, text, text, integer)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.caserne_stock_mouvement(text, text, integer, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.effort_ravitailler(text, jsonb, jsonb, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.effort_produire_lot(text, text, text, jsonb, jsonb, numeric, text, text, text, integer) TO service_role;

-- Les quatre RPC declenchees par un joueur restent ouvertes a anon : le jeu n'a pas d'autre
-- identite. Toute leur validation (poste, presence physique, stock, marqueur quotidien) est
-- SERVEUR, et aucune ne permet de creer une ressource.
GRANT EXECUTE ON FUNCTION public.effort_reserve_appliquer(text, jsonb, text[], numeric) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.militaire_retrait(text, text, integer, text, text, integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.militaire_subtiliser(text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.refectoire_repas(text, text, integer, integer, integer) TO anon, authenticated, service_role;