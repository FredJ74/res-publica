-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260925074330
-- Nom original      : securite_qhs_colonne_detentions
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-25 07:43:30 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6c96d7c3814bf3d95b3acc3ce1ceda94
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
-- PIEGE POSTGRESQL, ATTRAPE PAR LE BANC. `REVOKE SELECT (qhs)` est INOPERANT tant que le role
-- detient un GRANT SELECT au niveau TABLE : un droit de table couvre toutes les colonnes et ne se
-- laisse pas reduire colonne par colonne. Le banc l'a montre -- la colonne restait lue.
-- La forme correcte : retirer le droit de table, puis accorder la liste explicite des colonnes.
REVOKE SELECT ON public.detentions FROM anon, authenticated;

-- Les archives judiciaires restent publiques pour les JOUEURS -- l'ordre archives_police se
-- decrit comme « consultables par tous » -- mais sans la colonne `qhs`.
GRANT SELECT (
  id, country, city, nom, raison, jour_debut, jour_fin, created_at, motifs, jour_affaire,
  issue_judiciaire, autorite, ville_condamnation, jour_fin_effective, mode_fin, reduction_jours,
  detention_precedente_id, reliquat_jours, date_fin_effective, provenance
) ON public.detentions TO authenticated;

-- `anon` ne recoit rien : un visiteur sans compte n'a aucun acces IG aux archives judiciaires.
-- La salle des geoles et le cron continuent de passer par geoles_detenus() (SECURITY DEFINER).