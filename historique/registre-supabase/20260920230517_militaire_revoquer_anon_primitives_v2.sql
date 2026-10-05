-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920230517
-- Nom original      : militaire_revoquer_anon_primitives_v2
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 23:05:17 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 87b8b91c6893b194c4a8f9304593751c
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
-- Les DEFAULT PRIVILEGES du schema public reaccordent EXECUTE a anon sur
-- toute fonction creee. Ces cinq-la sont PURES (IMMUTABLE, aucun acces aux
-- tables) et donc inoffensives, mais la doctrine du projet est de ne jamais
-- laisser un droit non voulu : on ferme explicitement.
REVOKE ALL ON FUNCTION public.militaire_degats_pct(text)        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_degre_rang(text)        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_degre_par_rang(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_pa_restants(integer, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_sections_remplacer(jsonb, text, jsonb) FROM PUBLIC, anon;