-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920225942
-- Nom original      : militaire_mon_pays_pour_policies
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 22:59:42 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 9c689a60d8147e1148190cca4175a33c
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
-- Les policies de confidentialite militaire lisaient personnages_donnees
-- directement. Or une policy s'evalue avec les droits du ROLE APPELANT, et
-- `authenticated` n'a aucun droit sur cette table (seule la vue lui est
-- accordee) : toute lecture levait « permission denied for table
-- personnages_donnees ». Meme piege que celui deja resolu par mon_personnage().
CREATE OR REPLACE FUNCTION public.militaire_mon_pays()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $function$
  SELECT d.country FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() LIMIT 1;
$function$;

REVOKE ALL ON FUNCTION public.militaire_mon_pays() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_mon_pays() TO authenticated, service_role;

DROP POLICY IF EXISTS compagnies_lecture_mon_pays ON public.compagnies_militaires;
CREATE POLICY compagnies_lecture_mon_pays ON public.compagnies_militaires
  FOR SELECT TO authenticated
  USING (data->>'pays' = public.militaire_mon_pays());

DROP POLICY IF EXISTS services_militaires_lecture ON public.services_militaires;
CREATE POLICY services_militaires_lecture ON public.services_militaires
  FOR SELECT TO authenticated
  USING (pays = public.militaire_mon_pays());