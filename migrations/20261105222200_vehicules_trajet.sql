-- APPLIQUEE le 05/11/2026 par Claude (registre vehicules_trajet_20261105222200), puis banc annule outils/bancs/banc-vehicules.sql joue en production : vert.
-- 5 novembre 2026 -- VEHICULES PERSONNELS, etape 3 : conduire, panne, depannage, revision, lecture.
-- Decisions de Fred (GAME-DESIGN-VEHICULES.md) :
--   * trajet entre deux villes reliees par la route d'un meme pays, depuis n'importe quel endroit de
--     la ville, arrivee devant le centre multimodal ; 1 PA par occupant PJ ; occupants = le groupe du
--     conducteur (socle des groupes, PJ et PNJ), dans la limite des places ;
--   * consommation 10 + 1 par tranche de 50 unites de chargement, prelevee au depart ;
--   * panne selon le rang du trajet depuis la revision : 1-9 aucune, 10e 50 %, +10 % ensuite,
--     15e : ne demarre plus. Tirage serveur. En panne, personne n'arrive : le conducteur choisit un
--     garage des deux villes du trajet (450), sinon du reste du pays (600) ; le depannage ramene
--     vehicule et groupe dans la ville du garage, et la revision reste due avant de repartir ;
--   * revision au garage : 10 derives petrochimiques du garage, 500 dans un garage PNJ.

CREATE OR REPLACE FUNCTION public.vehicule_garages_interne(p_pays text, p_villes text[])
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  -- Garages des villes du trajet ; s'il n'y en a aucun, ceux du reste du pays avec 150 de surcout.
  WITH g AS (SELECT id, data->>'city' AS ville, coalesce(nullif(data->>'nom', ''), 'Garage') AS nom, data->>'proprietaire' AS proprietaire
               FROM public.entreprises WHERE data->>'type' = 'garage' AND data->>'country' = p_pays),
       proches AS (SELECT * FROM g WHERE ville = ANY(p_villes))
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', id, 'ville', ville, 'nom', nom, 'proprietaire', proprietaire,
           'prix', CASE WHEN EXISTS (SELECT 1 FROM proches) THEN 450 ELSE 600 END) ORDER BY ville, id), '[]'::jsonb)
    FROM (SELECT * FROM proches UNION ALL SELECT * FROM g WHERE NOT EXISTS (SELECT 1 FROM proches)) x;
$$;

