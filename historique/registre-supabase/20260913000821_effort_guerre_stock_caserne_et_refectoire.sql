-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913000821
-- Nom original      : effort_guerre_stock_caserne_et_refectoire
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 00:08:21 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6a9a40190f007159d5b589a68d9633da
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
CREATE OR REPLACE FUNCTION public.caserne_stock_mouvement(
  p_pays text, p_produit text, p_delta integer, p_lot text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_data jsonb; v_stock jsonb; v_lots jsonb; v_file jsonb;
  v_cur integer; v_reste integer; v_servis jsonb := '[]'::jsonb;
  v_tete jsonb; v_q integer; v_pris integer;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' OR COALESCE(btrim(p_produit), '') = ''
     OR p_delta IS NULL OR p_delta = 0 OR abs(p_delta) > 100000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_delta > 0 AND COALESCE(btrim(p_lot), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lot_obligatoire');
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  IF NOT FOUND THEN
    IF p_delta < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'stock', 0); END IF;
    v_data := '{}'::jsonb;
    INSERT INTO public.budgets_nationaux (id, data, updated_at) VALUES (p_pays, v_data, now());
  END IF;
  v_data := COALESCE(v_data, '{}'::jsonb);

  v_stock := CASE WHEN jsonb_typeof(v_data -> 'stockArmurerieMilitaire') = 'object'
                  THEN v_data -> 'stockArmurerieMilitaire' ELSE '{}'::jsonb END;
  v_lots  := CASE WHEN jsonb_typeof(v_data -> 'lotsMilitaires') = 'object'
                  THEN v_data -> 'lotsMilitaires' ELSE '{}'::jsonb END;
  v_cur   := GREATEST(0, COALESCE((v_stock ->> p_produit)::integer, 0));
  v_file  := CASE WHEN jsonb_typeof(v_lots -> p_produit) = 'array'
                  THEN v_lots -> p_produit ELSE '[]'::jsonb END;

  IF v_cur + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'stock', v_cur);
  END IF;

  IF p_delta > 0 THEN
    v_file := v_file || jsonb_build_array(jsonb_build_object('lot', p_lot, 'qte', p_delta));
  ELSE
    v_reste := -p_delta;
    WHILE v_reste > 0 AND jsonb_array_length(v_file) > 0 LOOP
      v_tete := v_file -> 0;
      v_q    := GREATEST(0, COALESCE((v_tete ->> 'qte')::integer, 0));
      v_pris := LEAST(v_q, v_reste);
      IF v_pris > 0 THEN
        v_servis := v_servis || jsonb_build_array(jsonb_build_object('lot', v_tete ->> 'lot', 'qte', v_pris));
        v_reste := v_reste - v_pris;
      END IF;
      IF v_q - v_pris <= 0 THEN v_file := v_file - 0;
      ELSE v_file := jsonb_set(v_file, ARRAY['0','qte'], to_jsonb(v_q - v_pris)); END IF;
    END LOOP;
    IF v_reste > 0 THEN
      v_servis := v_servis || jsonb_build_array(jsonb_build_object('lot', 'legacy', 'qte', v_reste));
    END IF;
  END IF;

  v_stock := v_stock || jsonb_build_object(p_produit, v_cur + p_delta);
  v_lots  := v_lots  || jsonb_build_object(p_produit, v_file);
  v_data  := v_data  || jsonb_build_object('stockArmurerieMilitaire', v_stock, 'lotsMilitaires', v_lots);
  UPDATE public.budgets_nationaux SET data = v_data, updated_at = now() WHERE id = p_pays;

  RETURN jsonb_build_object('ok', true, 'produit', p_produit, 'stock', v_cur + p_delta, 'lots', v_servis);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.militaire_retrait(
  p_pays text, p_produit text, p_quantite integer,
  p_lieutenant text, p_section text, p_jour integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_pj public.personnages%ROWTYPE; v_mvt jsonb; v_lot jsonb;
BEGIN
  IF COALESCE(p_quantite, 0) <= 0 OR p_quantite > 1000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF p_produit NOT IN ('arme_de_poing', 'mitraillette', 'explosif_militaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_invalide');
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_lieutenant FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  IF COALESCE(v_pj.poste ->> 'id', '') <> 'lieutenant' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef_de_section');
  END IF;

  v_mvt := public.caserne_stock_mouvement(p_pays, p_produit, -p_quantite, NULL);
  IF COALESCE((v_mvt ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;

  FOR v_lot IN SELECT value FROM jsonb_array_elements(COALESCE(v_mvt -> 'lots', '[]'::jsonb)) LOOP
    INSERT INTO public.retraits_materiel_militaire
      (pays, materiel, lot, quantite, lieutenant, section, jour)
    VALUES (p_pays, p_produit, v_lot ->> 'lot', (v_lot ->> 'qte')::integer, p_lieutenant, p_section, p_jour);
  END LOOP;

  RETURN v_mvt || jsonb_build_object('registre', true);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.militaire_subtiliser(p_pays text, p_joueur text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE v_pj public.personnages%ROWTYPE;
BEGIN
  SELECT * INTO v_pj FROM public.personnages WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  RETURN public.caserne_stock_mouvement(p_pays, 'explosif_militaire', -1, NULL);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.refectoire_repas(
  p_pays text, p_joueur text, p_jour integer,
  p_pa_max integer DEFAULT 30, p_gain integer DEFAULT 2
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_pj public.personnages%ROWTYPE; v_stats jsonb; v_data jsonb; v_ref jsonb; v_brut jsonb;
  v_rations integer; v_cer integer; v_via integer; v_poi integer;
  v_prot text; v_fab boolean := false; v_pa integer;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' OR COALESCE(btrim(p_joueur), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  v_stats := CASE WHEN jsonb_typeof(v_pj.stats) = 'object' THEN v_pj.stats ELSE '{}'::jsonb END;
  IF COALESCE((v_stats ->> 'repasCaserneJour')::integer, -1) = p_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_mange');
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'refectoire_vide'); END IF;
  v_data := COALESCE(v_data, '{}'::jsonb);
  v_ref  := CASE WHEN jsonb_typeof(v_data -> 'refectoire') = 'object' THEN v_data -> 'refectoire' ELSE '{}'::jsonb END;
  v_brut := CASE WHEN jsonb_typeof(v_ref -> 'brut') = 'object' THEN v_ref -> 'brut' ELSE '{}'::jsonb END;
  v_rations := GREATEST(0, COALESCE((v_ref ->> 'rations')::integer, 0));

  IF v_rations <= 0 THEN
    v_cer := GREATEST(0, COALESCE((v_brut ->> 'cereales')::integer, 0));
    v_via := GREATEST(0, COALESCE((v_brut ->> 'viande')::integer, 0));
    v_poi := GREATEST(0, COALESCE((v_brut ->> 'poisson')::integer, 0));
    IF v_cer < 1 OR (v_via + v_poi) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ingredients_insuffisants',
                                'cereales', v_cer, 'viande', v_via, 'poisson', v_poi);
    END IF;
    v_prot := CASE WHEN v_via >= 1 THEN 'viande' ELSE 'poisson' END;
    v_brut := v_brut || jsonb_build_object('cereales', v_cer - 1,
                v_prot, (CASE WHEN v_prot = 'viande' THEN v_via ELSE v_poi END) - 1);
    v_rations := 10;
    v_fab := true;
  END IF;

  v_rations := v_rations - 1;
  v_ref  := v_ref || jsonb_build_object('brut', v_brut, 'rations', v_rations);
  v_data := v_data || jsonb_build_object('refectoire', v_ref);
  UPDATE public.budgets_nationaux SET data = v_data, updated_at = now() WHERE id = p_pays;

  v_pa := LEAST(COALESCE(p_pa_max, 30), GREATEST(0, COALESCE(v_pj.pa, 0)) + GREATEST(0, COALESCE(p_gain, 2)));
  UPDATE public.personnages
     SET pa = v_pa, stats = v_stats || jsonb_build_object('repasCaserneJour', p_jour)
   WHERE name = p_joueur;

  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'rations', v_rations,
                            'fabrique', v_fab, 'proteine', v_prot);
END;
$fn$;

REVOKE ALL ON FUNCTION public.caserne_stock_mouvement(text, text, integer, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_retrait(text, text, integer, text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_subtiliser(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refectoire_repas(text, text, integer, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.caserne_stock_mouvement(text, text, integer, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.militaire_retrait(text, text, integer, text, text, integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.militaire_subtiliser(text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.refectoire_repas(text, text, integer, integer, integer) TO anon, authenticated, service_role;