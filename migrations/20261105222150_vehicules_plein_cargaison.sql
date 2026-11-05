-- APPLIQUEE le 05/11/2026 par Claude (registre vehicules_plein_cargaison_20261105222150), puis banc annule outils/bancs/banc-vehicules.sql joue en production : vert.
-- 5 novembre 2026 -- VEHICULES PERSONNELS, etape 2 bis : faire le plein, charger, decharger (GAME-DESIGN-VEHICULES.md).
-- Moteurs sans autorite : appeles par la porte vehicule_acte (etape 3).

-- Vehicule accessible : la cle est detenue et le vehicule est dans la ville du personnage.
CREATE OR REPLACE FUNCTION public.vehicule_accessible_interne(p_moi text, p_vehicule uuid)
RETURNS public.vehicules LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v public.vehicules; d record;
BEGIN
  SELECT * INTO v FROM public.vehicules WHERE id = p_vehicule FOR UPDATE;
  IF v.id IS NULL OR NOT public.serrure_cle_detenue_interne(p_moi, v.serrure) THEN RETURN NULL; END IF;
  SELECT country, current_city INTO d FROM public.personnages_donnees WHERE name = p_moi;
  IF (d.country, d.current_city) IS DISTINCT FROM (v.pays, v.ville) THEN RETURN NULL; END IF;
  RETURN v;
END $$;

CREATE OR REPLACE FUNCTION public.vehicule_faire_plein_interne(p_moi text, p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v public.vehicules; v_res integer; v_q integer := (p->>'qte')::integer; v_inv jsonb;
BEGIN
  v := public.vehicule_accessible_interne(p_moi, (p->>'vehicule')::uuid);
  IF v.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'vehicule_hors_de_portee'); END IF;
  SELECT reservoir INTO v_res FROM public.vehicules_modeles WHERE modele = v.modele;
  IF v_q IS NULL OR v_q < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  IF v.carburant + v_q > v_res THEN RETURN jsonb_build_object('ok', false, 'raison', 'reservoir_plein', 'place', v_res - v.carburant); END IF;
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = p_moi FOR UPDATE;
  IF public.inventaire_quantite(v_inv, 'carburant') < v_q THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bidons_insuffisants', 'detenu', public.inventaire_quantite(v_inv, 'carburant')); END IF;
  UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer(v_inv, 'carburant', v_q) WHERE name = p_moi;
  UPDATE public.vehicules SET carburant = carburant + v_q, modifie_le = now() WHERE id = v.id;
  RETURN jsonb_build_object('ok', true, 'carburant', v.carburant + v_q, 'reservoir', v_res) || public.vehicule_inventaire_reponse_interne(p_moi);
END $$;

