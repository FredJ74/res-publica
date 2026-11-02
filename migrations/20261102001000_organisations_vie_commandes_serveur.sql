-- ORGANISATIONS, FIN DE LA DOUBLE AUTORITÉ, ÉTAPE B — PORTAGE 1/3 (Claude, 02/11/2026).
-- Additive : ne ferme rien. Inventaire : outils/audits/ORGANISATIONS-ECRITURES-20261031.md
--
-- Une porte serveur pour les chemins qui écrivaient encore l'organisation par la sauvegarde
-- générale de l'écran : fondation dans un local loué, syndicat des dockers de PSM, grève
-- ordinaire (lancer, terminer). Mêmes règles qu'à l'écran, désormais tenues ici :
--   * fondation : type ouvert aux locaux loués, une seule fondation par type et par fondateur,
--     prérequis POP / INF / DIS / argent du type, présence dans un local loué en son nom où
--     les organisations sont admises, local libre, grade de fondateur = grade le plus haut ;
--   * grève : chef seulement, au moins 5 membres (GREVE_MEMBRES_MIN), une seule à la fois,
--     1 PA payé par payer_ordre dans la même transaction (tarif 'greve_lancer' du miroir).
-- Reçus dans organisation_commandes_recus : un geste rejoué ne s'exécute jamais deux fois.
--
-- Référentiel des types : organisation_vie_referentiel() (20261102000900).

BEGIN;

