-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920123041
-- Nom original      : fermeture_lois_assemblee_morte
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 12:30:41 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 28d525df5497906257d773d53fd7bf31
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
-- §6.3 — FERMETURE DE lois_assemblee
-- ---------------------------------------------------------------------------
-- EXPLOIT MESURE : un joueur ordinaire pouvait promulguer une loi (INSERT
-- reussi sous veritable role authenticated).
--
-- INVENTAIRE DES PRODUCTEURS : AUCUN. Les deux seuls wrappers clients
-- (sbArchiverLoi / sbGetArchivesLois, supabase.js) n'ont plus le moindre
-- appelant -- ni en ecriture, ni en LECTURE. Le moteur de l'Assemblee a ete
-- refait le 10 septembre 2026 : il stocke un vote par ligne (assemblee_votes)
-- et la cloture est faite par le serveur (assemblee_cloturer). Le code le dit
-- lui-meme (plateau-politique.js, vers la ligne 4607) : « La table
-- lois_assemblee et ses wrappers sont laisses en place : ils ne sont plus
-- appeles par personne [...]. Signale au rapport. »
--
-- Fermer cette table ne peut donc casser aucun flux legitime : il n'y en a pas.
--
-- POURQUOI ACTIVER LA RLS NE SUFFIT PAS. Les politiques posees sur cette table
-- sont en USING (true) / WITH CHECK (true) -- « Ecriture publique lois
-- assemblee », « Maj publique ». Les laisser en place et activer la RLS ne
-- changerait strictement RIEN : elles autorisent tout le monde. On les retire,
-- puis RLS active SANS politique = ferme. Le GRANT est revoque en plus, parce
-- que les DEFAULT PRIVILEGES du schema public reaccordent tout a anon sur
-- chaque nouvel objet : les deux couches doivent etre traitees separement.
-- service_role continue de contourner la RLS, comme partout ailleurs.

DROP POLICY IF EXISTS "Ecriture publique lois assemblee" ON public.lois_assemblee;
DROP POLICY IF EXISTS "Lecture publique lois assemblee"  ON public.lois_assemblee;
DROP POLICY IF EXISTS "Maj publique lois assemblee"      ON public.lois_assemblee;

ALTER TABLE public.lois_assemblee ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lois_assemblee FROM anon, authenticated, public;