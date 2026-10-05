-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920091001
-- Nom original      : caisse_marqueur_appel_interne
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 09:10:01 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6443b503cb6f8d719a138e598991693d
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
-- =====================================================================
-- MARQUEUR D'APPEL INTERNE POSE DANS LES 13 APPELANTS
-- =====================================================================
-- ALTER FUNCTION ... SET est refuse (le role postgres de Supabase n'est pas
-- superutilisateur : « permission denied to set parameter »). set_config a
-- l'execution fonctionne, en revanche. On injecte donc la pose du marqueur en
-- tete de corps -- par programme, en relisant chaque definition existante, pour
-- ne recopier aucune fonction a la main et ne rien alterer d'autre.
--
-- Le marqueur est LOCAL a la transaction (3e argument = true) : il ne fuit pas
-- d'un appel a l'autre. Un navigateur ne peut pas le poser : set_config vit dans
-- pg_catalog et PostgREST n'expose que le schema public.
DO $marqueur$
DECLARE
  r record;
  v_def text;
  v_nouveau text;
  v_ligne constant text := E'BEGIN\n  PERFORM set_config(''rp.caisse_interne'', ''on'', true);';
  v_faits int := 0;
  v_ignores text := '';
BEGIN
  FOR r IN
    SELECT p.oid, p.proname, p.prolang, l.lanname
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      JOIN pg_language l ON l.oid = p.prolang
     WHERE n.nspname = 'public'
       AND p.prosrc LIKE '%caisse_institution_mouvement%'
       AND p.proname NOT IN ('caisse_institution_mouvement',
                             'caisse_institution_mouvement_plafonne',
                             'caisse_client_mouvement')
  LOOP
    IF r.lanname <> 'plpgsql' THEN
      v_ignores := v_ignores || r.proname || '(langage ' || r.lanname || ') ';
      CONTINUE;
    END IF;

    v_def := pg_get_functiondef(r.oid);

    -- Deja marquee : on ne repasse pas dessus.
    IF v_def LIKE '%rp.caisse_interne%' THEN
      CONTINUE;
    END IF;

    -- Remplace la PREMIERE ligne composee du seul mot BEGIN (celle qui ouvre le
    -- corps, apres l'eventuel bloc DECLARE).
    v_nouveau := regexp_replace(v_def, E'\\mBEGIN\\M', v_ligne, '');

    IF v_nouveau = v_def THEN
      v_ignores := v_ignores || r.proname || '(BEGIN introuvable) ';
      CONTINUE;
    END IF;

    EXECUTE v_nouveau;
    v_faits := v_faits + 1;
  END LOOP;

  RAISE NOTICE 'marquees : % ; ignorees : %', v_faits, coalesce(nullif(v_ignores,''), 'aucune');
END;
$marqueur$;