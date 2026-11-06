-- Exportations de Sovarka (Claude, 06/11/2026, décision de Fred).
--
-- Fred : la Sovarka exporte des minerais vers tous les pays, du pétrole vers la Républia, de la viande et
-- des céréales vers Al-Khalija, du métal vers tous les pays.
--
-- 1. Réception générique `exportation_recevoir(origine, pays, ...)` : la règle de Fred pour Sovarka (le
--    port paie, répartit aussitôt en trois, les deux autres entrepôts paient leur part au port) vaut aussi
--    pour la Républia, par symétrie (choix de Claude, à confirmer) : PSM paie, Luthécia et Montrouge lui
--    paient leur part. `exportation_sovarka_recevoir` (migration 20261106100000) devient son enveloppe.
-- 2. Expédition `exportations_sovarka_executer(jour, contrats)` : prélève sur le stock réel des trois
--    entrepôts de Sovarka (au prorata), les paie au prix de base, livre la part de la Républia par la
--    réception ci-dessus. Al-Khalija et El Estado n'ont ni entrepôt ni caisse : leur part disparaît, comme
--    les exportations de Républia vers Al-Khalija.
-- 3. Toutes les caisses passent désormais par caisse_institution_mouvement (journal, refus sous zéro),
--    y compris la réception du 06/11 qui écrivait caisses_batiments directement.
-- Une seule opération par jour, matière, origine et destination (exportations_recues), rejeu sans effet.

ALTER TABLE public.exportations_recues ADD COLUMN IF NOT EXISTS origine text NOT NULL DEFAULT 'republic';
ALTER TABLE public.exportations_recues DROP CONSTRAINT IF EXISTS exportations_recues_pkey;
ALTER TABLE public.exportations_recues ADD PRIMARY KEY (jour, cle, origine, pays);

