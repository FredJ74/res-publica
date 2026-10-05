-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920132755
-- Nom original      : fermeture_guerres
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 13:27:55 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 2334bf529b947bd805e70f38c158da01
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
-- §6.3 — FERMETURE DE guerres
-- SEQUENCEMENT RESPECTE : les trois portes serveur existent, le client est migre,
-- et les deux wrappers d'ecriture directe (sbCreerGuerre, sbMajGuerre) n'ont plus
-- aucun appelant -- verifie.
--
-- LA LECTURE RESTE OUVERTE : l'etat de guerre entre deux empires est une
-- information publique, lue par les ecrans diplomatiques, l'effort de guerre et
-- l'immunite militaire. Le correctif du chargement de `statut` cote client
-- accompagne cette fermeture -- sans lui, le predicat de guerre resterait faux
-- en permanence et la fermeture n'aurait rien change a l'observabilite.

DROP POLICY IF EXISTS "Ecriture publique guerres" ON public.guerres;
DROP POLICY IF EXISTS "Lecture publique guerres"  ON public.guerres;
DROP POLICY IF EXISTS "Maj publique guerres"      ON public.guerres;

CREATE POLICY guerres_lecture ON public.guerres
  FOR SELECT TO anon, authenticated USING (true);

ALTER TABLE public.guerres ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE ON public.guerres FROM anon, authenticated, public;