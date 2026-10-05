-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927164115
-- Nom original      : socle_pnj_bascule_axes_famille_employe
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 16:41:15 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 07ab506fa5a244db828f431c50a8456c
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
-- CHECKPOINT A2 (3/3) — LES AXES DE LA FAMILLE `employe` PASSENT AU SOCLE
--
-- `employe_recruter` est desormais le seul createur d'un employe, et il ecrit `pnj_membres`. Le
-- socle decide donc, et l'axe doit le dire -- sinon `pnj_pa_garde` refuse pour « axe hors socle »
-- alors que le vrai motif de refus doit etre la CLASSE : un Beta ne consomme pas ses PA.
--
-- Bascule sans phase miroir ni migration de donnees : la production ne contenait aucun employe.
-- Les structures clientes (state.employes, escortActive, group.members) restent alimentees tant que
-- des chemins vivants les lisent -- elles deviennent des PROJECTIONS, comme le blob militaire.
UPDATE public.pnj_axes_autorite SET autorite = 'socle',
       note = 'Bascule du 27/09/2026 : employe_recruter / employe_liberer ecrivent pnj_membres, et '
           || 'la production ne contenait aucun employe a migrer. Les structures clientes '
           || '(state.employes, escort_active) deviennent des projections d''affichage.'
 WHERE famille = 'employe';