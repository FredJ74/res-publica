-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927143349
-- Nom original      : militaire_reposer_section_pa_au_socle
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 14:33:49 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 070906a1a112790db729b6a29120cc67
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
-- CHECKPOINT A (4/4, 3e partie) — LE REPOS DE SECTION PASSE AU SOCLE
--
-- Regles strictement conservees : un seul repos par jour et par soldat ; a la caserne on repart
-- a 12 PA ; au terrain +8 ; sous la tente +8+2 ; une tente abrite 12 PNJ (13 personnes, le leader
-- compris) ; les premiers servis sont pris dans l'ordre du matricule, comme avant.
-- Ce qui change : les PA et le leader se lisent et s'ecrivent au socle. `dernier_sommeil` reste
-- une donnee METIER, ecrite dans le blob.
CREATE OR REPLACE FUNCTION public.militaire_reposer_section(
  p_compagnie_id text, p_section_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  c_pa_max         constant integer := 12;
  c_gain_terrain   constant integer := 8;
  c_bonus_tente    constant integer := 2;
  c_pnj_par_tente  constant integer := 12;
  g record; v_sec jsonb; v_sols jsonb; v_jour text;
  v_caserne integer := 0; v_tente integer := 0; v_terrain integer := 0;
  v_deja integer := 0; v_total integer := 0;
  v_ids_caserne text[]; v_ids_tente text[]; v_ids_terrain text[]; v_servis jsonb;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', g.o_raison);
  END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s
   WHERE s->>'id' = p_section_id;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  CREATE TEMP TABLE IF NOT EXISTS pg_temp_repos
    (id text, matricule text, sort text) ON COMMIT DROP;
  DELETE FROM pg_temp_repos;

  -- Le batiment retenu est celui du CHEF quand le soldat le suit, sinon le sien. Un PNJ qui suit
  -- un leader est reellement la ou est son leader : c'est le referentiel commun PJ/PNJ.
  INSERT INTO pg_temp_repos (id, matricule, sort)
  WITH base AS (
    SELECT m.id, sm.matricule, m.pa, m.leader_pj,
           COALESCE(sm.dernier_sommeil, '') AS marqueur,
           COALESCE(pd.current_building, m.building_id) AS batiment
      FROM public.pnj_soldats_metier sm
      JOIN public.pnj_membres m ON m.id = sm.pnj_id
      LEFT JOIN public.personnages_donnees pd ON pd.name = m.leader_pj
     WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
       AND m.statut = 'actif'
  ), eligible AS (
    SELECT b.*, (b.pa > 0 AND b.marqueur <> v_jour) AS peut,
           (COALESCE(b.batiment,'') = 'caserne-militaire') AS a_la_caserne
      FROM base b
  ), tentes AS (
    SELECT l.leader_pj,
           (SELECT count(*) FROM jsonb_array_elements(
                     CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
             WHERE i->>'produitMilitaire' = 'tente')::integer AS nb
      FROM (SELECT DISTINCT leader_pj FROM eligible
             WHERE peut AND NOT a_la_caserne AND leader_pj IS NOT NULL) l
      JOIN public.personnages_donnees pd ON pd.name = l.leader_pj
  ), rang AS (
    SELECT id, leader_pj,
           row_number() OVER (PARTITION BY leader_pj ORDER BY matricule) AS n
      FROM eligible WHERE peut AND NOT a_la_caserne AND leader_pj IS NOT NULL
  )
  SELECT e.id, e.matricule,
         CASE WHEN NOT e.peut     THEN 'aucun'
              WHEN e.a_la_caserne THEN 'caserne'
              WHEN r.n IS NOT NULL AND r.n <= COALESCE(t.nb, 0) * c_pnj_par_tente THEN 'tente'
              ELSE 'terrain' END
    FROM eligible e
    LEFT JOIN rang   r ON r.id = e.id
    LEFT JOIN tentes t ON t.leader_pj = e.leader_pj;

  SELECT count(*) FILTER (WHERE sort='caserne'), count(*) FILTER (WHERE sort='tente'),
         count(*) FILTER (WHERE sort='terrain'), count(*)
    INTO v_caserne, v_tente, v_terrain, v_total FROM pg_temp_repos;
  SELECT count(*) INTO v_deja
    FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND m.statut = 'actif' AND m.pa > 0 AND COALESCE(sm.dernier_sommeil,'') = v_jour;

  IF v_caserne + v_tente + v_terrain = 0 THEN
    RETURN jsonb_build_object('ok', true, 'caserne', 0, 'tente', 0, 'terrain', 0,
      'deja_reposes', v_deja, 'effectif', v_total, 'reposes', 0,
      'pnj_par_tente', c_pnj_par_tente);
  END IF;

  SELECT coalesce(array_agg(id) FILTER (WHERE sort='caserne'), '{}'::text[]),
         coalesce(array_agg(id) FILTER (WHERE sort='tente'),   '{}'::text[]),
         coalesce(array_agg(id) FILTER (WHERE sort='terrain'), '{}'::text[])
    INTO v_ids_caserne, v_ids_tente, v_ids_terrain FROM pg_temp_repos;

  -- LES PA, PAR LE SOCLE. La caserne remet au plein, le reste credite.
  IF array_length(v_ids_caserne,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_fixer(v_ids_caserne, c_pa_max); END IF;
  IF array_length(v_ids_tente,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_crediter(v_ids_tente, c_gain_terrain + c_bonus_tente); END IF;
  IF array_length(v_ids_terrain,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_crediter(v_ids_terrain, c_gain_terrain); END IF;

  -- LE MARQUEUR, PAR LE BLOB : c'est une donnee metier.
  SELECT coalesce(jsonb_agg(matricule), '[]'::jsonb) INTO v_servis
    FROM pg_temp_repos WHERE sort <> 'aucun';
  SELECT coalesce(jsonb_agg(
           CASE WHEN v_servis ? (sol->>'matricule')
                THEN sol || jsonb_build_object('dernier_sommeil', v_jour)
                ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  PERFORM public.militaire_blob_projeter(p_compagnie_id);

  RETURN jsonb_build_object('ok', true,
    'caserne', v_caserne, 'tente', v_tente, 'terrain', v_terrain,
    'deja_reposes', v_deja, 'effectif', v_total,
    'reposes', v_caserne + v_tente + v_terrain,
    'pnj_par_tente', c_pnj_par_tente);
END; $$;