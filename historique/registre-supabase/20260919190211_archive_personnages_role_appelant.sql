-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919190211
-- Nom original      : archive_personnages_role_appelant
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 19:02:11 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 76e8739ffbde410314c88fe10f73b423
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
-- Affinage : capter le role REEL de l'appelant.
--
-- Defaut constate au banc : current_user, dans une fonction SECURITY DEFINER,
-- vaut le PROPRIETAIRE de la fonction (postgres) -- jamais l'appelant. La
-- colonne role_sql etait donc sans valeur diagnostique.
--
-- current_setting('role') reflete en revanche le SET ROLE effectif : il rend
-- 'authenticated' pour un appel PostgREST, et 'none' quand aucun SET ROLE n'a
-- eu lieu -- auquel cas on retombe sur session_user, qui n'est jamais masque
-- par SECURITY DEFINER. On distingue ainsi un appel applicatif d'une
-- suppression lancee directement en session privilegiee, SANS jamais designer
-- une personne.
CREATE OR REPLACE FUNCTION public.personnages_archiver_suppression()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_claims jsonb; v_role text;
BEGIN
  BEGIN
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  EXCEPTION WHEN others THEN v_claims := NULL;
  END;

  v_role := nullif(current_setting('role', true), 'none');
  IF v_role IS NULL OR v_role = '' THEN v_role := session_user; END IF;

  INSERT INTO public.personnages_supprimes
    (personnage_id, nom, user_id, ligne, chemin, origine,
     role_sql, session_sql, jwt_role, jwt_sub, application, client_addr,
     backend_pid, transaction_id, requete)
  VALUES (
    OLD.id, OLD.name, OLD.user_id, to_jsonb(OLD),
    CASE WHEN coalesce(current_setting('rp.suppression_via_vue', true), '') = '1'
         THEN 'vue' ELSE 'direct' END,
    nullif(current_setting('rp.suppression_origine', true), ''),
    v_role, session_user,
    v_claims ->> 'role', v_claims ->> 'sub',
    nullif(current_setting('application_name', true), ''),
    inet_client_addr(),
    pg_backend_pid(),
    txid_current()::text,
    left(coalesce(current_query(), ''), 2000));

  RETURN OLD;
END;
$function$;
