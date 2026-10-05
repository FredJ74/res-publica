-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924084226
-- Nom original      : militaire_revoquer_anon_reliquat
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-24 08:42:26 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ce3711fcdd14712687171d075fafd61d
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
-- =============================================================================================
-- RELIQUAT DE DROITS ANONYMES SUR LES RPC MILITAIRES (24 septembre 2026)
-- =============================================================================================
-- CONSTAT. Le releve exhaustif des 105 fonctions militaires deployees a montre que NEUF d'entre
-- elles restent executables par le role `anon`. Trois ECRIVENT :
--   militaire_mutinerie_declencher  -- cree un camp mutin et rallie des soldats
--   militaire_ration_consommer      -- modifie PA et inventaire
--   militaire_reposer_section       -- modifie les PA de toute une section
-- Les six autres sont en lecture, mais cinq exposent des positions de troupes.
--
-- CE N'EST PAS UNE BRECHE EXPLOITABLE AUJOURD'HUI : toutes se protegent en interne par
-- mon_personnage(), qui rend NULL pour un appelant anonyme -- elles repondent donc
-- acteur_non_authentifie. Mais le GRANT lui-meme contredit une doctrine deja ecrite dans ce
-- depot (migration_militaire_revoquer_anon.sql) : aucune RPC militaire ne doit etre offerte au
-- role anonyme. Une protection qui ne tient que par le contenu de la fonction tombe le jour ou
-- quelqu'un la modifie sans y penser.
--
-- CE QUE CELA NE CASSE PAS : les appels INTERNES. exiger_poste est appelee par des fonctions
-- SECURITY DEFINER, qui s'executent sous leur proprietaire et ne dependent pas de ce GRANT.
-- Les joueurs, eux, sont `authenticated` et conservent tous leurs droits.
-- =============================================================================================

REVOKE EXECUTE ON FUNCTION public.exiger_poste(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.militaire_mutinerie_declencher() FROM anon;
REVOKE EXECUTE ON FUNCTION public.militaire_ration_consommer() FROM anon;
REVOKE EXECUTE ON FUNCTION public.militaire_reposer_section(text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.mutinerie_camp_de(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.mutinerie_camps_presents(text, text, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.mutinerie_est_camp(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.mutinerie_pays_du_camp(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.mutinerie_social_national(text) FROM anon;