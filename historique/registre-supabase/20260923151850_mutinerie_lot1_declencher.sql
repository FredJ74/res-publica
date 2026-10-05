-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260923151850
-- Nom original      : mutinerie_lot1_declencher
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-23 15:18:50 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 2bd1809529e4f2dad1f065f402218a72
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
CREATE OR REPLACE FUNCTION public.militaire_mutinerie_declencher()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  c_effectif_max constant integer := 24;
  c_bonus_max    constant integer := 4;
  c_seuil_crise  constant numeric := 35;
  g record; v_moi text; v_pays text; v_cie text; v_sec text;
  v_cha numeric; v_base integer; v_social numeric; v_ie numeric;
  v_deg_s numeric; v_deg_e numeric; v_score numeric; v_bonus integer;
  v_vises integer; v_dispo integer; v_camp text; v_choisis text[]; v_sols jsonb; v_secj jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), poste->>'compagnieId', poste->>'sectionId',
         public.assemblee_stat_base(stats, 'CHA')
    INTO v_pays, v_cie, v_sec, v_cha
    FROM public.personnages_donnees
   WHERE name = v_moi AND poste->>'id' = 'lieutenant';
  IF v_cie IS NULL OR v_sec IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_lieutenant');
  END IF;

  IF public.mutinerie_camp_de(v_moi) IS NOT NULL
     OR EXISTS (SELECT 1 FROM public.mutineries_membres WHERE personnage = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_mutin');
  END IF;

  SELECT * INTO g FROM public.militaire_section_de_moi(v_cie, v_sec);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  v_base := CASE WHEN v_cha <= 13 THEN 12 WHEN v_cha < 15 THEN 15
                 WHEN v_cha < 16 THEN 18 ELSE 20 END;

  v_social := public.mutinerie_social_national(v_pays);
  v_ie     := public.helvetia_ie_national(v_pays);
  v_deg_s  := greatest(0, (c_seuil_crise - v_social) / c_seuil_crise);
  v_deg_e  := greatest(0, (c_seuil_crise - v_ie)     / c_seuil_crise);
  v_score  := (2.0/3.0) * v_deg_s + (1.0/3.0) * v_deg_e;
  v_bonus  := least(c_bonus_max, greatest(0, ceil(c_bonus_max * v_score)::integer));

  v_vises := least(c_effectif_max, v_base + v_bonus);

  SELECT s INTO v_secj FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = v_sec;
  v_sols := CASE WHEN jsonb_typeof(v_secj->'soldats') = 'array' THEN v_secj->'soldats' ELSE '[]'::jsonb END;

  SELECT count(*)::integer INTO v_dispo FROM jsonb_array_elements(v_sols) sol
   WHERE NOT coalesce((sol->>'pj')::boolean, false)
     AND coalesce((sol->>'pa')::integer, 0) > 0
     AND (sol->>'mutin') IS NULL;
  v_vises := least(v_vises, v_dispo);

  v_camp := 'mutin:' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 12);
  INSERT INTO public.mutineries (camp, pays, fondateur, compagnie_id, section_id)
  VALUES (v_camp, v_pays, v_moi, v_cie, v_sec);
  INSERT INTO public.mutineries_membres (camp, personnage, role_origine)
  VALUES (v_camp, v_moi, 'lieutenant');

  IF v_vises > 0 THEN
    SELECT coalesce(array_agg(mat), '{}'::text[]) INTO v_choisis FROM (
      SELECT sol->>'matricule' AS mat FROM jsonb_array_elements(v_sols) sol
       WHERE NOT coalesce((sol->>'pj')::boolean, false)
         AND coalesce((sol->>'pa')::integer, 0) > 0
         AND (sol->>'mutin') IS NULL
       ORDER BY random() LIMIT v_vises) x;

    SELECT coalesce(jsonb_agg(
             CASE WHEN sol->>'matricule' = ANY (v_choisis)
                  THEN sol || jsonb_build_object('mutin', v_camp) ELSE sol END ORDER BY pos), '[]'::jsonb)
      INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

    UPDATE public.compagnies_militaires
       SET data = public.militaire_sections_remplacer(g.o_data, v_sec,
                    v_secj || jsonb_build_object('soldats', v_sols))
     WHERE id = v_cie;
  END IF;

  RETURN jsonb_build_object('ok', true, 'camp', v_camp, 'cha', v_cha,
    'base', v_base, 'bonus_crise', v_bonus, 'social', v_social, 'ie', v_ie,
    'soldats_rallies', v_vises, 'soldats_disponibles', v_dispo,
    'soldats_restes_loyalistes', greatest(0, v_dispo - v_vises));
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_mutinerie_declencher() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.militaire_mutinerie_declencher() TO authenticated;