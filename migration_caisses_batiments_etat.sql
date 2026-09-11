-- =====================================================================
-- MOUVEMENTS ATOMIQUES DES CAISSES DE batiments_etat (12 septembre 2026)
-- =====================================================================
-- PROBLEME CORRIGE : toutes les caisses vivant dans batiments_etat (imprimerie.caisse,
-- usine.caisse, entrepot.caisse, port.caisse, et le stock associe) etaient lues puis reecrites par
-- le client en deux appels HTTP distincts (sbGetBatimentEtat puis sbSetBatimentEtat). Deux
-- operations simultanees -- ou un simple double-clic -- lisaient le meme solde et la derniere
-- ecriture ecrasait l'autre : la caisse payait deux fois mais ne baissait qu'une fois (creation de
-- monnaie), ou encaissait deux fois pour un seul credit (destruction de monnaie).
--
-- Cette RPC fait la lecture, le calcul et l'ecriture dans UNE SEULE instruction, sous le verrou de
-- ligne de batiments_etat. Semantique tout-ou-rien : un debit qui mettrait la caisse en negatif
-- n'est pas applique du tout et renvoie le solde reel (l'appelant peut recalculer une quantite).
-- Aucune refonte de batiments_etat : la colonne data reste le meme JSON stocke comme texte, les
-- autres sous-objets ne sont jamais touches.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.batiment_caisse_mouvement(
  p_pays      text,
  p_ville     text,
  p_building  text,
  p_souscle   text,
  p_delta     numeric,
  p_stock_cle text    DEFAULT NULL,
  p_stock     numeric DEFAULT 0
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

  -- data est un JSON stocke comme texte (double encodage) sur la plupart des lignes.
  v_d := CASE WHEN NOT v_existe THEN '{}'::jsonb
              WHEN jsonb_typeof(v_brut) = 'string' THEN (v_brut #>> '{}')::jsonb
              WHEN jsonb_typeof(v_brut) = 'object' THEN v_brut
              ELSE '{}'::jsonb END;
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

REVOKE ALL ON FUNCTION public.batiment_caisse_mouvement(text, text, text, text, numeric, text, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.batiment_caisse_mouvement(text, text, text, text, numeric, text, numeric) TO anon, authenticated, service_role;
