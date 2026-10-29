-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261028204032.
-- Eprouvee au role authenticated en transaction annulee : dépôt : pile unique, quantités entières, refus des inventaires mal formés.
-- (Preparee par Codex.) PREPAREE NON APPLIQUEE. Meme depot commun : quantites entieres, une seule pile incrementee. Aucun verrou final.
CREATE OR REPLACE FUNCTION public.inventaire_deposer_interne(p_nom text, p_objet jsonb, p_automatique boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_place integer; v_q integer; v_cle text; v_obj jsonb := p_objet; v_pile bigint;
BEGIN
  IF p_objet IS NULL OR jsonb_typeof(p_objet) <> 'object' THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_invalide'); END IF;
  SELECT coalesce(inventory,'[]'::jsonb) INTO v_inv
    FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF jsonb_typeof(v_inv) IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_format_a_examiner'); END IF;
  v_place := CASE WHEN p_automatique THEN 1000000 ELSE public.inventaire_place_restante(v_inv) END;
  v_cle := nullif(p_objet ->> 'stackKey', '');
  IF coalesce((p_objet ->> 'stackable')::boolean, false) AND v_cle IS NOT NULL THEN
    IF coalesce((p_objet->>'qty')::numeric,1)<=0 OR coalesce((p_objet->>'qty')::numeric,1)<>trunc(coalesce((p_objet->>'qty')::numeric,1)) THEN
      RETURN jsonb_build_object('ok',false,'raison','quantite_invalide'); END IF;
    v_q := least(coalesce((p_objet->>'qty')::numeric,1),v_place)::integer;
    IF v_q <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
    SELECT o INTO v_pile FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e,o) WHERE coalesce((e->>'stackable')::boolean,false) AND e->>'stackKey'=v_cle ORDER BY o LIMIT 1;
    IF v_pile IS NOT NULL THEN
      SELECT jsonb_agg(CASE WHEN o=v_pile
                       THEN jsonb_set(e, '{qty}', to_jsonb(coalesce((e ->> 'qty')::numeric, 1) + v_q)) ELSE e END ORDER BY o)
        INTO v_inv FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o);
    ELSE
      v_inv := v_inv || jsonb_build_array(p_objet || jsonb_build_object('qty', v_q));
    END IF;
  ELSE
    v_q := greatest(1, coalesce((p_objet ->> 'encombrement')::numeric, 1)::integer);
    IF v_place < v_q THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
    IF coalesce(p_objet ->> 'id', '') = '' THEN
      v_obj := p_objet || jsonb_build_object('id', 'obj-' || replace(gen_random_uuid()::text, '-', ''));
    END IF;
    v_inv := v_inv || jsonb_build_array(v_obj);
    v_q := 1;
  END IF;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_nom;
  RETURN jsonb_build_object('ok', true, 'qte', v_q)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_nom);
END; $function$;
REVOKE ALL ON FUNCTION public.inventaire_deposer_interne(text,jsonb,boolean) FROM PUBLIC,anon,authenticated;
