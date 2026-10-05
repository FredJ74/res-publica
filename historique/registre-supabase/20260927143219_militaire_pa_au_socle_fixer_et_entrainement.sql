-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927143219
-- Nom original      : militaire_pa_au_socle_fixer_et_entrainement
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 14:32:19 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 55d943d0f80c49364d6e27a8740db81c
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
-- CHECKPOINT A (4/4, 1re partie) — LES PA PASSENT AU SOCLE : FIXATION ET ENTRAINEMENT
--
-- Le metier ne decide plus QUE la valeur ou le cout ; le socle applique le plancher, le plafond
-- et la mort a 0. C'est exactement le partage demande : « le metier Soldat definit seulement
-- quels ordres utilisent combien de PA ».

CREATE OR REPLACE FUNCTION public.militaire_soldat_pa_fixer(
  p_compagnie_id text, p_section_id text, p_matricule text, p_pa integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  PERFORM public.pnj_pa_fixer(ARRAY[p_compagnie_id || '-' || p_matricule], p_pa);
  PERFORM public.militaire_blob_projeter(p_compagnie_id);
END; $$;

-- ENTRAINEMENT. Les PA des PNJ passent par le socle, la FORMATION reste une donnee metier du
-- blob. Le Lieutenant et les soldats PJ paient sur leur propre fiche, comme avant.
CREATE OR REPLACE FUNCTION public.militaire_entrainer_section(
  p_compagnie_id text, p_section_id text, p_stat text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  c_max     constant integer := 12;
  c_pa      constant integer := 6;
  c_gain    constant integer := 3;
  c_plafond constant integer := 100;
  g record; v_sec jsonb; v_sols jsonb; v_pa_chef integer;
  v_elus_pnj jsonb; v_elus_pj jsonb; v_n integer; v_nom text; v_ids text[];
BEGIN
  IF p_stat NOT IN ('combat_rapproche','tir','reconnaissance','secourisme') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'domaine_invalide', 'domaine', p_stat);
  END IF;

  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  SELECT coalesce(pa, 0) INTO v_pa_chef FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;
  IF v_pa_chef < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_chef_insuffisants',
                              'requis', c_pa, 'pa_reel', v_pa_chef);
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;

  -- SELECTION COMMUNE PJ + PNJ, regle inchangee : les moins formes d'abord, jusqu'a 12 au total,
  -- et seulement ceux qui ont REELLEMENT leurs 6 PA. Les PA d'un PNJ se lisent desormais au socle.
  CREATE TEMP TABLE IF NOT EXISTS pg_temp_elus (nom text, matricule text, est_pj boolean, niveau numeric) ON COMMIT DROP;
  DELETE FROM pg_temp_elus;

  INSERT INTO pg_temp_elus (nom, matricule, est_pj, niveau)
  SELECT NULL, sm.matricule, false, coalesce((sm.formation->>p_stat)::numeric, 0)
    FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND m.statut = 'actif' AND m.pa >= c_pa
  UNION ALL
  SELECT pd.name, NULL, true, coalesce((pd.competences_militaires->>p_stat)::numeric, 0)
    FROM jsonb_array_elements(v_sols) sol
    JOIN public.personnages_donnees pd ON pd.name = sol->>'nom'
   WHERE coalesce((sol->>'pj')::boolean, false) AND coalesce(pd.pa, 0) >= c_pa;

  DELETE FROM pg_temp_elus WHERE ctid NOT IN (
    SELECT ctid FROM pg_temp_elus ORDER BY niveau, coalesce(matricule, nom) LIMIT c_max);

  SELECT count(*) INTO v_n FROM pg_temp_elus;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_soldat_en_etat', 'pa_requis', c_pa);
  END IF;

  SELECT coalesce(jsonb_agg(matricule), '[]'::jsonb) INTO v_elus_pnj FROM pg_temp_elus WHERE NOT est_pj;
  SELECT coalesce(jsonb_agg(nom), '[]'::jsonb)       INTO v_elus_pj  FROM pg_temp_elus WHERE est_pj;
  SELECT coalesce(array_agg(p_compagnie_id || '-' || matricule), '{}'::text[])
    INTO v_ids FROM pg_temp_elus WHERE NOT est_pj;

  -- PA : au socle, par la primitive generique. FORMATION : au blob, donnee metier.
  IF array_length(v_ids, 1) IS NOT NULL THEN
    PERFORM public.pnj_pa_debiter(v_ids, c_pa);
  END IF;

  SELECT coalesce(jsonb_agg(
           CASE WHEN v_elus_pnj ? (sol->>'matricule')
                THEN sol || jsonb_build_object('formation',
                              coalesce(CASE WHEN jsonb_typeof(sol->'formation') = 'object'
                                            THEN sol->'formation' END, '{}'::jsonb)
                              || jsonb_build_object(p_stat, least(c_plafond,
                                   coalesce((sol->'formation'->>p_stat)::numeric, 0) + c_gain)))
                ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  PERFORM public.militaire_blob_projeter(p_compagnie_id);

  FOR v_nom IN SELECT nom FROM pg_temp_elus WHERE est_pj LOOP
    UPDATE public.personnages_donnees
       SET pa = greatest(0, coalesce(pa, 0) - c_pa),
           competences_militaires = coalesce(competences_militaires, '{}'::jsonb)
             || jsonb_build_object(p_stat, least(c_plafond,
                  coalesce((competences_militaires->>p_stat)::numeric, 0) + c_gain))
     WHERE name = v_nom;
  END LOOP;

  UPDATE public.personnages_donnees SET pa = v_pa_chef - c_pa WHERE name = g.o_moi;

  RETURN jsonb_build_object('ok', true, 'domaine', p_stat, 'progresses', v_n,
    'pnj', jsonb_array_length(v_elus_pnj), 'pj', jsonb_array_length(v_elus_pj),
    'gain', c_gain, 'plafond', c_plafond, 'pa_soldat', c_pa, 'pa_chef', c_pa,
    'pa_restants_chef', v_pa_chef - c_pa, 'matricules', v_elus_pnj, 'joueurs', v_elus_pj);
END; $$;