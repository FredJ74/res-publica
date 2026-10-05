-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920123900
-- Nom original      : plaintes_champs_judiciaires_epingles
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 12:39:00 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f5f0863dd933ff3774b9eeecf2dabf74
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
-- §6.3 — L'ACCUSE PEUT SE DEFENDRE, PAS SE JUGER
-- ---------------------------------------------------------------------------
-- La politique posee juste avant ouvre la ligne de l'affaire a l'accuse : il en
-- a besoin pour ecrire sa defense (doDefense). Mais une politique RLS raisonne
-- par LIGNE, pas par champ : elle lui ouvrait donc aussi `status` et
-- `sentence`. Le banc l'a montre immediatement -- l'accuse pouvait ecrire
-- « status: jugee, sentence: relaxe » sur sa propre affaire. Refermer un exploit
-- en en ouvrant un plus etroit n'est pas le refermer.
--
-- Le bon outil n'est pas une politique mais un TRIGGER, exactement la doctrine
-- deja employee sur la fiche du personnage (personnages_vue_modifier) : on ne
-- REFUSE pas l'ecriture, on EPINGLE les champs que l'auteur n'a pas le droit de
-- changer. La defense passe, le verdict ne bouge pas.
--
-- Qui peut toucher au verdict : l'autorite judiciaire de la ville de l'affaire,
-- et le serveur. Personne d'autre -- pas meme le plaignant.

CREATE OR REPLACE FUNCTION public.plaintes_epingler_verdict()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old jsonb; v_new jsonb; v_cle text;
  -- Champs qui disent l'issue judiciaire. Tout le reste (defense, pieces,
  -- circonstances) reste librement modifiable par les parties.
  v_verdict constant text[] := ARRAY['status','sentence','peine','jugement','juge',
                                     'circonstanceAttenuante','aggravation'];
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF public.affaire_autorite_de(NEW.city) THEN RETURN NEW; END IF;

  -- L'auteur n'est pas l'autorite judiciaire : on restaure les champs de verdict
  -- tels qu'ils etaient. Si l'un d'eux est illisible, on ne prend aucun risque.
  IF OLD.data IS NULL OR left(btrim(OLD.data), 1) <> '{'
     OR NEW.data IS NULL OR left(btrim(NEW.data), 1) <> '{' THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_old := OLD.data::jsonb;
    v_new := NEW.data::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
  END;

  FOREACH v_cle IN ARRAY v_verdict LOOP
    IF (v_new -> v_cle) IS DISTINCT FROM (v_old -> v_cle) THEN
      IF (v_old ? v_cle) THEN
        v_new := jsonb_set(v_new, ARRAY[v_cle], v_old -> v_cle);
      ELSE
        v_new := v_new - v_cle;   -- le champ n'existait pas : il n'apparait pas
      END IF;
    END IF;
  END LOOP;

  NEW.data := v_new::text;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_plaintes_epingler_verdict ON public.plaintes_en_cours;
CREATE TRIGGER trg_plaintes_epingler_verdict
  BEFORE UPDATE ON public.plaintes_en_cours
  FOR EACH ROW EXECUTE FUNCTION public.plaintes_epingler_verdict();