-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260915220143
-- Nom original      : titulaires_pnj_ecriture_hors_postes_politiques
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-15 22:01:43 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a96c368d0b5f8f7e3c7e2e3dee7623a6
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
-- AUTORITE DES POSTES — la fermeture de titulaires_pnj devait epargner les postes qui ne sont
-- pas politiques.
--
-- La table sert aussi a des titulaires SANS enjeu d'autorite serveur : le pretre d'une ville et
-- le grand pretre, poses par plateau-divers.js lors d'une prise de fonction religieuse. Ils ne
-- figurent pas dans POSTES_NOMMES_EXCLUSIFS, aucune RPC ne s'en sert comme preuve, et les fermer
-- aurait casse le culte sans rien securiser.
--
-- La regle est donc portee par le miroir lui-meme : un client ne peut ecrire dans titulaires_pnj
-- que pour un poste ABSENT de postes_nommes_regles. Les dix-sept postes politiques, eux, ne sont
-- plus attribuables que par les RPC.
GRANT INSERT, UPDATE, DELETE ON public.titulaires_pnj TO authenticated;

DROP POLICY IF EXISTS titulaires_pnj_ecriture_non_politique ON public.titulaires_pnj;
CREATE POLICY titulaires_pnj_ecriture_non_politique ON public.titulaires_pnj
  FOR INSERT TO authenticated
  WITH CHECK (NOT EXISTS (SELECT 1 FROM public.postes_nommes_regles r WHERE r.poste_id = poste_id));

DROP POLICY IF EXISTS titulaires_pnj_maj_non_politique ON public.titulaires_pnj;
CREATE POLICY titulaires_pnj_maj_non_politique ON public.titulaires_pnj
  FOR UPDATE TO authenticated
  USING (NOT EXISTS (SELECT 1 FROM public.postes_nommes_regles r WHERE r.poste_id = titulaires_pnj.poste_id))
  WITH CHECK (NOT EXISTS (SELECT 1 FROM public.postes_nommes_regles r WHERE r.poste_id = titulaires_pnj.poste_id));

DROP POLICY IF EXISTS titulaires_pnj_suppression_non_politique ON public.titulaires_pnj;
CREATE POLICY titulaires_pnj_suppression_non_politique ON public.titulaires_pnj
  FOR DELETE TO authenticated
  USING (NOT EXISTS (SELECT 1 FROM public.postes_nommes_regles r WHERE r.poste_id = titulaires_pnj.poste_id));