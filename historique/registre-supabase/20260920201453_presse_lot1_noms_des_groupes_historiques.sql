-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920201453
-- Nom original      : presse_lot1_noms_des_groupes_historiques
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 20:14:53 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b8b7cacdf77c5090463e9711afd8bbc8
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
-- ===========================================================================
-- PRESSE — LOT 1, BAPTEME DES TROIS GROUPES HISTORIQUES (20 septembre 2026)
--
-- Arbitrage GD : pour les trois empires dont le depot ne fournissait aucun nom
-- de groupe attesté, le groupe porte le nom de son titre. La colonne nom reste
-- NULLABLE : un groupe fonde par un PJ pourra exister avant d'etre baptise, et
-- rien dans le modele ne depend de sa presence.
-- ===========================================================================
UPDATE public.groupes_presse g
   SET nom = j.nom
  FROM public.journaux j
 WHERE j.groupe_id = g.id
   AND j.garanti_automatique
   AND g.nom IS NULL;