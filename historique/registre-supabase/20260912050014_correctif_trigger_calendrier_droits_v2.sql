-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260912050014
-- Nom original      : correctif_trigger_calendrier_droits_v2
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-12 05:00:14 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f1c2afbee3cd55e6a61dbd5f4344af7c
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
-- Retablit le corps EXACT des deux fonctions de trigger du calendrier, en n'ajoutant que
-- SECURITY DEFINER (correctif du 42501 sur cycle_electoral_aligne_dimanche). Aucune autre
-- difference avec migration_calendrier_electoral_dimanche.sql.
CREATE OR REPLACE FUNCTION public.cycles_electoraux_dimanche()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_d jsonb;
  v_n jsonb;
BEGIN
  BEGIN v_d := NEW.data::jsonb; EXCEPTION WHEN OTHERS THEN RETURN NEW; END;
  v_n := public.cycle_electoral_aligne_dimanche(v_d, now());
  IF v_n IS DISTINCT FROM v_d THEN NEW.data := v_n::text; END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.cycles_electoraux_dimanche() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.candidatures_cloture()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_data text;
  v_d    jsonb;
  v_ms   numeric := floor(extract(epoch FROM now()) * 1000);
BEGIN
  SELECT data INTO v_data FROM public.cycles_electoraux
   WHERE id = NEW.country || '_' || NEW.poste_id || CASE WHEN NEW.city IS NOT NULL THEN '_' || NEW.city ELSE '' END;
  IF NOT FOUND THEN RETURN NEW; END IF;          -- cycle cree par le client juste avant la candidature
  BEGIN v_d := v_data::jsonb; EXCEPTION WHEN OTHERS THEN RETURN NEW; END;
  IF COALESCE((v_d ->> 'resultatsTraites')::boolean, false)
     OR COALESCE(v_d ->> 'phase', '') IN ('mandat', 'vacant')
     OR (jsonb_typeof(v_d -> 'dateDebutCampagne') = 'number' AND v_ms >= (v_d ->> 'dateDebutCampagne')::numeric) THEN
    RAISE EXCEPTION 'candidatures_closes' USING HINT = 'Les candidatures a ce scrutin sont closes (cloture du lundi 00:01).';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.candidatures_cloture() FROM PUBLIC, anon, authenticated;