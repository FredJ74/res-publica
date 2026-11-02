-- BLOCUS SYNDICAL : PARTICIPANTS, COÛT ET UNE TENTATIVE PAR JOUR (décisions de Fred, 02/11/2026,
-- GAME-DESIGN-BLOCUS.md).
--
-- Participants : l'organisateur (Secrétaire Général ou Adjoint), les PJ de son groupe membres du même
-- syndicat et présents avec lui (même pièce), et les militants PNJ mobilisés. Minimum : 2 participants,
-- PJ et PNJ confondus. Chaque participant compte comme un militant dans les chances et l'intensité.
-- Coût : 2 PA par PJ participant, tout ou rien (un PJ sans ses 2 PA → blocus refusé, personne ne paie).
-- Une seule tentative par jour de jeu et par syndicat (SG et Adjoint la partagent), réussie ou non.
-- L'organisateur doit être chef de son groupe s'il en a un.

CREATE OR REPLACE FUNCTION public.blocus_syndical_organiser(p_organisation text, p_militants integer, p_revendication text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa constant integer := 2;
  v_moi text; p public.personnages_donnees%ROWTYPE; v_pays text; v_data jsonb; v_jour integer;
  v_militants integer; v_mob integer; v_pj text[]; v_sans_pa text[]; v_n integer;
  v_puissance integer; v_taux integer; v_intensite integer; v_jet integer; v_ms bigint;
  v_rev text; v_blocus jsonb; v_ailleurs boolean; v_pa_moi integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  v_pays := coalesce(p.country, 'republic');
  IF p.current_building IS NULL OR p.current_city IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
                  WHERE pays = v_pays AND ville = p.current_city AND batiment = p.current_building) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'batiment_inconnu'); END IF;
  IF EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE membre = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chef_de_groupe_requis'); END IF;

  SELECT CASE WHEN left(btrim(coalesce(o.data, '')), 1) = '{' THEN o.data::jsonb END INTO v_data
    FROM public.organisations o WHERE o.id = p_organisation FOR UPDATE;
  IF v_data IS NULL OR coalesce(v_data->>'type', '') <> 'syndicale' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'syndicat_introuvable'); END IF;
  IF NOT public.blocus_syndicat_dirigeant_interne(v_moi, v_data) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_secretaire_general'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  IF (v_data->>'blocusDernierEssaiJour') ~ '^[0-9]+$' AND (v_data->>'blocusDernierEssaiJour')::int = v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tentative_du_jour_deja_faite', 'jour', v_jour); END IF;

  -- PJ participants : moi, et les PJ de mon groupe membres du syndicat, dans la même pièce.
  SELECT array_agg(d.name ORDER BY d.name <> v_moi, d.name) INTO v_pj
    FROM public.personnages_donnees d
   WHERE (d.name = v_moi OR d.name IN (SELECT membre FROM public.groupes_pj_adhesions WHERE chef = v_moi))
     AND d.current_city = p.current_city AND d.current_building = p.current_building
     AND d.current_room IS NOT DISTINCT FROM p.current_room
     AND (d.name = v_moi OR EXISTS (SELECT 1 FROM jsonb_array_elements(
            CASE WHEN jsonb_typeof(v_data->'membres') = 'array' THEN v_data->'membres' ELSE '[]'::jsonb END) m
          WHERE m->>'nom' = d.name AND coalesce(m->>'estPnj', 'false') <> 'true'));

  SELECT count(*) INTO v_militants
    FROM public.pnj_militants_metier mm JOIN public.pnj_membres pm ON pm.id = mm.pnj_id
   WHERE mm.organisation_id = p_organisation AND pm.statut = 'actif' AND pm.famille = 'militant';
  v_mob := coalesce(p_militants, v_militants);
  IF v_mob < 0 OR v_mob > v_militants THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nombre_militants_invalide', 'militants', v_militants); END IF;
  v_n := coalesce(array_length(v_pj, 1), 0) + v_mob;
  IF v_n < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'participants_insuffisants', 'participants', v_n,
      'pj', coalesce(array_length(v_pj, 1), 0), 'militants', v_militants); END IF;

  PERFORM 1 FROM public.batiments_etat
   WHERE id = v_pays || '_' || p.current_city || '_' || p.current_building FOR UPDATE;
  IF public.blocus_actif_interne(v_pays, p.current_city, p.current_building) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_bloque'); END IF;

  -- 2 PA par PJ participant, tout ou rien.
  PERFORM 1 FROM public.personnages_donnees WHERE name = ANY (v_pj) ORDER BY name FOR UPDATE;
  SELECT array_agg(name ORDER BY name) INTO v_sans_pa FROM public.personnages_donnees
   WHERE name = ANY (v_pj) AND coalesce(pa, 0) < c_pa;
  IF v_sans_pa IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants_participants', 'sans_pa', to_jsonb(v_sans_pa),
      'pa_par_participant', c_pa); END IF;
  UPDATE public.personnages_donnees SET pa = pa - c_pa, updated_at = clock_timestamp() WHERE name = ANY (v_pj);
  SELECT pa INTO v_pa_moi FROM public.personnages_donnees WHERE name = v_moi;

  -- La tentative du jour est consommée, réussie ou non.
  v_data := jsonb_set(v_data, '{blocusDernierEssaiJour}', to_jsonb(v_jour));

  SELECT EXISTS (SELECT 1 FROM public.batiments_etat e
                  WHERE e.country = v_pays
                    AND public.blocus_actif_interne(e.country, e.city, e.building_id)->>'syndicatId' = p_organisation)
    INTO v_ailleurs;
  v_puissance := greatest(0, least(100, v_militants * 3 + CASE WHEN v_ailleurs THEN 15 ELSE 0 END
                 + coalesce(nullif(v_data->>'blocusReussis', '')::int, 0) * 5
                 + coalesce(nullif(v_data->>'repressionsSubies', '')::int, 0) * 8));
  v_taux := least(90, 10 + 6 * v_n + round(v_puissance / 5.0)::int);
  v_intensite := least(90, 10 + 6 * v_n);
  v_jet := floor(random() * 100)::int + 1;

  IF v_jet > v_taux THEN
    UPDATE public.organisations SET data = v_data::text WHERE id = p_organisation;
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_jet,
      'participants', to_jsonb(v_pj), 'militants', v_mob,
      'paiement', jsonb_build_object('ok', true, 'pa', v_pa_moi, 'pa_preleves', c_pa));
  END IF;

  v_rev := left(btrim(coalesce(p_revendication, '')), 280);
  IF v_rev = '' THEN v_rev := 'Revendications non précisées.'; END IF;
  v_ms := floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint;
  v_blocus := jsonb_build_object('syndicatId', p_organisation,
    'syndicatNom', coalesce(v_data->>'nom', 'Syndicat'), 'revendication', v_rev,
    'nbMilitants', v_mob, 'nbPj', coalesce(array_length(v_pj, 1), 0), 'participantsPj', to_jsonb(v_pj),
    'intensite', v_intensite, 'leaderActuel', v_moi,
    'lanceLe', v_ms, 'dernierRenouvellementTimestamp', v_ms);
  PERFORM public.blocus_ecrire_interne(v_pays, p.current_city, p.current_building, v_blocus);

  UPDATE public.organisations
     SET data = jsonb_set(v_data, '{blocusReussis}',
                  to_jsonb(coalesce(nullif(v_data->>'blocusReussis', '')::int, 0) + 1))::text
   WHERE id = p_organisation;

  RETURN jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_jet,
    'intensite', v_intensite, 'blocus', v_blocus, 'participants', to_jsonb(v_pj), 'militants', v_mob,
    'city', p.current_city, 'buildingId', p.current_building,
    'paiement', jsonb_build_object('ok', true, 'pa', v_pa_moi, 'pa_preleves', c_pa));
END $function$;

REVOKE ALL ON FUNCTION public.blocus_syndical_organiser(text,integer,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.blocus_syndical_organiser(text,integer,text) TO authenticated, service_role;