-- Stock d'un entrepôt : batiments_etat.data est un objet (Sovarka) ou un texte JSON (Républia, écrit par
-- la passe de minuit) ; on garde la forme d'origine.
CREATE OR REPLACE FUNCTION public.exportation_stock_interne(p_id text, p_cle text, p_delta integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_data jsonb; v_obj jsonb; v_texte boolean; v_val integer;
BEGIN
  SELECT data INTO v_data FROM public.batiments_etat WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN NULL; END IF;
  v_texte := jsonb_typeof(v_data) = 'string';
  v_obj := CASE WHEN v_texte THEN (v_data #>> '{}')::jsonb ELSE coalesce(v_data, '{}'::jsonb) END;
  v_val := coalesce((v_obj #>> ARRAY['entrepot','stock',p_cle])::numeric, 0)::integer;
  IF p_delta = 0 THEN RETURN v_val; END IF;
  v_val := greatest(0, v_val + p_delta);
  IF v_obj->'entrepot' IS NULL THEN v_obj := v_obj || '{"entrepot": {}}'::jsonb; END IF;
  IF v_obj->'entrepot'->'stock' IS NULL THEN v_obj := jsonb_set(v_obj, '{entrepot,stock}', '{}'::jsonb); END IF;
  v_obj := jsonb_set(v_obj, ARRAY['entrepot','stock',p_cle], to_jsonb(v_val), true);
  UPDATE public.batiments_etat SET data = CASE WHEN v_texte THEN to_jsonb(v_obj::text) ELSE v_obj END, updated_at = now()
   WHERE id = p_id;
  RETURN v_val;
END $$;

CREATE OR REPLACE FUNCTION public.exportation_caisse_interne(p_entrepot text, p_delta numeric)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_caisse text; v_rep jsonb;
BEGIN
  IF p_delta = 0 THEN RETURN true; END IF;
  v_caisse := public.entrepot_caisse_id(p_entrepot);
  IF v_caisse IS NULL THEN RETURN false; END IF;
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement(v_caisse, round(p_delta, 2), true);
  PERFORM set_config('rp.caisse_interne', '', true);
  RETURN coalesce((v_rep->>'ok')::boolean, false);
END $$;

CREATE OR REPLACE FUNCTION public.exportation_solde_interne(p_entrepot text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((c.data->>'solde')::numeric, 0) FROM public.caisses_batiments c
   WHERE c.id = public.entrepot_caisse_id(p_entrepot);
$$;

-- Réception : le port paie, répartit en trois, les deux autres entrepôts lui paient leur part.
CREATE OR REPLACE FUNCTION public.exportation_recevoir(p_origine text, p_pays text, p_jour date, p_cle text, p_quantite integer, p_prix numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  v_port text; v_autres text[]; v_villes text[];
  v_deja jsonb; v_solde numeric; v_q integer; v_base integer; v_reste integer;
  v_i integer; v_part integer; v_envoye integer; v_parts jsonb := '{}'::jsonb; v_res jsonb;
BEGIN
  IF p_pays = 'soviet' THEN
    v_port := 'soviet_ville_a_entrepot-logistique-starovka';
    v_autres := ARRAY['soviet_capitale_entrepot-logistique-novomirsk', 'soviet_ville_b_entrepot-logistique-krasnov'];
  ELSIF p_pays = 'republic' THEN
    v_port := 'republic_ville_a_entrepot-logistique-psm';
    v_autres := ARRAY['republic_capitale_entrepot-logistique-luthecia', 'republic_ville_b_entrepot-logistique-montrouge'];
  ELSE
    RETURN jsonb_build_object('ok', false, 'acceptee', 0, 'raison', 'pays_sans_entrepot');
  END IF;
  v_villes := ARRAY['capitale', 'ville_b'];
  IF p_cle IS NULL OR coalesce(p_quantite, 0) <= 0 OR coalesce(p_prix, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'acceptee', 0, 'raison', 'rien_a_recevoir');
  END IF;
  SELECT resultat INTO v_deja FROM public.exportations_recues
   WHERE jour = p_jour AND cle = p_cle AND origine = p_origine AND pays = p_pays;
  IF FOUND THEN RETURN v_deja || jsonb_build_object('rejeu', true); END IF;

  PERFORM 1 FROM public.batiments_etat WHERE id = v_port FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'acceptee', 0, 'raison', 'entrepot_port_absent'); END IF;
  v_solde := public.exportation_solde_interne(v_port);
  v_q := least(p_quantite, floor(coalesce(v_solde, 0) / p_prix)::integer);
  IF v_q > 0 AND NOT public.exportation_caisse_interne(v_port, -(v_q * p_prix)) THEN v_q := 0; END IF;
  IF v_q <= 0 THEN
    v_res := jsonb_build_object('ok', true, 'acceptee', 0, 'raison', 'caisse_port_insuffisante');
    INSERT INTO public.exportations_recues(jour, cle, origine, pays, resultat) VALUES (p_jour, p_cle, p_origine, p_pays, v_res);
    RETURN v_res;
  END IF;
  PERFORM public.exportation_stock_interne(v_port, p_cle, v_q);

  v_base := v_q / 3; v_reste := v_q - 3 * v_base;
  FOR v_i IN 1..2 LOOP
    v_part := v_base + CASE WHEN v_i <= v_reste THEN 1 ELSE 0 END;
    v_envoye := 0;
    IF v_part > 0 AND public.exportation_stock_interne(v_autres[v_i], p_cle, 0) IS NOT NULL THEN
      v_envoye := least(v_part, floor(coalesce(public.exportation_solde_interne(v_autres[v_i]), 0) / p_prix)::integer);
      IF v_envoye > 0 AND public.exportation_caisse_interne(v_autres[v_i], -(v_envoye * p_prix)) THEN
        PERFORM public.exportation_caisse_interne(v_port, v_envoye * p_prix);
        PERFORM public.exportation_stock_interne(v_autres[v_i], p_cle, v_envoye);
        PERFORM public.exportation_stock_interne(v_port, p_cle, -v_envoye);
      ELSE
        v_envoye := 0;
      END IF;
    END IF;
    v_parts := v_parts || jsonb_build_object(v_villes[v_i], jsonb_build_object('part', v_part, 'envoye', v_envoye));
  END LOOP;

  v_res := jsonb_build_object('ok', true, 'acceptee', v_q, 'prix', p_prix, 'parts', v_parts);
  INSERT INTO public.exportations_recues(jour, cle, origine, pays, resultat) VALUES (p_jour, p_cle, p_origine, p_pays, v_res);
  RETURN v_res;
END $$;

-- Enveloppe conservée pour la passe de minuit (exportations de Républia vers Sovarka).
CREATE OR REPLACE FUNCTION public.exportation_sovarka_recevoir(p_jour date, p_cle text, p_quantite integer, p_prix numeric)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.exportation_recevoir('republic', 'soviet', p_jour, p_cle, p_quantite, p_prix);
$$;

-- Expédition depuis Sovarka. p_contrats : {"minerai": {"republic": 84, "khalija": 83, "narco": 83}, ...}
CREATE OR REPLACE FUNCTION public.exportations_sovarka_executer(p_jour date, p_contrats jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  c_entrepots constant text[] := ARRAY['soviet_capitale_entrepot-logistique-novomirsk',
                                       'soviet_ville_a_entrepot-logistique-starovka',
                                       'soviet_ville_b_entrepot-logistique-krasnov'];
  v_cle text; v_dests jsonb; v_pays text; v_demande integer; v_prix numeric;
  v_stocks integer[]; v_total integer; v_q integer; v_rec jsonb; v_res jsonb := '{}'::jsonb;
  v_i integer; v_preleve integer[]; v_reste integer; v_ligne jsonb;
BEGIN
  FOR v_cle, v_dests IN SELECT key, value FROM jsonb_each(coalesce(p_contrats, '{}'::jsonb)) LOOP
    SELECT prix_base INTO v_prix FROM public.ressources_economie WHERE cle = v_cle;
    IF coalesce(v_prix, 0) <= 0 THEN CONTINUE; END IF;
    FOR v_pays, v_demande IN SELECT key, (value #>> '{}')::integer FROM jsonb_each(v_dests) LOOP
      IF EXISTS (SELECT 1 FROM public.exportations_recues
                  WHERE jour = p_jour AND cle = v_cle AND origine = 'soviet' AND pays = v_pays) THEN
        v_res := jsonb_set(v_res, ARRAY[v_cle || ':' || v_pays], '"deja_traite"'); CONTINUE;
      END IF;
      v_stocks := ARRAY[]::integer[]; v_total := 0;
      FOR v_i IN 1..3 LOOP
        v_stocks := v_stocks || coalesce(public.exportation_stock_interne(c_entrepots[v_i], v_cle, 0), 0);
        v_total := v_total + v_stocks[v_i];
      END LOOP;
      v_q := least(greatest(coalesce(v_demande, 0), 0), v_total);
      IF v_pays IN ('republic', 'soviet') AND v_q > 0 THEN
        v_rec := public.exportation_recevoir('soviet', v_pays, p_jour, v_cle, v_q, v_prix);
        v_q := CASE WHEN coalesce((v_rec->>'ok')::boolean, false) THEN least(v_q, coalesce((v_rec->>'acceptee')::integer, 0)) ELSE 0 END;
      END IF;
      -- Prélèvement au prorata du stock réel, reste aux plus gros stocks ; chaque entrepôt payé.
      v_preleve := ARRAY[0, 0, 0];
      IF v_q > 0 THEN
        FOR v_i IN 1..3 LOOP v_preleve[v_i] := floor(v_q::numeric * v_stocks[v_i] / v_total)::integer; END LOOP;
        v_reste := v_q - (v_preleve[1] + v_preleve[2] + v_preleve[3]);
        WHILE v_reste > 0 LOOP
          v_i := NULL;
          SELECT i INTO v_i FROM generate_series(1, 3) i
           WHERE v_stocks[i] - v_preleve[i] > 0 ORDER BY v_stocks[i] - v_preleve[i] DESC, i LIMIT 1;
          EXIT WHEN v_i IS NULL;
          v_preleve[v_i] := v_preleve[v_i] + 1; v_reste := v_reste - 1;
        END LOOP;
        FOR v_i IN 1..3 LOOP
          IF v_preleve[v_i] > 0 THEN
            PERFORM public.exportation_stock_interne(c_entrepots[v_i], v_cle, -v_preleve[v_i]);
            PERFORM public.exportation_caisse_interne(c_entrepots[v_i], v_preleve[v_i] * v_prix);
          END IF;
        END LOOP;
      END IF;
      v_ligne := jsonb_build_object('demande', v_demande, 'envoye', v_q, 'prix', v_prix,
                                    'preleve', jsonb_build_object('capitale', v_preleve[1], 'ville_a', v_preleve[2], 'ville_b', v_preleve[3]))
                 || CASE WHEN v_rec IS NOT NULL AND v_pays IN ('republic', 'soviet') THEN jsonb_build_object('reception', v_rec) ELSE '{}'::jsonb END;
      IF v_pays NOT IN ('republic', 'soviet') THEN
        INSERT INTO public.exportations_recues(jour, cle, origine, pays, resultat) VALUES (p_jour, v_cle, 'soviet', v_pays, v_ligne);
      END IF;
      v_res := v_res || jsonb_build_object(v_cle || ':' || v_pays, v_ligne);
      v_rec := NULL;
    END LOOP;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'exportations', v_res);
END $$;

REVOKE ALL ON FUNCTION public.exportation_stock_interne(text, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.exportation_caisse_interne(text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.exportation_solde_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.exportation_recevoir(text, text, date, text, integer, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.exportation_sovarka_recevoir(date, text, integer, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.exportations_sovarka_executer(date, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.exportation_sovarka_recevoir(date, text, integer, numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.exportations_sovarka_executer(date, jsonb) TO service_role;