CREATE OR REPLACE FUNCTION public.vehicule_trajet_interne(p_moi text, p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v public.vehicules; m public.vehicules_modeles; d public.personnages_donnees%ROWTYPE;
  v_dest text := p->>'ville'; ids text[]; pnjs text[]; n text; r jsonb; v_conso integer; v_rang integer;
  v_proba numeric; b text; piece text; v_garages jsonb;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe', 0));
  v := public.vehicule_accessible_interne(p_moi, (p->>'vehicule')::uuid);
  IF v.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'vehicule_hors_de_portee'); END IF;
  IF v.statut = 'en_panne' THEN RETURN jsonb_build_object('ok', false, 'raison', 'vehicule_en_panne', 'panne', v.panne); END IF;
  SELECT * INTO m FROM public.vehicules_modeles WHERE modele = v.modele;
  IF NOT EXISTS (SELECT 1 FROM public.routes_vehicules WHERE pays = v.pays
                  AND ville_a = least(v.ville, v_dest) AND ville_b = greatest(v.ville, v_dest)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_route'); END IF;
  SELECT batiment, pieces->>0 INTO b, piece FROM public.navigation_lieux_regles
   WHERE pays = v.pays AND ville = v_dest AND batiment LIKE 'centre-multinodal-%' ORDER BY batiment LIMIT 1;
  IF b IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'arrivee_non_referencee'); END IF;
  v_rang := v.trajets_depuis_revision + 1;
  IF v_rang >= 15 THEN RETURN jsonb_build_object('ok', false, 'raison', 'revision_requise'); END IF;
  -- Le groupe du conducteur : il doit en etre le chef, complet et reuni au meme endroit.
  IF EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE membre = p_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chef_de_groupe_requis'); END IF;
  SELECT array_agg(identifiant ORDER BY identifiant) FILTER (WHERE est_pj),
         coalesce(array_agg(identifiant ORDER BY identifiant) FILTER (WHERE NOT est_pj), '{}'::text[])
    INTO ids, pnjs FROM public.groupe_participants_interne(p_moi);
  PERFORM public.pnj_groupes_verrouiller_projections_interne(pnjs);
  PERFORM name FROM public.personnages_donnees WHERE name = ANY(ids) ORDER BY name FOR UPDATE;
  IF cardinality(ids) <> (SELECT count(*) + 1 FROM public.groupes_pj_adhesions WHERE chef = p_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'groupe_incomplet'); END IF;
  IF cardinality(ids) + cardinality(pnjs) > m.places THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'trop_d_occupants', 'places', m.places, 'occupants', cardinality(ids) + cardinality(pnjs)); END IF;
  SELECT * INTO d FROM public.personnages_donnees WHERE name = p_moi;
  IF EXISTS (SELECT 1 FROM public.personnages_donnees x WHERE x.name = ANY(ids) AND (
       (x.country, x.current_city, x.current_building) IS DISTINCT FROM (d.country, d.current_city, d.current_building)
       OR (d.current_building IS NOT NULL AND x.current_room IS DISTINCT FROM d.current_room)
       OR (d.current_building IS NULL AND x.current_street IS DISTINCT FROM d.current_street))) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'groupe_disperse'); END IF;
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = ANY(pnjs) AND (statut <> 'actif'
       OR (SELECT pe.pays FROM public.pnj_position_effective(pnj_membres.id) pe) IS DISTINCT FROM d.country)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'membre_pnj_indisponible'); END IF;
  FOREACH n IN ARRAY ids LOOP
    r := public.navigation_disponibilite_interne(n);
    IF NOT coalesce((r->>'ok')::boolean, false) THEN RETURN r || jsonb_build_object('membre', n); END IF;
    IF (SELECT public.vehicule_unites_interne(inventory) FROM public.personnages_donnees WHERE name = n) > 100 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_surcharge', 'membre', n); END IF;
    IF (SELECT coalesce(pa, 0) FROM public.personnages_donnees WHERE name = n) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'membre', n); END IF;
  END LOOP;
  v_conso := public.vehicule_consommation_interne(v.cargaison);
  IF v.carburant < v_conso THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'carburant_insuffisant', 'carburant', v.carburant, 'requis', v_conso); END IF;

  -- Le trajet commence : 1 PA par occupant PJ, carburant du trajet, un trajet de plus.
  UPDATE public.personnages_donnees SET pa = pa - 1, updated_at = clock_timestamp() WHERE name = ANY(ids);
  v_proba := CASE WHEN v_rang < 10 THEN 0 ELSE 0.5 + 0.1 * (v_rang - 10) END;
  IF random() < v_proba THEN
    v_garages := public.vehicule_garages_interne(v.pays, ARRAY[v.ville, v_dest]);
    UPDATE public.vehicules SET carburant = carburant - v_conso, trajets_depuis_revision = v_rang, statut = 'en_panne',
      panne = jsonb_build_object('depart', v.ville, 'destination', v_dest, 'le', now(), 'garages', v_garages), modifie_le = now()
     WHERE id = v.id;
    RETURN jsonb_build_object('ok', true, 'panne', true, 'garages', v_garages, 'depart', v.ville, 'destination', v_dest,
      'occupants', cardinality(ids) + cardinality(pnjs), 'consommation', v_conso) || public.vehicule_inventaire_reponse_interne(p_moi);
  END IF;
  UPDATE public.vehicules SET carburant = carburant - v_conso, trajets_depuis_revision = v_rang, ville = v_dest, modifie_le = now() WHERE id = v.id;
  UPDATE public.personnages_donnees SET current_city = v_dest, current_building = b, current_room = piece, current_street = NULL,
    updated_at = clock_timestamp() WHERE name = ANY(ids);
  PERFORM public.pnj_groupes_projeter_interne(pnjs);
  RETURN jsonb_build_object('ok', true, 'panne', false, 'pays', v.pays, 'ville', v_dest, 'building', b, 'room', piece,
    'membres', to_jsonb(ids), 'occupants', cardinality(ids) + cardinality(pnjs), 'consommation', v_conso,
    'carburant', v.carburant - v_conso, 'rang', v_rang) || public.vehicule_inventaire_reponse_interne(p_moi);
END $$;

