-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913130623
-- Nom original      : chantier_b_exiger_acteur_rpc_begin_minuscule
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 13:06:23 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 31ee771743a0f210c7700d28e9e10ac4
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
-- Complement : quatre fonctions Helvetia ecrivent leur bloc en minuscules
-- ("declare ... begin"), que la premiere passe, ancree sur BEGIN majuscule,
-- n'avait pas reconnues. Meme insertion, recherche insensible a la casse.
DO $migration$
DECLARE r record; def text; nouvelle text; faits int := 0; ignores text := '';
BEGIN
  FOR r IN
    SELECT p.oid, p.oid::regprocedure::text AS sig
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
    JOIN pg_language l ON l.oid = p.prolang AND l.lanname = 'plpgsql'
    WHERE p.proname IN ('creer_placement_helvetia','deposer_helvetia','ouvrir_compte_helvetia','retirer_helvetia')
      AND pg_get_functiondef(p.oid) NOT LIKE '%exiger_acteur%'
  LOOP
    def := pg_get_functiondef(r.oid);
    nouvelle := regexp_replace(
      def,
      '(AS \$function\$.*?\n)([ \t]*begin[ \t]*\n)',
      '\1\2  perform public.exiger_acteur(p_personnage);' || chr(10),
      'si');
    IF nouvelle = def THEN
      ignores := ignores || r.sig || '; ';
      CONTINUE;
    END IF;
    EXECUTE nouvelle;
    faits := faits + 1;
  END LOOP;
  RAISE NOTICE 'complement : % gardees, ignorees : %', faits, coalesce(nullif(ignores,''),'aucune');
END
$migration$;