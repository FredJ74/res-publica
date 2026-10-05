-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918073538
-- Nom original      : engagements_militaires_fermeture
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-18 07:35:38 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3e7f2ebd6ad94f463140ccf7a1041e0c
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
-- ==========================================================================================
-- FERMETURE DE engagements_militaires
--
-- ORDRE RESPECTE : les producteurs legitimes (filiere officier ET filiere soldat) ont ete migres
-- vers des RPC attestees et DEPLOYES avant cette fermeture. Poser les droits d'abord aurait fait
-- echouer les candidatures en silence.
--
-- La table et les RPC productrices appartiennent a postgres, et relforcerowsecurity est faux :
-- le proprietaire contourne la RLS, donc les SECURITY DEFINER continuent d'ecrire.
--
-- LECTURE OUVERTE, ECRITURE FERMEE. Un Commandant et un Capitaine doivent voir les candidatures
-- qui leur sont adressees, et un Lieutenant celles de sa section : la lecture reste publique,
-- comme avant. Seules les ecritures directes disparaissent.
-- ==========================================================================================
ALTER TABLE public.engagements_militaires ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engagements_militaires_lecture ON public.engagements_militaires;
CREATE POLICY engagements_militaires_lecture ON public.engagements_militaires
  FOR SELECT TO authenticated USING (true);

-- Aucune policy INSERT / UPDATE / DELETE : plus aucun client ne forge ni ne modifie.
REVOKE ALL ON TABLE public.engagements_militaires FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.engagements_militaires FROM authenticated;
GRANT SELECT ON TABLE public.engagements_militaires TO authenticated;