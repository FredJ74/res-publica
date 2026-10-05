-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913131013
-- Nom original      : chantier_b_rls_elections
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 13:10:13 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 69dfae4c7642efe51160e409e06e234c
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
-- ============================================================================
-- CHANTIER B — ELECTIONS
-- 13 septembre 2026.
-- ============================================================================
-- cycles_electoraux : LE BLOB N'EST PLUS ECRIT PAR LE CLIENT.
-- Il contient les candidats ET LE DECOMPTE DES VOIX. Ouvert en ecriture a la cle
-- anon, il permettait a n'importe qui de se declarer elu. Le depot dit pourtant
-- lui-meme, a deux endroits, ce qu'il est reellement : « le blob cycles_electoraux
-- reste un cache best-effort, jamais la source de verite » -- l'autorite, ce sont
-- les tables candidatures et votes_electoraux, que syncCyclesDepuisSupabase()
-- relit. L'ecriture cliente est deja en .catch(() => {}) : sa fermeture ne casse
-- aucun parcours, elle retire simplement au joueur la possibilite de reecrire le
-- resultat. Le cron, sous service_role, continue d'entretenir le blob.
DROP POLICY IF EXISTS allow_all_cycles_electoraux ON public.cycles_electoraux;
DROP POLICY IF EXISTS "Maj publique cycles electoraux" ON public.cycles_electoraux;
DROP POLICY IF EXISTS "Ecriture publique cycles electoraux" ON public.cycles_electoraux;
DROP POLICY IF EXISTS "Lecture publique cycles electoraux" ON public.cycles_electoraux;
CREATE POLICY cycles_electoraux_lecture ON public.cycles_electoraux
  FOR SELECT TO anon, authenticated USING (true);

-- candidatures : on ne se porte candidat que pour SOI.
ALTER TABLE public.candidatures ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS allow_all_candidatures ON public.candidatures;
DROP POLICY IF EXISTS candidatures_lecture ON public.candidatures;
CREATE POLICY candidatures_lecture ON public.candidatures
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS candidatures_depot_soi ON public.candidatures;
CREATE POLICY candidatures_depot_soi ON public.candidatures
  FOR INSERT TO authenticated WITH CHECK (nom = public.mon_personnage());
-- Retrait de sa propre candidature uniquement.
DROP POLICY IF EXISTS candidatures_retrait_soi ON public.candidatures;
CREATE POLICY candidatures_retrait_soi ON public.candidatures
  FOR DELETE TO authenticated USING (nom = public.mon_personnage());

-- votes_electoraux : on ne vote QUE EN SON NOM, et on ne rature jamais un
-- bulletin -- ni le sien, ni celui d'un autre. Aucune policy UPDATE ni DELETE.
ALTER TABLE public.votes_electoraux ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS allow_all_votes_electoraux ON public.votes_electoraux;
DROP POLICY IF EXISTS votes_electoraux_lecture ON public.votes_electoraux;
CREATE POLICY votes_electoraux_lecture ON public.votes_electoraux
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS votes_electoraux_vote_soi ON public.votes_electoraux;
CREATE POLICY votes_electoraux_vote_soi ON public.votes_electoraux
  FOR INSERT TO authenticated WITH CHECK (votant = public.mon_personnage());