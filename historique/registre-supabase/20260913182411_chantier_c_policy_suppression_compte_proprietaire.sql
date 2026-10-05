-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913182411
-- Nom original      : chantier_c_policy_suppression_compte_proprietaire
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 18:24:11 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f1f192dcf42d19535dba5a9062894bc2
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
-- Defaut constate en exploitation (13 septembre 2026) : comptes_bancaires avait
-- des policies SELECT, INSERT et UPDATE pour le proprietaire, mais AUCUNE pour la
-- suppression. La destruction d'un personnage laissait donc derriere elle un
-- compte orphelin -- et l'echec etait silencieux, PostgREST repondant 204 sur une
-- suppression qui ne touche aucune ligne.
--
-- Un joueur peut deja detruire son personnage (policy personnages_suppression_soi)
-- et fermer son compte Helvetia par RPC : pouvoir supprimer SON compte ne lui
-- donne aucun pouvoir nouveau, et surement pas sur autrui.
DROP POLICY IF EXISTS comptes_bancaires_proprietaire_suppression ON public.comptes_bancaires;
CREATE POLICY comptes_bancaires_proprietaire_suppression ON public.comptes_bancaires
  FOR DELETE TO authenticated
  USING (personnage = public.mon_personnage());

-- Purge des comptes orphelins laisses par les bancs (aucun personnage reel).
DELETE FROM public.comptes_bancaires c
WHERE NOT EXISTS (SELECT 1 FROM public.personnages_donnees p WHERE p.name = c.personnage);