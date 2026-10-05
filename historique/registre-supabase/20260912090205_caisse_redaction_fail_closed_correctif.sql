-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260912090205
-- Nom original      : caisse_redaction_fail_closed_correctif
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-12 09:02:05 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 534b623ade0abc4e5024db4a0d0629b9
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
-- CORRECTIF : le garde-fou fail-closed sur le SOUS-OBJET ne se declenchait jamais.
-- jsonb_typeof(NULL) vaut NULL, et « NULL <> 'object' » vaut NULL, donc la condition etait ignoree :
-- une recette editoriale dans un batiment sans caisse de redaction creait la caisse au lieu d'etre
-- refusee. IS DISTINCT FROM traite correctement l'absence. (Le cas « ligne inexistante » etait, lui,
-- deja correct.)
CREATE OR REPLACE FUNCTION public.batiment_caisse_mouvement(
  p_pays             text,
  p_ville            text,
  p_building         text,
  p_souscle          text,
  p_delta            numeric,
  p_stock_cle        text    DEFAULT NULL,
  p_stock            numeric DEFAULT 0,
  p_stock_max        numeric DEFAULT NULL,
  p_exiger_existant  boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id     text;
  v_brut   jsonb;
  v_d      jsonb;
  v_obj    jsonb;
  v_caisse numeric;
  v_st     numeric;
  v_existe boolean;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' OR COALESCE(btrim(p_ville), '') = ''
     OR COALESCE(btrim(p_building), '') = '' OR COALESCE(btrim(p_souscle), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_delta IS NULL OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  v_id := p_pays || '_' || p_ville || '_' || p_building;
  SELECT data INTO v_brut FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  v_existe := FOUND;

  IF p_exiger_existant AND NOT v_existe THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_d := CASE WHEN NOT v_existe THEN '{}'::jsonb
              WHEN jsonb_typeof(v_brut) = 'string' THEN (v_brut #>> '{}')::jsonb
              WHEN jsonb_typeof(v_brut) = 'object' THEN v_brut
              ELSE '{}'::jsonb END;

  IF p_exiger_existant AND jsonb_typeof(v_d -> p_souscle) IS DISTINCT FROM 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_obj := CASE WHEN jsonb_typeof(v_d -> p_souscle) = 'object' THEN v_d -> p_souscle ELSE '{}'::jsonb END;
  v_caisse := CASE WHEN jsonb_typeof(v_obj -> 'caisse') = 'number' THEN (v_obj ->> 'caisse')::numeric ELSE 0 END;

  IF v_caisse + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
  END IF;

  v_obj := v_obj || jsonb_build_object('caisse', v_caisse + p_delta);

  IF p_stock_cle IS NOT NULL AND COALESCE(p_stock, 0) <> 0 THEN
    v_st := CASE WHEN jsonb_typeof(v_obj -> p_stock_cle) = 'number' THEN (v_obj ->> p_stock_cle)::numeric ELSE 0 END;
    IF v_st + p_stock < 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'stock', v_st, 'caisse', v_caisse);
    END IF;
    IF p_stock_max IS NOT NULL AND v_st + p_stock > p_stock_max THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_plafond', 'stock', v_st,
                                'stock_max', p_stock_max, 'caisse', v_caisse);
    END IF;
    v_obj := v_obj || jsonb_build_object(p_stock_cle, v_st + p_stock);
  END IF;

  v_d := v_d || jsonb_build_object(p_souscle, v_obj);

  IF v_existe THEN
    UPDATE public.batiments_etat SET data = to_jsonb(v_d::text), updated_at = now() WHERE id = v_id;
  ELSE
    INSERT INTO public.batiments_etat (id, country, city, building_id, data, updated_at)
    VALUES (v_id, p_pays, p_ville, p_building, to_jsonb(v_d::text), now());
  END IF;

  RETURN jsonb_build_object('ok', true, 'caisse', v_caisse + p_delta,
                            'stock', CASE WHEN p_stock_cle IS NULL THEN NULL ELSE v_obj -> p_stock_cle END);
END;
$$;
REVOKE ALL ON FUNCTION public.batiment_caisse_mouvement(text, text, text, text, numeric, text, numeric, numeric, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.batiment_caisse_mouvement(text, text, text, text, numeric, text, numeric, numeric, boolean) TO anon, authenticated, service_role;