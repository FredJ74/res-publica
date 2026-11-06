-- APPLIQUEE le 05/11/2026 par Claude (registre vehicules_commerce_20261105222100), puis banc annule outils/bancs/banc-vehicules.sql joue en production : vert.
-- 5 novembre 2026 -- VEHICULES PERSONNELS, etape 2 : moteurs et actes de commerce (GAME-DESIGN-VEHICULES.md).
--
-- Moteurs sans autorite (EXECUTE pour personne) : unites de chargement, consommation d'un trajet,
-- encaissement d'une prestation par un garage, reponse d'inventaire. Puis une porte unique
-- vehicule_acte_interne qui rend chaque acte idempotent (cle de requete, rejeu sans second
-- paiement, refus jamais memorise) et quatre actes :
--   * achat d'un vehicule au garage (moteur commun des commerces : stock, prix, taxe, caisse) :
--     le vehicule nait au lieu du garage, avec sa serrure et UNE cle dans l'inventaire ;
--   * achat de bidons a la station (1 bidon = 1 unite de carburant, pile 'carburant') ;
--   * faire le plein (bidons de l'inventaire -> reservoir, jamais au-dela) ;
--   * charger / decharger la cargaison (objets de l'inventaire, capacite du modele).
-- Conduire, panne, depannage et revision : etape 3.

CREATE OR REPLACE FUNCTION public.vehicule_unites_interne(p_objets jsonb)
RETURNS numeric LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  -- Meme decompte que la garde de deplacement (transport_effectuer) : qty, sinon encombrement, sinon 1.
  SELECT coalesce(sum(coalesce(nullif(x->>'qty', '')::numeric, nullif(x->>'encombrement', '')::numeric, 1)), 0)
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_objets) = 'array' THEN p_objets ELSE '[]'::jsonb END) x;
$$;

CREATE OR REPLACE FUNCTION public.vehicule_consommation_interne(p_cargaison jsonb)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  -- Decision de Fred : 10 unites + 1 par tranche de 50 unites de chargement.
  SELECT 10 + floor(public.vehicule_unites_interne(p_cargaison) / 50)::integer;
$$;

