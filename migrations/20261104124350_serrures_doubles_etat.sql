-- APPLIQUEE le 04/11/2026 par Claude (registre serrures_doubles_etat_20261104124350), structure eprouvee en transaction annulee
-- avant application, puis banc annule outils/bancs/banc-serrures.sql joue en production : vert.
-- 4 novembre 2026 -- SERRURES, etape 4 bis : dupliquer une cle, lire l'etat d'une serrure (issue #434).
-- Suite de 20261104124300_serrures_pose_cles.sql (scindee : limite de taille du canal MCP).
--   cle_dupliquer(requete, serrure) : une cle detenue + une cle vierge -> un double, sans autre
--     frais (decision du 01/11 : ne pas inventer de cout) ; doubles illimites (04/11).
--   serrure_etat(serrure) : ce que sait le detenteur d'une cle ou du bloc.

CREATE OR REPLACE FUNCTION public.cle_dupliquer(p_requete uuid, p_serrure uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text := public.mon_personnage(); prm jsonb; v jsonb; s public.serrures; v_inv jsonb; v_pos integer; v_q numeric; v_dep jsonb;
BEGIN
  prm := jsonb_build_object('serrure', p_serrure);
  v := public.achat_requete_ouvrir_interne(v_moi, p_requete, 'cle_dupliquer', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT * INTO s FROM public.serrures WHERE id = p_serrure;
  IF s.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'serrure_introuvable'); END IF;
  IF s.cible = 'lieu' THEN PERFORM public.serrures_fin_bail_interne(s.pays, s.ville, s.batiment, s.piece); END IF;
  SELECT * INTO s FROM public.serrures WHERE id = p_serrure;
  IF s.statut = 'detruite' THEN RETURN jsonb_build_object('ok', false, 'raison', 'serrure_detruite'); END IF;
  IF NOT public.serrure_cle_detenue_interne(v_moi, s.id) THEN RETURN jsonb_build_object('ok', false, 'raison', 'cle_requise'); END IF;
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT (o.ord - 1)::integer, coalesce((o.val->>'qty')::numeric, 1) INTO v_pos, v_q
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_inv) = 'array' THEN v_inv ELSE '[]'::jsonb END) WITH ORDINALITY o(val, ord)
   WHERE o.val->>'type' = 'cle_vierge' ORDER BY o.ord LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'cle_vierge_requise'); END IF;
  v_inv := CASE WHEN v_q > 1 THEN jsonb_set(v_inv, ARRAY[v_pos::text, 'qty'], to_jsonb(v_q - 1))
                ELSE public.inventaire_retirer_position(v_inv, v_pos) END;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;
  v_dep := public.inventaire_deposer_interne(v_moi, public.serrure_cle_objet_interne(s.id, 1));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'cle_dupliquer: double refuse %', v_dep; END IF;
  RETURN public.achat_requete_clore_interne(v_moi, p_requete, 'cle_dupliquer', prm,
    jsonb_build_object('ok', true, 'serrure', s.id, 'numero', public.serrure_numero_interne(s.id)));
END $$;

CREATE OR REPLACE FUNCTION public.serrure_etat(p_serrure uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text := public.mon_personnage(); s public.serrures; d record;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO s FROM public.serrures WHERE id = p_serrure;
  IF s.id IS NULL OR NOT (public.serrure_cle_detenue_interne(v_moi, s.id) OR EXISTS (
       SELECT 1 FROM public.personnages_donnees x, jsonb_array_elements(CASE WHEN jsonb_typeof(x.inventory) = 'array' THEN x.inventory ELSE '[]'::jsonb END) o
        WHERE x.name = v_moi AND o->>'type' = 'serrure_cle' AND o->>'serrureId' = s.id::text)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'serrure_introuvable'); END IF;
  IF s.cible = 'lieu' THEN
    PERFORM public.serrures_fin_bail_interne(s.pays, s.ville, s.batiment, s.piece);
    SELECT * INTO s FROM public.serrures WHERE id = p_serrure;
  END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true, 'serrure', s.id, 'numero', public.serrure_numero_interne(s.id), 'statut', s.statut,
    'fermee', s.fermee, 'cible', s.cible, 'pays', s.pays, 'ville', s.ville, 'batiment', s.batiment, 'piece', s.piece,
    'a_portee', s.statut = 'posee' AND CASE WHEN s.cible = 'lieu'
                  THEN (d.country, d.current_city, d.current_building) IS NOT DISTINCT FROM (s.pays, s.ville, s.batiment)
                  ELSE public.serrure_armoire_a_portee_interne(v_moi, s.armoire_objet) END);
END $$;

REVOKE ALL ON FUNCTION public.cle_dupliquer(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.serrure_etat(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cle_dupliquer(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.serrure_etat(uuid) TO authenticated;