CREATE OR REPLACE FUNCTION public.organisation_vie_commande(p_requete text, p_organisation text, p_action text, p_parametres jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $f$
DECLARE v_moi text; v_rec public.organisation_commandes_recus; v_cmd jsonb; v_res jsonb; v_d jsonb;
  v_perso record; v_def jsonb; v_grades jsonb; v_type text; v_nom text; v_id text; v_jour integer;
  v_cle text; v_seuil numeric; v_val numeric; v_paie jsonb; v_greve jsonb; v_txt text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^orgcmd-[A-Za-z0-9-]{6,80}$' OR p_action IS NULL
     OR p_parametres IS NULL OR jsonb_typeof(p_parametres) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'commande_invalide'); END IF;
  IF p_organisation IS NOT NULL THEN
    PERFORM 1 FROM public.organisations WHERE id = p_organisation FOR UPDATE;
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('orgcmd:' || p_requete, 0));
  v_cmd := jsonb_build_object('action', p_action, 'parametres', p_parametres);
  SELECT * INTO v_rec FROM public.organisation_commandes_recus WHERE requete = p_requete;
  IF FOUND THEN
    IF v_rec.acteur <> v_moi OR v_rec.commande <> v_cmd THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'requete_reutilisee'); END IF;
    RETURN v_rec.resultat || jsonb_build_object('rejeu', true);
  END IF;
  SELECT country, current_city, current_building, current_room, arg,
         CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END AS res
    INTO v_perso FROM public.personnages_donnees WHERE name = v_moi;
  IF v_perso.country IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_jour := coalesce(public.jour_de_jeu_pays(v_perso.country), 1);

  IF p_action = 'fonder' THEN
    IF p_parametres - ARRAY['type', 'nom', 'desc', 'corpsMetier'] <> '{}'::jsonb THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'champs_interdits'); END IF;
    v_type := p_parametres->>'type';
    v_def := public.organisation_vie_referentiel() -> v_type;
    IF v_def IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'type_non_fondable_ici'); END IF;
    v_nom := btrim(coalesce(p_parametres->>'nom', ''));
    IF length(v_nom) < 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_requis'); END IF;
    IF length(v_nom) > 40 OR length(coalesce(p_parametres->>'desc', '')) > 200 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'texte_trop_long'); END IF;
    IF coalesce(p_parametres->>'corpsMetier', '') NOT IN ('', 'police')
       OR (v_type <> 'syndicale' AND coalesce(p_parametres->>'corpsMetier', '') <> '') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'corps_metier_invalide'); END IF;
    FOR v_cle, v_seuil IN SELECT key, value::numeric FROM jsonb_each_text(v_def->'requis') LOOP
      v_val := CASE WHEN v_cle = 'arg' THEN coalesce(v_perso.arg, 0)
                    ELSE coalesce(CASE WHEN jsonb_typeof(v_perso.res->v_cle) = 'number' THEN (v_perso.res->>v_cle)::numeric END, 0) END;
      IF v_val < v_seuil THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'prerequis_insuffisant', 'jauge', v_cle, 'requis', v_seuil, 'actuel', v_val);
      END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM public.organisations o WHERE o.data IS JSON OBJECT
                AND o.data::jsonb->>'type' = v_type AND o.data::jsonb->>'fondateur' = v_moi
                AND coalesce(o.data::jsonb->>'country', o.country_origine) = v_perso.country) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'type_deja_fonde'); END IF;
    IF NOT EXISTS (SELECT 1 FROM public.locations_actives l
                    WHERE l.country = v_perso.country AND l.data->>'locataire' = v_moi
                      AND l.data->>'buildingId' = v_perso.current_building AND l.data->>'roomId' = v_perso.current_room
                      AND coalesce(l.data->>'city', 'capitale') = coalesce(v_perso.current_city, 'capitale')
                      AND coalesce(l.data->>'orgaAutorisee', 'true') <> 'false'
                      AND coalesce(l.data->>'logementSocial', 'false') <> 'true') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'local_loue_requis'); END IF;
    IF EXISTS (SELECT 1 FROM public.organisations o WHERE o.data IS JSON OBJECT
                AND o.data::jsonb->>'localId' = v_perso.current_building || ':' || v_perso.current_room) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'local_deja_occupe'); END IF;
    v_grades := coalesce(v_def->'grades'->v_perso.country, v_def->'grades'->'republic');
    v_id := 'orga_' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint;
    v_d := jsonb_build_object('id', v_id, 'type', v_type, 'nom', v_nom, 'desc', btrim(coalesce(p_parametres->>'desc', '')),
      'fondateur', v_moi, 'chef', v_moi, 'country', v_perso.country, 'country_origine', v_perso.country,
      'creeLe', v_jour,
      'membres', jsonb_build_array(jsonb_build_object('nom', v_moi, 'grade', v_grades->>(jsonb_array_length(v_grades) - 1),
                   'gradeIdx', jsonb_array_length(v_grades) - 1, 'rejointLe', v_jour)),
      'demandesAdhesion', '[]'::jsonb, 'bonusLocaux', jsonb_build_object('pop', 0, 'inf', 0, 'dis', 0),
      'caisse', 0, 'influence', 50, 'localId', v_perso.current_building || ':' || v_perso.current_room,
      'visible', NOT (v_def->>'secret')::boolean);
    IF coalesce(p_parametres->>'corpsMetier', '') <> '' THEN v_d := v_d || jsonb_build_object('corpsMetier', p_parametres->>'corpsMetier'); END IF;
    INSERT INTO public.organisations (id, country_origine, data) VALUES (v_id, v_perso.country, v_d::text);
    p_organisation := v_id;

  ELSIF p_action = 'dockers_assurer' THEN
    IF p_parametres <> '{}'::jsonb OR p_organisation IS DISTINCT FROM 'orga_syndicat_dockers_republic_ville_a' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'syndicat_inconnu'); END IF;
    SELECT data::jsonb INTO v_d FROM public.organisations WHERE id = p_organisation;
    IF v_d IS NULL THEN
      v_d := jsonb_build_object('id', p_organisation, 'type', 'syndicale',
        'nom', 'Syndicat des Dockers de Port-Sainte-Marie',
        'desc', 'Le syndicat des dockers du Port industriel de Port-Sainte-Marie.',
        'fondateur', 'Étienne Dantafasse (PNJ)', 'chef', 'Étienne Dantafasse (PNJ)', 'chefEstPnj', true,
        'country', 'republic', 'city', 'ville_a', 'country_origine', 'republic', 'creeLe', v_jour,
        'membres', '[]'::jsonb, 'demandesAdhesion', '[]'::jsonb,
        'bonusLocaux', jsonb_build_object('pop', 0, 'inf', 0, 'dis', 0), 'caisse', 0, 'influence', 50,
        'election', NULL, 'visible', true);
      INSERT INTO public.organisations (id, country_origine, data) VALUES (p_organisation, 'republic', v_d::text)
      ON CONFLICT (id) DO NOTHING;
    END IF;
    -- Rien à rejouer : acte idempotent, pas de reçu (l'appel suit chaque visite du port).
    RETURN jsonb_build_object('ok', true, 'organisation', p_organisation);

  ELSIF p_action IN ('greve_lancer', 'greve_terminer') THEN
    SELECT data::jsonb INTO v_d FROM public.organisations WHERE id = p_organisation;
    IF v_d IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'organisation_absente'); END IF;
    IF v_d->>'type' IS DISTINCT FROM 'syndicale' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_aux_syndicats'); END IF;
    IF v_d->>'chef' IS DISTINCT FROM v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_chef'); END IF;
    IF p_action = 'greve_lancer' THEN
      IF p_parametres - ARRAY['type', 'cibleValue', 'cibleLabel', 'revendications'] <> '{}'::jsonb THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'champs_interdits'); END IF;
      v_txt := btrim(coalesce(p_parametres->>'revendications', ''));
      IF coalesce(btrim(p_parametres->>'cibleValue'), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_requise'); END IF;
      IF v_txt = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'revendications_requises'); END IF;
      IF length(v_txt) > 2000 OR length(coalesce(p_parametres->>'cibleLabel', '')) > 120
         OR length(coalesce(p_parametres->>'type', '')) > 40 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'texte_trop_long'); END IF;
      IF jsonb_array_length(CASE WHEN jsonb_typeof(v_d->'membres') = 'array' THEN v_d->'membres' ELSE '[]'::jsonb END) < 5 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'syndicat_trop_petit', 'minimum', 5); END IF;
      IF coalesce((v_d->'greve'->>'actif')::boolean, false) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'greve_deja_en_cours'); END IF;
      v_paie := public.payer_ordre(v_moi, 'greve_lancer', 1, 0);
      IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN
        RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie); END IF;
      v_greve := jsonb_build_object('actif', true, 'type', p_parametres->>'type',
        'cibleValue', p_parametres->>'cibleValue', 'cibleLabel', coalesce(p_parametres->>'cibleLabel', p_parametres->>'cibleValue'),
        'revendications', v_txt, 'dateDebut', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
        'joursActifs', 0, 'derniereApplicationJour', NULL);
      v_d := jsonb_set(v_d, '{greve}', v_greve);
    ELSE
      IF p_parametres <> '{}'::jsonb THEN RETURN jsonb_build_object('ok', false, 'raison', 'champs_interdits'); END IF;
      v_greve := v_d->'greve';
      IF NOT coalesce((v_greve->>'actif')::boolean, false) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'aucune_greve'); END IF;
      v_d := jsonb_set(v_d, '{greve}', 'null'::jsonb);
    END IF;
    UPDATE public.organisations SET data = v_d::text WHERE id = p_organisation;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue');
  END IF;

  v_res := jsonb_build_object('ok', true, 'organisation', p_organisation, 'action', p_action);
  IF v_greve IS NOT NULL THEN v_res := v_res || jsonb_build_object('greve', v_greve); END IF;
  IF v_paie IS NOT NULL THEN v_res := v_res || jsonb_build_object('paiement', v_paie); END IF;
  INSERT INTO public.organisation_commandes_recus (requete, acteur, organisation, commande, resultat)
  VALUES (p_requete, v_moi, p_organisation, v_cmd, v_res);
  RETURN v_res;
END
$f$;
REVOKE ALL ON FUNCTION public.organisation_vie_commande(text, text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.organisation_vie_commande(text, text, text, jsonb) TO authenticated;

COMMIT;
