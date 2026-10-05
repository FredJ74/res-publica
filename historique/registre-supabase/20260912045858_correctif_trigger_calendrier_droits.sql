-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260912045858
-- Nom original      : correctif_trigger_calendrier_droits
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-12 04:58:58 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : c7285a08d84d9e8d735e89c78697f97f
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
-- CORRECTIF CRITIQUE (12 septembre 2026)
-- La migration calendrier_electoral_dimanche a pose un trigger BEFORE INSERT OR UPDATE sur
-- cycles_electoraux qui appelle cycle_electoral_aligne_dimanche(). Une fonction de trigger
-- s'execute avec les droits de CELUI QUI ECRIT : le client (role anon) n'ayant pas l'EXECUTE sur
-- cette fonction d'aide, TOUTE ecriture cliente d'un cycle electoral etait refusee
--   42501 : permission denied for function cycle_electoral_aligne_dimanche
-- c'est-a-dire : plus aucun cycle ne pouvait etre cree ni sauvegarde depuis le navigateur.
-- Les deux fonctions de trigger passent en SECURITY DEFINER : elles s'executent alors avec les
-- droits du proprietaire, comme le reste du socle, sans rien ouvrir au client (une fonction de
-- trigger n'est pas appelable directement, et l'EXECUTE reste revoque).
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
  IF v_n IS DISTINCT FROM v_d THEN
    NEW.data := v_n::text;
  END IF;
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
  v_d jsonb;
BEGIN
  SELECT CASE WHEN jsonb_typeof(c.data::jsonb) = 'object' THEN c.data::jsonb END INTO v_d
    FROM public.cycles_electoraux c
   WHERE c.country = NEW.country AND c.poste_id = NEW.poste_id
     AND (c.city IS NOT DISTINCT FROM NEW.city);
  IF v_d IS NULL THEN
    RETURN NEW;   -- fail-open : aucun cycle identifiable, comportement inchange
  END IF;
  IF COALESCE((v_d ->> 'resultatsTraites')::boolean, false)
     OR COALESCE(v_d ->> 'phase', '') IN ('mandat', 'vacant')
     OR (jsonb_typeof(v_d -> 'dateDebutCampagne') = 'number'
         AND floor(extract(epoch FROM now()) * 1000)::bigint >= (v_d ->> 'dateDebutCampagne')::numeric::bigint) THEN
    RAISE EXCEPTION 'candidatures_closes';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.candidatures_cloture() FROM PUBLIC, anon, authenticated;