-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916125259
-- Nom original      : championnat_verrou_post_compte_rendu
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 12:52:59 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4d8291115f4aad14860e93c509c2d8bf
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
-- Le sujet refuse, son message ne doit pas rester orphelin : sans cela, le compte rendu
-- s'afficherait quand meme la ou le forum liste les messages, et le verrou serait decoratif.
CREATE OR REPLACE FUNCTION public.forum_verrou_message_ligue()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF NEW.author = 'Ligue Officielle'
     AND NOT EXISTS (SELECT 1 FROM public.forum_topics t WHERE t.id = NEW.topic_id) THEN
    INSERT INTO public.championnat_tentatives (acteur, decision, raison)
    VALUES (auth.uid(), 'refus', 'message_ligue_sans_sujet');
    RETURN NULL;
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_forum_verrou_message_ligue ON public.forum_posts;
CREATE TRIGGER trg_forum_verrou_message_ligue
  BEFORE INSERT ON public.forum_posts
  FOR EACH ROW EXECUTE FUNCTION public.forum_verrou_message_ligue();