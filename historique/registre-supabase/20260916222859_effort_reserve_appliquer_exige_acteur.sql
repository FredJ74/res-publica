-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916222859
-- Nom original      : effort_reserve_appliquer_exige_acteur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 22:28:59 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b51782c20a81aa3001080ae46bebf029
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
-- Audit des frontieres d'autorite, 17 septembre 2026.
-- effort_reserve_appliquer regle la RESERVE MILITAIRE NATIONALE sur les entrepots du pays et
-- etait executable par le role anon (sans session), sans aucun controle d'identite.
-- Corps de calcul strictement inchange : seule la garde d'entree est ajoutee.
-- QUI doit pouvoir regler cette reserve (ministre de la Defense ? etat-major ?) reste un
-- ARBITRAGE de game design : cette garde etablit seulement qu'il faut etre un joueur identifie
-- ou le serveur, pas n'importe quel visiteur.
CREATE OR REPLACE FUNCTION public.effort_reserve_appliquer(
  p_pays text, p_entrepots jsonb, p_ressources text[], p_pct numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_pct numeric; v_id text; v_ids text[] := ARRAY[]::text[];
  v_etats jsonb := '{}'::jsonb; v_d jsonb; v_stock jsonb; v_res text;
  v_total numeric; v_cible numeric; v_pose numeric; v_q numeric;
  v_dispo numeric; v_reste numeric; v_avance boolean;
  v_reserves jsonb := '{}'::jsonb; v_totaux jsonb := '{}'::jsonb; v_obj jsonb;
BEGIN
  IF NOT public.est_appel_serveur() AND public.mon_personnage() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  IF COALESCE(btrim(p_pays), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_entrepots IS NULL OR jsonb_typeof(p_entrepots) <> 'array' OR jsonb_array_length(p_entrepots) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot');
  END IF;
  IF p_ressources IS NULL OR array_length(p_ressources, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_ressource');
  END IF;
  v_pct := LEAST(100, GREATEST(0, COALESCE(p_pct, 0)));

  SELECT array_agg(x ORDER BY x) INTO v_ids
  FROM (SELECT public.eg_etat_id(p_pays, e) AS x FROM jsonb_array_elements(p_entrepots) AS e) s;

  FOREACH v_id IN ARRAY v_ids LOOP
    SELECT public.eg_etat_lire(data) INTO v_d FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
    IF NOT FOUND THEN CONTINUE; END IF;
    v_etats := v_etats || jsonb_build_object(v_id, v_d);
  END LOOP;
  IF v_etats = '{}'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot_trouve');
  END IF;

  FOREACH v_res IN ARRAY p_ressources LOOP
    v_total := 0;
    FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
      v_stock := COALESCE(v_etats -> v_id -> 'entrepot' -> 'stock', '{}'::jsonb);
      v_total := v_total + GREATEST(0, COALESCE((v_stock ->> v_res)::numeric, 0));
    END LOOP;
    v_cible  := floor(v_total * v_pct / 100.0);
    v_totaux := v_totaux || jsonb_build_object(v_res, v_cible);
    v_pose := 0;
    FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
      v_stock := COALESCE(v_etats -> v_id -> 'entrepot' -> 'stock', '{}'::jsonb);
      v_dispo := GREATEST(0, COALESCE((v_stock ->> v_res)::numeric, 0));
      v_q := CASE WHEN v_total > 0 THEN LEAST(v_dispo, floor(v_cible * v_dispo / v_total)) ELSE 0 END;
      v_reserves := v_reserves || jsonb_build_object(
        v_id, COALESCE(v_reserves -> v_id, '{}'::jsonb) || jsonb_build_object(v_res, v_q));
      v_pose := v_pose + v_q;
    END LOOP;
    v_reste := v_cible - v_pose;
    WHILE v_reste > 0 LOOP
      v_avance := false;
      FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
        EXIT WHEN v_reste <= 0;
        v_stock := COALESCE(v_etats -> v_id -> 'entrepot' -> 'stock', '{}'::jsonb);
        v_dispo := GREATEST(0, COALESCE((v_stock ->> v_res)::numeric, 0));
        v_q := COALESCE((v_reserves -> v_id ->> v_res)::numeric, 0);
        IF v_q < v_dispo THEN
          v_reserves := v_reserves || jsonb_build_object(
            v_id, (v_reserves -> v_id) || jsonb_build_object(v_res, v_q + 1));
          v_reste  := v_reste - 1;
          v_avance := true;
        END IF;
      END LOOP;
      EXIT WHEN NOT v_avance;
    END LOOP;
  END LOOP;

  FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
    v_d   := v_etats -> v_id;
    v_obj := COALESCE(v_d -> 'entrepot', '{}'::jsonb);
    IF v_pct = 0 THEN
      v_obj := v_obj - 'reserveMilitaire';
    ELSE
      v_obj := v_obj || jsonb_build_object('reserveMilitaire', COALESCE(v_reserves -> v_id, '{}'::jsonb));
    END IF;
    v_d := v_d || jsonb_build_object('entrepot', v_obj);
    UPDATE public.batiments_etat SET data = to_jsonb(v_d::text), updated_at = now() WHERE id = v_id;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pct', v_pct, 'reserves', v_reserves, 'totaux', v_totaux);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.effort_reserve_appliquer(text, jsonb, text[], numeric) FROM anon;