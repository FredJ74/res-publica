-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914105429
-- Nom original      : inventaire_primitives_pures_fermees_anon
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-14 10:54:29 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 07a091c14c365150cbda65a7eea41396
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
-- Coherence des droits. Les quatre primitives pures d'inventaire (anterieures a ce lot) etaient
-- joignables par anon, par l'effet d'ALTER DEFAULT PRIVILEGES. Elles sont inoffensives -- ce sont
-- des fonctions IMMUTABLE qui transforment un jsonb passe en argument, sans aucun acces a la
-- base ni effet de bord -- mais aucun appelant navigateur ne les utilise (verifie : zero
-- occurrence dans les sources), et leurs seuls appelants reels sont des fonctions SECURITY
-- DEFINER qui s'executent avec les droits du proprietaire.
-- On aligne donc leur exposition sur celle des trois primitives ajoutees par ce lot, plutot que
-- de laisser deux regles differentes pour des fonctions de meme nature.
REVOKE ALL ON FUNCTION public.inventaire_ajouter(jsonb, text, integer, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.inventaire_retirer(jsonb, text, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.inventaire_quantite(jsonb, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.inventaire_place_restante(jsonb) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.inventaire_ajouter(jsonb, text, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inventaire_retirer(jsonb, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inventaire_quantite(jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inventaire_place_restante(jsonb) TO authenticated;
