-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260923070212
-- Nom original      : pj_militaire_repos_nocturne
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-23 07:02:12 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 9f44e5baae0447ac9598d38a7be83dad
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
CREATE OR REPLACE FUNCTION public.pa_repos_nocturne(p_acteur text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa_max         constant integer := 30;
  c_gain_civil     constant integer := 12;
  c_gain_caserne   constant integer := 12;
  c_gain_terrain   constant integer := 8;
  c_bonus_tente    constant integer := 2;
  v_pa integer; v_qhs jsonb; v_bonus integer; v_deja date;
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_nouveau integer; v_plafond_qhs integer;
  v_caserne boolean; v_tente boolean; v_grade text; v_gain integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT coalesce(pa, 0), detention_qhs, coalesce(bonus_pa_differe, 0), pa_repos_le,
         coalesce(current_building, '') = 'caserne-militaire',
         EXISTS (SELECT 1 FROM jsonb_array_elements(
                   CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) i
                  WHERE i->>'produitMilitaire' = 'tente')
    INTO v_pa, v_qhs, v_bonus, v_deja, v_caserne, v_tente
    FROM public.personnages_donnees d WHERE d.name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  IF v_deja IS NOT NULL AND v_deja >= v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_repose', 'pa', v_pa);
  END IF;

  IF v_qhs IS NOT NULL AND jsonb_typeof(v_qhs) = 'object' AND (v_qhs ->> 'enQHS')::boolean IS TRUE THEN
    v_plafond_qhs := CASE WHEN (v_qhs ->> 'paLimite1Jour')::boolean IS TRUE THEN 1 ELSE 3 END;
    v_nouveau := least(c_pa_max, greatest(0, v_plafond_qhs + v_bonus));
    IF (v_qhs ->> 'paLimite1Jour')::boolean IS TRUE THEN
      UPDATE public.personnages_donnees
         SET detention_qhs = v_qhs || jsonb_build_object('paLimite1Jour', false)
       WHERE name = p_acteur;
    END IF;
  ELSE
    v_grade := public.militaire_grade_effectif(p_acteur);
    IF v_grade IS NULL THEN
      v_gain := c_gain_civil;
    ELSIF v_caserne THEN
      v_gain := c_gain_caserne;
    ELSIF v_tente THEN
      v_gain := c_gain_terrain + c_bonus_tente;
    ELSE
      v_gain := c_gain_terrain;
    END IF;
    v_nouveau := least(c_pa_max, greatest(0, v_pa + v_gain + v_bonus));
  END IF;

  UPDATE public.personnages_donnees
     SET pa = v_nouveau, bonus_pa_differe = 0, pa_repos_le = v_jour
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'pa', v_nouveau, 'bonus_consomme', v_bonus,
                            'qhs', (v_qhs ->> 'enQHS')::boolean IS TRUE,
                            'grade_militaire', v_grade, 'gain', v_gain,
                            'caserne', v_caserne, 'tente', v_tente);
END;
$function$;