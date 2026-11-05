-- APPLIQUEE le 05/11/2026 par Claude (registre vehicules_depannage_revision_20261105222250), puis banc annule outils/bancs/banc-vehicules.sql joue en production : vert.
-- 5 novembre 2026 -- VEHICULES PERSONNELS, etape 3 bis : depannage et revision (GAME-DESIGN-VEHICULES.md).
-- Moteurs sans autorite : appeles par la porte vehicule_acte (etape 4).

CREATE OR REPLACE FUNCTION public.vehicule_depanner_interne(p_moi text, p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v public.vehicules; v_garages jsonb; g jsonb; v_data jsonb; ids text[]; pnjs text[]; d record; r jsonb; b text; piece text;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe', 0));
  v := public.vehicule_accessible_interne(p_moi, (p->>'vehicule')::uuid);
  IF v.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'vehicule_hors_de_portee'); END IF;
  IF v.statut <> 'en_panne' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_panne'); END IF;
  v_garages := public.vehicule_garages_interne(v.pays, ARRAY[v.panne->>'depart', v.panne->>'destination']);
  SELECT x INTO g FROM jsonb_array_elements(v_garages) x WHERE x->>'id' = p->>'garage';
  IF g IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'garage_non_propose', 'garages', v_garages); END IF;
  SELECT data INTO v_data FROM public.entreprises WHERE id = g->>'id';
  r := public.vehicule_encaisser_interne(p_moi, g->>'id', (g->>'prix')::numeric, 'Dépannage');
  IF coalesce((r->>'ok')::boolean, false) IS NOT TRUE THEN RETURN r; END IF;
  -- Arrivee : au garage s'il est un lieu declare, sinon devant le centre multimodal.
  SELECT batiment, pieces->>0 INTO b, piece FROM public.navigation_lieux_regles
   WHERE pays = v.pays AND ville = g->>'ville' AND batiment = v_data->>'buildingId';
  IF b IS NULL THEN
    SELECT batiment, pieces->>0 INTO b, piece FROM public.navigation_lieux_regles
     WHERE pays = v.pays AND ville = g->>'ville' AND batiment LIKE 'centre-multinodal-%' ORDER BY batiment LIMIT 1;
  END IF;
  SELECT country, current_city, current_building, current_room, current_street INTO d FROM public.personnages_donnees WHERE name = p_moi;
  -- Le groupe du conducteur qui se trouve avec lui suit le vehicule.
  SELECT array_agg(gp.identifiant ORDER BY gp.identifiant) FILTER (WHERE gp.est_pj),
         coalesce(array_agg(gp.identifiant ORDER BY gp.identifiant) FILTER (WHERE NOT gp.est_pj), '{}'::text[])
    INTO ids, pnjs FROM public.groupe_participants_interne(p_moi) gp;
  SELECT array_agg(x.name ORDER BY x.name) INTO ids FROM public.personnages_donnees x
   WHERE x.name = ANY(ids) AND (x.country, x.current_city, x.current_building) IS NOT DISTINCT FROM (d.country, d.current_city, d.current_building)
     AND (CASE WHEN d.current_building IS NULL THEN x.current_street IS NOT DISTINCT FROM d.current_street ELSE x.current_room IS NOT DISTINCT FROM d.current_room END);
  UPDATE public.vehicules SET statut = 'pret', panne = NULL, ville = g->>'ville', trajets_depuis_revision = 15, modifie_le = now() WHERE id = v.id;
  IF b IS NOT NULL THEN
    UPDATE public.personnages_donnees SET current_city = g->>'ville', current_building = b, current_room = piece, current_street = NULL,
      updated_at = clock_timestamp() WHERE name = ANY(ids);
    PERFORM public.pnj_groupes_projeter_interne(pnjs);
  END IF;
  RETURN jsonb_build_object('ok', true, 'garage', g, 'ville', g->>'ville', 'building', b, 'room', piece, 'membres', to_jsonb(ids))
    || public.vehicule_inventaire_reponse_interne(p_moi);
END $$;

CREATE OR REPLACE FUNCTION public.vehicule_reviser_interne(p_moi text, p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v public.vehicules; v_data jsonb; d record; v_prix numeric; v_stock numeric; r jsonb;
BEGIN
  v := public.vehicule_accessible_interne(p_moi, (p->>'vehicule')::uuid);
  IF v.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'vehicule_hors_de_portee'); END IF;
  IF v.statut = 'en_panne' THEN RETURN jsonb_build_object('ok', false, 'raison', 'vehicule_en_panne'); END IF;
  IF v.trajets_depuis_revision = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_revise'); END IF;
  SELECT data INTO v_data FROM public.entreprises WHERE id = p->>'entreprise' FOR UPDATE;
  IF v_data IS NULL OR v_data->>'type' IS DISTINCT FROM 'garage' THEN RETURN jsonb_build_object('ok', false, 'raison', 'garage_introuvable'); END IF;
  SELECT country, current_city, current_building INTO d FROM public.personnages_donnees WHERE name = p_moi;
  IF (d.country, d.current_city, d.current_building) IS DISTINCT FROM (v_data->>'country', v_data->>'city', v_data->>'buildingId') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_stock := coalesce((v_data->'stockMatieres'->>'derives_petrochimiques')::numeric, 0);
  IF v_stock < 10 THEN RETURN jsonb_build_object('ok', false, 'raison', 'garage_sans_pieces', 'stock', v_stock); END IF;
  v_prix := CASE WHEN coalesce(v_data->>'proprietaire', 'PNJ') = 'PNJ' THEN 500
                 ELSE coalesce((v_data->'parametres'->'prixVente'->>'revision_vehicule')::numeric, 500) END;
  UPDATE public.entreprises SET data = jsonb_set(data, '{stockMatieres,derives_petrochimiques}', to_jsonb(v_stock - 10)), updated_at = now()
   WHERE id = p->>'entreprise';
  r := public.vehicule_encaisser_interne(p_moi, p->>'entreprise', v_prix, 'Révision de véhicule');
  IF coalesce((r->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'revision_refusee' USING ERRCODE = 'HG001', DETAIL = r::text; END IF;
  UPDATE public.vehicules SET trajets_depuis_revision = 0, modifie_le = now() WHERE id = v.id;
  RETURN jsonb_build_object('ok', true, 'prix', v_prix) || public.vehicule_inventaire_reponse_interne(p_moi);
END $$;

