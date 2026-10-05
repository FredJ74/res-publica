-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926131517
-- Nom original      : socle_pnj_snapshot_militaire_avant_bascule
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 13:15:17 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6e0cf74d755ba0ec85f1d1439f4a715b
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
-- SNAPSHOT AUTORITAIRE DE L'ETAT MILITAIRE AVANT LA BASCULE DU SOCLE PNJ
-- 26 septembre 2026. Feu vert explicite du concepteur.
--
-- C'est le filet de securite de toute la bascule. Il contient la ligne complete de
-- compagnies_militaires, blob compris, telle qu'elle etait AVANT qu'une seule ligne du socle
-- n'existe. Une restauration exacte consiste a reecrire data depuis cette table.
--
-- Il est cree AVANT tout : ni pnj_membres, ni copie, ni bascule de lecture n'existent encore.
-- Etat constate a l'instant du snapshot, conforme au rapport valide :
--   1 compagnie, 24 soldats en section, 72 en reserve, 4 sections, total 96
--   updated_at = 2026-09-22 22:29:35.196405+00 (inchange depuis le 22 septembre)

CREATE TABLE public.compagnies_militaires_snapshot_20260926 AS
  SELECT c.*, now() AS snapshot_le,
         'Avant bascule du socle PNJ/groupes/leaders. Feu vert du 26 septembre 2026.'::text AS motif
    FROM public.compagnies_militaires c;

ALTER TABLE public.compagnies_militaires_snapshot_20260926
  ADD CONSTRAINT snapshot_20260926_pk PRIMARY KEY (id);

REVOKE ALL ON public.compagnies_militaires_snapshot_20260926 FROM anon, authenticated, PUBLIC;

COMMENT ON TABLE public.compagnies_militaires_snapshot_20260926 IS
  'Snapshot autoritaire de compagnies_militaires pris le 26 septembre 2026, juste avant la '
  'bascule du socle PNJ. NE PAS SUPPRIMER avant validation de la recette reelle par le joueur. '
  'Restauration exacte : UPDATE compagnies_militaires c SET data = s.data, updated_at = s.updated_at '
  'FROM compagnies_militaires_snapshot_20260926 s WHERE s.id = c.id;';