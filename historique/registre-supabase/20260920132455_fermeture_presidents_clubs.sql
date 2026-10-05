-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920132455
-- Nom original      : fermeture_presidents_clubs
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 13:24:55 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : af31d0720f5186ade420c075e99f845b
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
-- §6.3 — FERMETURE DE presidents_clubs
-- ---------------------------------------------------------------------------
-- SEQUENCEMENT RESPECTE : les trois portes serveur existent et sont testees, le
-- client a ete migre, et les deux wrappers d'ecriture directe (sbSavePresidentClub,
-- getElecteursClub) n'ont plus aucun appelant -- verifie.
--
-- chargerPresidentClub() a par ailleurs cesse d'ECRIRE a la lecture : elle creait
-- la ligne quand elle n'existait pas. La ligne est desormais creee par le serveur,
-- au depot de la premiere candidature.
--
-- La LECTURE reste ouverte : le nom du president d'un club est une information
-- publique, affichee au bureau du president et lue par le circuit des transferts.
--
-- Les politiques existantes etaient en USING (true) / WITH CHECK (true) : les
-- laisser aurait rendu l'activation de la RLS purement decorative.

DROP POLICY IF EXISTS "Ecriture publique presidents clubs" ON public.presidents_clubs;
DROP POLICY IF EXISTS "Lecture publique presidents clubs"  ON public.presidents_clubs;
DROP POLICY IF EXISTS "Maj publique presidents clubs"      ON public.presidents_clubs;

CREATE POLICY presidents_clubs_lecture ON public.presidents_clubs
  FOR SELECT TO anon, authenticated USING (true);

ALTER TABLE public.presidents_clubs ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE ON public.presidents_clubs FROM anon, authenticated, public;