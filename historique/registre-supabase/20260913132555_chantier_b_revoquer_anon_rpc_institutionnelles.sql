-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913132555
-- Nom original      : chantier_b_revoquer_anon_rpc_institutionnelles
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 13:25:55 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a2f188e711461cf0ad2d06b8915a2c25
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
-- PIEGE SUPABASE, RENCONTRE POUR LA TROISIEME FOIS DANS CE PROJET.
-- ALTER DEFAULT PRIVILEGES accorde EXECUTE a anon sur toute nouvelle fonction du
-- schema public. « REVOKE ALL ... FROM PUBLIC » ne l'enleve donc PAS : il faut
-- nommer anon. Les trois RPC creees a l'instant restaient ainsi appelables sans
-- aucune session -- sans danger pratique (exiger_poste et exiger_acteur les
-- refusent faute de personnage rattache), mais un verrou qui ne tient que par la
-- fonction qu'il protege n'est pas un verrou.
REVOKE ALL ON FUNCTION public.justice_prolonger_peine(text, jsonb, boolean) FROM anon;
REVOKE ALL ON FUNCTION public.presidence_gracier(text, integer) FROM anon;
REVOKE ALL ON FUNCTION public.personnage_ajuster_pop_inf(text, text, integer, integer) FROM anon;