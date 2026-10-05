-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924081751
-- Nom original      : affecter_leader_meme_section
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-24 08:17:51 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 9388ef0147e36afd1e920daaf87f5387
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
CREATE OR REPLACE FUNCTION public.militaire_affecter_leader(p_compagnie_id text, p_section_id text, p_nb integer, p_leader text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g record; v_sec jsonb; v_sols jsonb; v_dispo int;
        v_mv text; v_mb text; v_mr text; v_lv text; v_lb text; v_lr text; v_pays_l text; v_pays_m text;
        v_membre boolean;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;
  IF coalesce(btrim(coalesce(p_leader,'')),'') = '' OR p_leader = g.o_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_invalide');
  END IF;

  SELECT current_city, current_building, current_room, country INTO v_mv, v_mb, v_mr, v_pays_m
    FROM public.personnages_donnees WHERE name = g.o_moi;
  SELECT current_city, current_building, current_room, country INTO v_lv, v_lb, v_lr, v_pays_l
    FROM public.personnages_donnees WHERE name = p_leader;
  IF v_pays_l IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_introuvable');
  END IF;
  IF v_pays_l IS DISTINCT FROM v_pays_m THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_hors_juridiction');
  END IF;
  IF v_lv IS DISTINCT FROM v_mv OR v_lb IS DISTINCT FROM v_mb OR v_lr IS DISTINCT FROM v_mr THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_absent');
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;

  -- ------------------------------------------------------------------------------------------
  -- LA GARDE AJOUTEE : la cible doit etre un SOLDAT JOUEUR DE CETTE SECTION.
  -- Un soldat joueur vit dans le blob sous la forme { pj: true, nom: '...' }. Exiger pj = true
  -- exclut du meme coup les PNJ -- qui n'ont ni inventaire ni existence hors de la section --
  -- et l'absence de la cible dans soldats[] exclut les civils et les militaires d'une autre
  -- section, meme presents dans la piece.
  -- ------------------------------------------------------------------------------------------
  SELECT EXISTS (
    SELECT 1 FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
     WHERE coalesce((s->>'pj')::boolean, false) AND s->>'nom' = p_leader
  ) INTO v_membre;
  IF NOT v_membre THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_hors_section');
  END IF;

  SELECT count(*) INTO v_dispo FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'leaderCourant' = g.o_moi;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_assez_avec_vous', 'disponibles', v_dispo);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN avec AND ord <= p_nb
           THEN sol || jsonb_build_object('leaderCourant', p_leader) ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM (SELECT sol, pos, (sol->>'leaderCourant' = g.o_moi) AS avec,
                 row_number() OVER (PARTITION BY (sol->>'leaderCourant' = g.o_moi) ORDER BY pos) AS ord
            FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos)) x;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'affectes', p_nb, 'leader', p_leader);
END;
$function$;