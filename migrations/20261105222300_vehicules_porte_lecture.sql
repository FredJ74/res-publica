-- 5 novembre 2026 -- VEHICULES PERSONNELS, etape 4 : la porte d'autorite vehicule_acte et la lecture vehicules_lire.

-- La porte : idempotence par cle de requete (meme registre que les achats), refus jamais memorise.
CREATE OR REPLACE FUNCTION public.vehicule_acte(p_requete uuid, p_action text, p_parametres jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v jsonb; dt text; act text := 'vehicule:' || coalesce(p_action, '');
BEGIN
  IF p_action IS NULL OR p_action NOT IN ('acheter', 'carburant', 'plein', 'charger', 'decharger', 'trajet', 'depanner', 'reviser') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue'); END IF;
  IF p_parametres IS NULL OR jsonb_typeof(p_parametres) <> 'object' THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, act, p_parametres);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := CASE p_action
      WHEN 'acheter'   THEN public.vehicule_acheter_interne(a, p_parametres)
      WHEN 'carburant' THEN public.carburant_acheter_interne(a, p_parametres)
      WHEN 'plein'     THEN public.vehicule_faire_plein_interne(a, p_parametres)
      WHEN 'charger'   THEN public.vehicule_charger_interne(a, p_parametres)
      WHEN 'decharger' THEN public.vehicule_decharger_interne(a, p_parametres)
      WHEN 'trajet'    THEN public.vehicule_trajet_interne(a, p_parametres)
      WHEN 'depanner'  THEN public.vehicule_depanner_interne(a, p_parametres)
      ELSE public.vehicule_reviser_interne(a, p_parametres) END;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'acte_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS dt = PG_EXCEPTION_DETAIL; RETURN dt::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, act, p_parametres, v);
END $$;

-- Lecture : mes vehicules (ceux dont je detiens une cle) et le commerce du lieu ou je me trouve.
CREATE OR REPLACE FUNCTION public.vehicules_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record; v_ici jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building INTO d FROM public.personnages_donnees WHERE name = a;
  SELECT jsonb_build_object('id', e.id, 'type', e.data->>'type', 'proprietaire', e.data->>'proprietaire',
           'stock', e.data->'stockProduits', 'prix', e.data->'parametres'->'prixVente',
           'pieces', coalesce((e.data->'stockMatieres'->>'derives_petrochimiques')::numeric, 0))
    INTO v_ici FROM public.entreprises e
   WHERE e.data->>'type' IN ('garage', 'station-service') AND e.data->>'country' = d.country
     AND e.data->>'city' = d.current_city AND e.data->>'buildingId' = d.current_building LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'ici', v_ici, 'vehicules', coalesce((
    SELECT jsonb_agg(jsonb_build_object('id', v.id, 'modele', v.modele, 'label', m.label, 'numero', public.serrure_numero_interne(v.serrure),
      'proprietaire', v.proprietaire, 'pays', v.pays, 'ville', v.ville, 'sur_place', (v.pays, v.ville) = (d.country, d.current_city),
      'places', m.places, 'chargement', m.chargement, 'reservoir', m.reservoir, 'carburant', v.carburant,
      'cargaison', v.cargaison, 'unites', public.vehicule_unites_interne(v.cargaison),
      'consommation', public.vehicule_consommation_interne(v.cargaison), 'trajets', v.trajets_depuis_revision,
      'statut', v.statut, 'panne', v.panne,
      'routes', (SELECT coalesce(jsonb_agg(CASE WHEN r.ville_a = v.ville THEN r.ville_b ELSE r.ville_a END), '[]'::jsonb)
                   FROM public.routes_vehicules r WHERE r.pays = v.pays AND v.ville IN (r.ville_a, r.ville_b)))
      ORDER BY v.achete_le)
      FROM public.vehicules v JOIN public.vehicules_modeles m ON m.modele = v.modele
     WHERE public.serrure_cle_detenue_interne(a, v.serrure)), '[]'::jsonb));
END $$;

REVOKE ALL ON FUNCTION public.vehicule_garages_interne(text, text[]), public.vehicule_trajet_interne(text, jsonb),
  public.vehicule_depanner_interne(text, jsonb), public.vehicule_reviser_interne(text, jsonb)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.vehicule_acte(uuid, text, jsonb), public.vehicules_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vehicule_acte(uuid, text, jsonb), public.vehicules_lire() TO authenticated;

-- Ordres d'ecran (ouverture des fenetres, gratuits) : connus du miroir des couts.
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT x.fn, 0, 0 FROM (VALUES ('garage_vehicules'), ('garage_reviser'), ('station_carburant'), ('mes_vehicules')) x(fn)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = x.fn AND o.pa = 0 AND o.cost = 0);
