-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920123308
-- Nom original      : fermeture_paris_sportifs
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 12:33:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 07ed56e37f3acaa2bc83c161acd68ff2
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
-- §6.3 — FERMETURE DE paris_sportifs
-- ---------------------------------------------------------------------------
-- SEQUENCEMENT RESPECTE : le producteur legitime a ete migre AVANT cette
-- fermeture. confirmerPariMatch() (plateau-organisations-quetes.js) passe
-- desormais par football_pari_engager(), et les trois wrappers d'acces direct
-- (sbCreerPari, sbResoudrePari, sbGetParisJourneeNonResolus) n'ont plus aucun
-- appelant -- verifie.
--
-- La lecture est fermee elle aussi : aucun ecran n'affiche les paris, le seul
-- lecteur etait sbGetParisJourneeNonResolus, orpheline. La resolution se fait
-- dans football_paris_resoudre, SECURITY DEFINER, que la RLS ne concerne pas.
--
-- Les politiques existantes etaient en USING (true) / WITH CHECK (true) : les
-- laisser en place aurait rendu l'activation de la RLS purement decorative.
-- On les retire, puis RLS active SANS politique = ferme. Le REVOKE traite la
-- seconde couche, celle des GRANT, que les DEFAULT PRIVILEGES du schema public
-- reaccordent a anon sur chaque nouvel objet.

DROP POLICY IF EXISTS "Ecriture publique paris sportifs" ON public.paris_sportifs;
DROP POLICY IF EXISTS "Lecture publique paris sportifs"  ON public.paris_sportifs;
DROP POLICY IF EXISTS "Maj publique paris sportifs"      ON public.paris_sportifs;

ALTER TABLE public.paris_sportifs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.paris_sportifs FROM anon, authenticated, public;