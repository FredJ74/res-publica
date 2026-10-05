-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927175007
-- Nom original      : socle_pnj_renseignement_aligner_dup_referentiel_metier
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 17:50:07 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 34df151c3e6175f219d559a32ccf7e89
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
-- CORRECTIF D'INCOHERENCE QUE MA PROPRE MIGRATION CREAIT. Le trigger alignait bien la DUP de chaque
-- nouvelle mission sur le socle (13), mais `cellule_renseignement_creer` construit son JSON de
-- retour a partir de `renseignement_identites_reelles.dup` AVANT que le trigger n'agisse : le
-- ministre recevait donc 10/12/15 alors que la base portait 13. Deux verites visibles, ce qui est
-- exactement ce que la convergence doit supprimer.
--
-- La table metier est donc ALIGNEE sur le socle. Elle ne redevient pas la source pour autant -- les
-- deux lecteurs mecaniques lisent pnj_membres.car_dup, et le trigger reste en place comme ceinture
-- si quelqu'un modifiait cette table. L'alignement ne fait que supprimer le desaccord d'affichage.
--
-- L'HISTORIQUE N'EST PAS TOUCHE : les occurrences de mission terminees conservent la DUP qu'elles
-- avaient reellement (10, 12, 15), et le comparateur ne verifie l'alignement que sur les missions
-- ACTIVES. Une mission passee ne se reecrit pas.
UPDATE public.renseignement_identites_reelles i
   SET dup = m.car_dup
  FROM public.pnj_membres m
 WHERE m.id = public.renseignement_pnj_id(i.role) AND i.dup IS DISTINCT FROM m.car_dup;