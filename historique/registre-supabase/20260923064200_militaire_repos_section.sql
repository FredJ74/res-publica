-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260923064200
-- Nom original      : militaire_repos_section
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-23 06:42:00 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e235cfcd189ea12696e4262662cc1448
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
CREATE OR REPLACE FUNCTION public.militaire_reposer_section(p_compagnie_id text, p_section_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  c_pa_max         constant integer := 12;
  c_gain_terrain   constant integer := 8;
  c_bonus_tente    constant integer := 2;
  c_capacite_tente constant integer := 13;
  g record; v_sec jsonb; v_sols jsonb; v_jour text;
  v_caserne integer; v_tente integer; v_terrain integer; v_deja integer; v_total integer;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', g.o_raison);
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s
   WHERE s->>'id' = p_section_id;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  WITH base AS (
    SELECT sol, pos,
           NOT coalesce((sol->>'pj')::boolean, false)        AS est_pnj,
           coalesce((sol->>'pa')::numeric, 0)::integer       AS pa,
           nullif(btrim(coalesce(sol->>'leaderCourant','')), '') AS leader,
           coalesce(sol->>'dernier_sommeil', '')             AS marqueur
      FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos)
  ),
  situe AS (
    SELECT b.*,
           coalesce(pd.current_building, b.sol->>'buildingId') AS batiment
      FROM base b
      LEFT JOIN public.personnages_donnees pd
             ON b.leader IS NOT NULL AND pd.name = b.leader
  ),
  eligible AS (
    SELECT s.*,
           (s.est_pnj AND s.pa > 0 AND s.marqueur <> v_jour)   AS peut,
           (coalesce(s.batiment, '') = 'caserne-militaire')    AS a_la_caserne
      FROM situe s
  ),
  tentes AS (
    SELECT l.leader,
           (SELECT count(*) FROM jsonb_array_elements(
                     CASE WHEN jsonb_typeof(pd.inventory) = 'array' THEN pd.inventory ELSE '[]'::jsonb END) i
             WHERE i->>'produitMilitaire' = 'tente')::integer AS nb
      FROM (SELECT DISTINCT leader FROM eligible
             WHERE peut AND NOT a_la_caserne AND leader IS NOT NULL) l
      JOIN public.personnages_donnees pd ON pd.name = l.leader
  ),
  rang AS (
    SELECT pos, leader,
           row_number() OVER (PARTITION BY leader ORDER BY (sol->>'matricule'), pos) AS n
      FROM eligible
     WHERE peut AND NOT a_la_caserne AND leader IS NOT NULL
  ),
  final AS (
    SELECT e.sol, e.pos, e.pa,
           CASE
             WHEN NOT e.peut            THEN 'aucun'
             WHEN e.a_la_caserne        THEN 'caserne'
             WHEN r.n IS NOT NULL
              AND r.n <= coalesce(t.nb, 0) * c_capacite_tente THEN 'tente'
             ELSE 'terrain'
           END AS sort,
           (NOT e.peut AND e.est_pnj AND e.pa > 0 AND e.marqueur = v_jour) AS deja_repose
      FROM eligible e
      LEFT JOIN rang   r ON r.pos = e.pos
      LEFT JOIN tentes t ON t.leader = e.leader
  )
  SELECT coalesce(jsonb_agg(
           CASE f.sort
             WHEN 'caserne' THEN f.sol || jsonb_build_object('pa', c_pa_max, 'dernier_sommeil', v_jour)
             WHEN 'tente'   THEN f.sol || jsonb_build_object(
                                  'pa', least(c_pa_max, f.pa + c_gain_terrain + c_bonus_tente),
                                  'dernier_sommeil', v_jour)
             WHEN 'terrain' THEN f.sol || jsonb_build_object(
                                  'pa', least(c_pa_max, f.pa + c_gain_terrain),
                                  'dernier_sommeil', v_jour)
             ELSE f.sol
           END ORDER BY f.pos), '[]'::jsonb),
         count(*) FILTER (WHERE f.sort = 'caserne')::integer,
         count(*) FILTER (WHERE f.sort = 'tente')::integer,
         count(*) FILTER (WHERE f.sort = 'terrain')::integer,
         count(*) FILTER (WHERE f.deja_repose)::integer,
         count(*)::integer
    INTO v_sols, v_caserne, v_tente, v_terrain, v_deja, v_total
    FROM final f;

  IF coalesce(v_caserne,0) + coalesce(v_tente,0) + coalesce(v_terrain,0) = 0 THEN
    RETURN jsonb_build_object('ok', true, 'caserne', 0, 'tente', 0, 'terrain', 0,
      'deja_reposes', coalesce(v_deja,0), 'effectif', coalesce(v_total,0), 'reposes', 0);
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;

  RETURN jsonb_build_object('ok', true,
    'caserne', v_caserne, 'tente', v_tente, 'terrain', v_terrain,
    'deja_reposes', v_deja, 'effectif', v_total,
    'reposes', v_caserne + v_tente + v_terrain);
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_reposer_section(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.militaire_reposer_section(text, text) TO authenticated;