-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927170630
-- Nom original      : socle_pnj_corriger_soldat_decor_non_recrutable
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 17:06:30 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 0d4688dd80eb7692629fc0d7ddd813c0
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
-- CORRECTIF IMMEDIAT. J'avais declare `soldat.recrutable = true` alors que la note de la meme ligne
-- dit le contraire : « Le PNJ du decor n'est pas recrutable ». La valeur, pas la note, est ce que le
-- code lit -- le bouton de recrutement se serait donc ouvert sur les soldats du decor de la caserne.
-- Detecte par le test, qui listait deux fonctions recrutables au lieu d'une.
--
-- UNE SEULE fonction du decor est recrutable : escort. La famille soldat ALPHA se recrute par la
-- filiere militaire (candidature, affectation), jamais comme employe personnel, et le soldat pose
-- dans le decor de la caserne n'a aucun rapport avec les 96 hommes du socle.
UPDATE public.pnj_fonctions
   SET recrutable = false,
       note = 'Decor de caserne. La fonction `soldat` existe aussi comme famille ALPHA (96 hommes '
           || 'au socle), recrutee par la FILIERE MILITAIRE -- candidature, affectation, section -- '
           || 'et jamais comme employe personnel. Le PNJ du decor n''est pas recrutable.'
 WHERE fonction = 'soldat';