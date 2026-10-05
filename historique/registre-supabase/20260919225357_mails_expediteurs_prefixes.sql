-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919225357
-- Nom original      : mails_expediteurs_prefixes
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-19 22:53:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : fc419c7df5aca3d3e26ea92cdf5bd797
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
-- Un expediteur systeme peut etre un PREFIXE dynamique :
--   plateau-politique.js:9384  sbSendMail('Lieutenant ' + (state.char?.name || ''), ...)
-- produit « Lieutenant Arnie ». Un libelle fixe ne peut pas le couvrir.
ALTER TABLE public.mails_expediteurs_systeme
  ADD COLUMN IF NOT EXISTS est_prefixe boolean NOT NULL DEFAULT false;

DELETE FROM public.mails_expediteurs_systeme WHERE expediteur = 'Lieutenant';
INSERT INTO public.mails_expediteurs_systeme (expediteur, note, est_prefixe)
VALUES ('Lieutenant ', 'prefixe : « Lieutenant <nom> », hierarchie militaire', true)
ON CONFLICT (expediteur) DO UPDATE SET est_prefixe = true, note = EXCLUDED.note;

CREATE OR REPLACE FUNCTION public.mail_expediteur_systeme(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.mails_expediteurs_systeme m
     WHERE (NOT m.est_prefixe AND m.expediteur = p_nom)
        OR (m.est_prefixe AND p_nom LIKE m.expediteur || '%')
  );
$$;