CREATE OR REPLACE FUNCTION public.vehicule_inventaire_reponse_interne(p_nom text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('inventory', coalesce(inventory, '[]'::jsonb), 'revision', inventory_revision,
    'pa', pa, 'liquide', liquide, 'arg', arg)
    FROM public.personnages_donnees WHERE name = p_nom;
$$;

-- Prestation payee a un commerce (depannage, revision) : debit du client, taxe locale, caisse,
-- journal du commerce. Meme ordre d'operations que commerce_vendre_produit_interne.
CREATE OR REPLACE FUNCTION public.vehicule_encaisser_interne(p_acteur text, p_entreprise text, p_montant numeric, p_libelle text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_data jsonb; v_taxe jsonb; v_net numeric; v_jour integer;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'garage_introuvable'); END IF;
  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, p_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'total', p_montant); END IF;
  v_taxe := public.appliquer_taxe_transaction(coalesce(v_data->>'country', 'republic'), coalesce(v_data->>'city', 'capitale'), p_montant);
  v_net := coalesce((v_taxe->>'net')::numeric, p_montant);
  SELECT coalesce(day, 1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_data := jsonb_set(v_data, '{caisse}', to_jsonb(greatest(0, coalesce((v_data->>'caisse')::numeric, 0)) + v_net), true);
  v_data := public.entreprise_ajouter_historique(v_data, v_net, p_libelle || ' — ' || p_acteur, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;
  RETURN jsonb_build_object('ok', true, 'montant', p_montant, 'net', v_net);
END $$;

CREATE OR REPLACE FUNCTION public.vehicule_acheter_interne(p_moi text, p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_data jsonb; d record; v_r jsonb; v_dep jsonb; v_serrure uuid; v_id uuid; v_modele text := p->>'modele';
BEGIN
  SELECT data INTO v_data FROM public.entreprises WHERE id = p->>'entreprise';
  IF v_data IS NULL OR v_data->>'type' IS DISTINCT FROM 'garage' THEN RETURN jsonb_build_object('ok', false, 'raison', 'garage_introuvable'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.vehicules_modeles WHERE modele = v_modele) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_non_propose'); END IF;
  SELECT country, current_city, current_building, inventory INTO d FROM public.personnages_donnees WHERE name = p_moi FOR UPDATE;
  IF (d.country, d.current_city, d.current_building) IS DISTINCT FROM (v_data->>'country', v_data->>'city', v_data->>'buildingId') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF public.inventaire_place_restante(d.inventory) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_r := public.commerce_vendre_produit_interne(p_moi, p->>'entreprise',
           jsonb_build_array(jsonb_build_object('produit', v_modele, 'qte', 1)), 'comptoir', NULL, 0, 0, NULL, NULL);
  IF coalesce((v_r->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;
  INSERT INTO public.serrures (statut, cible, poseur, posee_le, achetee_par, entreprise, pays, ville)
    VALUES ('posee', 'vehicule', p_moi, now(), p_moi, p->>'entreprise', d.country, d.current_city) RETURNING id INTO v_serrure;
  INSERT INTO public.vehicules (modele, proprietaire, serrure, pays, ville, entreprise)
    VALUES (v_modele, p_moi, v_serrure, d.country, d.current_city, p->>'entreprise') RETURNING id INTO v_id;
  v_dep := public.inventaire_deposer_interne(p_moi, public.serrure_cle_objet_interne(v_serrure, 1)
             || jsonb_build_object('desc', 'Clé du véhicule n° ' || public.serrure_numero_interne(v_serrure) || '. Qui la détient peut le conduire.'));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'vehicule_acheter: cle refusee %', v_dep; END IF;
  RETURN jsonb_build_object('ok', true, 'vehicule', v_id, 'numero', public.serrure_numero_interne(v_serrure),
    'modele', v_modele, 'total', v_r->'total') || public.vehicule_inventaire_reponse_interne(p_moi);
END $$;

CREATE OR REPLACE FUNCTION public.carburant_acheter_interne(p_moi text, p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_data jsonb; d record; v_r jsonb; v_dep jsonb; v_q integer := (p->>'qte')::integer;
BEGIN
  SELECT data INTO v_data FROM public.entreprises WHERE id = p->>'entreprise';
  IF v_data IS NULL OR v_data->>'type' IS DISTINCT FROM 'station-service' THEN RETURN jsonb_build_object('ok', false, 'raison', 'station_introuvable'); END IF;
  IF v_q IS NULL OR v_q < 1 OR v_q > 100 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  SELECT country, current_city, current_building, inventory INTO d FROM public.personnages_donnees WHERE name = p_moi FOR UPDATE;
  IF (d.country, d.current_city, d.current_building) IS DISTINCT FROM (v_data->>'country', v_data->>'city', v_data->>'buildingId') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF public.inventaire_place_restante(d.inventory) < v_q THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'requis', v_q); END IF;
  v_r := public.commerce_vendre_produit_interne(p_moi, p->>'entreprise',
           jsonb_build_array(jsonb_build_object('produit', 'bidon_carburant', 'qte', v_q)), 'comptoir', NULL, 0, 0, NULL, NULL);
  IF coalesce((v_r->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;
  v_dep := public.inventaire_deposer_interne(p_moi, jsonb_build_object('name', 'carburant', 'stackKey', 'carburant',
             'stackable', true, 'qty', v_q, 'desc', 'Bidons de carburant (1 bidon = 1 unité).'));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE OR (v_dep->>'qte')::integer IS DISTINCT FROM v_q THEN
    RAISE EXCEPTION 'carburant_acheter: bidons refuses %', v_dep; END IF;
  RETURN jsonb_build_object('ok', true, 'qte', v_q, 'total', v_r->'total') || public.vehicule_inventaire_reponse_interne(p_moi);
END $$;