CREATE OR REPLACE FUNCTION public.vehicule_charger_interne(p_moi text, p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v public.vehicules; v_cap integer; d record; v_r jsonb; v_obj jsonb; v_cle text; v_carg jsonb; v_pos integer;
BEGIN
  v := public.vehicule_accessible_interne(p_moi, (p->>'vehicule')::uuid);
  IF v.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'vehicule_hors_de_portee'); END IF;
  IF v.statut <> 'pret' THEN RETURN jsonb_build_object('ok', false, 'raison', 'vehicule_en_panne'); END IF;
  SELECT chargement INTO v_cap FROM public.vehicules_modeles WHERE modele = v.modele;
  SELECT coalesce(inventory, '[]'::jsonb) AS inv, quete_carriere INTO d FROM public.personnages_donnees WHERE name = p_moi FOR UPDATE;
  v_r := public.helvetia_inventaire_sortie(d.inv, d.quete_carriere, (p->>'index')::integer, p->'signature', coalesce((p->>'qte')::integer, 1));
  IF coalesce((v_r->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;
  v_obj := v_r->'objet';
  IF v_obj->>'serrureId' = v.serrure::text THEN RETURN jsonb_build_object('ok', false, 'raison', 'cle_du_vehicule'); END IF;
  IF public.vehicule_unites_interne(v.cargaison) + public.vehicule_unites_interne(jsonb_build_array(v_obj)) > v_cap THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chargement_plein',
      'place', v_cap - public.vehicule_unites_interne(v.cargaison)); END IF;
  v_carg := v.cargaison; v_cle := nullif(v_obj->>'stackKey', '');
  IF coalesce((v_obj->>'stackable')::boolean, false) AND v_cle IS NOT NULL THEN
    SELECT (o.ord - 1)::integer INTO v_pos FROM jsonb_array_elements(v_carg) WITH ORDINALITY o(val, ord)
     WHERE o.val->>'stackKey' = v_cle ORDER BY o.ord LIMIT 1;
  END IF;
  IF v_pos IS NOT NULL THEN
    v_carg := jsonb_set(v_carg, ARRAY[v_pos::text, 'qty'], to_jsonb(coalesce((v_carg->v_pos->>'qty')::numeric, 1) + (v_obj->>'qty')::numeric));
  ELSE
    v_carg := v_carg || jsonb_build_array(v_obj);
  END IF;
  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_moi;
  UPDATE public.vehicules SET cargaison = v_carg, modifie_le = now() WHERE id = v.id;
  RETURN jsonb_build_object('ok', true, 'cargaison', v_carg) || public.vehicule_inventaire_reponse_interne(p_moi);
END $$;

CREATE OR REPLACE FUNCTION public.vehicule_decharger_interne(p_moi text, p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v public.vehicules; v_pos integer := (p->>'position')::integer; v_q integer := coalesce((p->>'qte')::integer, 1);
  v_obj jsonb; v_detenu numeric; v_pile boolean; v_carg jsonb; v_dep jsonb;
BEGIN
  v := public.vehicule_accessible_interne(p_moi, (p->>'vehicule')::uuid);
  IF v.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'vehicule_hors_de_portee'); END IF;
  IF v_pos IS NULL OR v_pos < 0 OR v_pos >= jsonb_array_length(v.cargaison) THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
  v_obj := v.cargaison->v_pos;
  IF p->'signature' IS NOT NULL AND (v_obj->>'name') IS DISTINCT FROM (p->'signature'->>'name') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
  v_pile := coalesce((v_obj->>'stackable')::boolean, false) AND nullif(v_obj->>'stackKey', '') IS NOT NULL;
  v_detenu := CASE WHEN v_pile THEN coalesce((v_obj->>'qty')::numeric, 1) ELSE 1 END;
  IF v_q < 1 OR v_q > v_detenu THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_insuffisante', 'detenu', v_detenu); END IF;
  v_carg := CASE WHEN v_pile AND v_q < v_detenu THEN jsonb_set(v.cargaison, ARRAY[v_pos::text, 'qty'], to_jsonb(v_detenu - v_q))
                 ELSE public.inventaire_retirer_position(v.cargaison, v_pos) END;
  v_dep := public.inventaire_deposer_interne(p_moi, CASE WHEN v_pile THEN v_obj || jsonb_build_object('qty', v_q) ELSE v_obj END);
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_dep->>'raison', 'inventaire_plein')); END IF;
  IF v_pile AND (v_dep->>'qte')::integer IS DISTINCT FROM v_q THEN
    RAISE EXCEPTION 'decharge_partielle' USING ERRCODE = 'HG001', DETAIL = jsonb_build_object('ok', false, 'raison', 'inventaire_plein')::text; END IF;
  UPDATE public.vehicules SET cargaison = v_carg, modifie_le = now() WHERE id = v.id;
  RETURN jsonb_build_object('ok', true, 'cargaison', v_carg) || public.vehicule_inventaire_reponse_interne(p_moi);
END $$;

REVOKE ALL ON FUNCTION public.vehicule_unites_interne(jsonb), public.vehicule_consommation_interne(jsonb),
  public.vehicule_inventaire_reponse_interne(text), public.vehicule_encaisser_interne(text, text, numeric, text),
  public.vehicule_acheter_interne(text, jsonb), public.carburant_acheter_interne(text, jsonb),
  public.vehicule_accessible_interne(text, uuid), public.vehicule_faire_plein_interne(text, jsonb),
  public.vehicule_charger_interne(text, jsonb), public.vehicule_decharger_interne(text, jsonb)
  FROM PUBLIC, anon, authenticated, service_role;
