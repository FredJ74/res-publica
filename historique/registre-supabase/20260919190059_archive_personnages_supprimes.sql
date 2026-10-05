-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919190059
-- Nom original      : archive_personnages_supprimes
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 19:00:59 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6934e8224a1f270fa101853673b1434b
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
-- ARCHIVAGE AVANT SUPPRESSION D'UN PERSONNAGE.
--
-- POURQUOI. Le diagnostic du 19 septembre 2026 sur la disparition de la fiche
-- V2 de Vince Major Kubrick n'a PAS pu conclure : aucun chemin applicatif
-- identifie ne reproduit cette disparition silencieuse (ni deces, ni succession,
-- et sa ligne `presences` a survecu alors que sbDeletePersonnage la supprime),
-- mais aucune trace ne permet de dater ni de situer ce qui s'est passe.
-- auth.audit_log_entries est vide. Ce garde-fou existe pour que la question
-- soit repondable la prochaine fois.
--
-- IL EST POSE SUR LA TABLE CANONIQUE, pas sur la vue : il couvre donc AUSSI une
-- suppression directe qui contournerait entierement l'application -- c'est
-- precisement le cas que le diagnostic n'a pas pu exclure.
--
-- IL N'EMPECHE RIEN. Il archive puis laisse passer : mort/succession continue
-- de fonctionner a l'identique.
--
-- IL N'INVENTE JAMAIS « QUI A SUPPRIME ». Il n'enregistre que du contexte
-- PostgreSQL reellement disponible. Un appel PostgREST porte un JWT (role, sub)
-- ; une suppression depuis l'editeur SQL n'en porte aucun -- l'absence de JWT
-- est elle-meme une information, mais elle ne designe personne.

CREATE TABLE IF NOT EXISTS public.personnages_supprimes (
  archive_id      bigserial PRIMARY KEY,
  personnage_id   uuid,
  nom             text,
  user_id         uuid,
  ligne           jsonb NOT NULL,          -- copie COMPLETE de la ligne supprimee
  supprime_le     timestamptz NOT NULL DEFAULT now(),
  -- Chemin : 'vue' si la suppression est passee par personnages_vue_supprimer
  -- (donc par l'application), 'direct' si elle a touche la table canonique sans
  -- passer par la vue. C'est un FAIT, pas une imputation.
  chemin          text NOT NULL,
  origine         text,                    -- contexte applicatif explicite, si fourni
  role_sql        text,                    -- current_user
  session_sql     text,                    -- session_user
  jwt_role        text,                    -- absent depuis l'editeur SQL
  jwt_sub         text,
  application     text,
  client_addr     inet,
  backend_pid     integer,
  transaction_id  text,
  requete         text                     -- current_query(), tronquee
);

CREATE INDEX IF NOT EXISTS idx_personnages_supprimes_nom
  ON public.personnages_supprimes (nom, supprime_le DESC);

-- Donnee technique de recuperation : inaccessible aux joueurs, dans les deux
-- sens. RLS activee + AUCUNE policy, plus un REVOKE explicite (les DEFAULT
-- PRIVILEGES du schema public accordent arwdDxtm a anon sur toute table creee).
ALTER TABLE public.personnages_supprimes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.personnages_supprimes FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.personnages_supprimes_archive_id_seq FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.personnages_archiver_suppression()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_claims jsonb;
BEGIN
  BEGIN
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  EXCEPTION WHEN others THEN v_claims := NULL;
  END;

  INSERT INTO public.personnages_supprimes
    (personnage_id, nom, user_id, ligne, chemin, origine,
     role_sql, session_sql, jwt_role, jwt_sub, application, client_addr,
     backend_pid, transaction_id, requete)
  VALUES (
    OLD.id, OLD.name, OLD.user_id, to_jsonb(OLD),
    CASE WHEN coalesce(current_setting('rp.suppression_via_vue', true), '') = '1'
         THEN 'vue' ELSE 'direct' END,
    nullif(current_setting('rp.suppression_origine', true), ''),
    current_user, session_user,
    v_claims ->> 'role', v_claims ->> 'sub',
    nullif(current_setting('application_name', true), ''),
    inet_client_addr(),
    pg_backend_pid(),
    txid_current()::text,
    left(coalesce(current_query(), ''), 2000));

  RETURN OLD;   -- la suppression suit son cours : rien n'est bloque
END;
$function$;

DROP TRIGGER IF EXISTS trg_personnages_archiver_suppression ON public.personnages_donnees;
CREATE TRIGGER trg_personnages_archiver_suppression
  BEFORE DELETE ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_archiver_suppression();

-- La vue signale son passage. Un seul BEFORE DELETE se declenche de toute
-- facon -- celui de la table canonique -- donc AUCUN double archivage n'est
-- possible : ce drapeau ne sert qu'a qualifier le chemin.
CREATE OR REPLACE FUNCTION public.personnages_vue_supprimer()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF OLD.user_id IS NULL OR OLD.user_id <> auth.uid() THEN
      RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE = '42501';
    END IF;
  END IF;
  PERFORM set_config('rp.suppression_via_vue', '1', true);   -- true = LOCAL
  DELETE FROM public.personnages_donnees WHERE id = OLD.id;
  PERFORM set_config('rp.suppression_via_vue', '', true);
  RETURN OLD;
END; $function$;
