-- ORGANISATIONS, FIN DE LA DOUBLE AUTORITÉ, ÉTAPE B — PORTAGE 2/3 (Claude, 02/11/2026). Additive.
--
-- 1) greve_generale_synchroniser(gg) : les syndicats engagés dans une grève générale ne sont
--    plus réécrits par l'écran (y compris ceux des AUTRES chefs, lors de l'adoption ou de
--    l'effondrement). Leur état est le reflet de la ligne greves_generales, recopié ici :
--      consultation : l'initiateur est « actif » ; un syndicat qui a répondu porte sa réponse ;
--      active       : un syndicat qui a accepté est « actif » et rattaché ; les autres détachés ;
--      autre statut : tous détachés.
--    Seuls les syndicats du pays de la grève sont touchés, et jamais un syndicat rattaché à une
--    autre grève générale. Correctif au passage : à l'adoption, les syndicats acceptants sont
--    désormais rattachés (greveGeneraleEnCoursId) — sans cela, seul l'initiateur pouvait s'en retirer.
-- 2) club_supporters_adherer(requete, club, meneur) : cotisation (club_supporters_cotiser,
--    inchangée), création du club de supporters s'il n'existe pas et inscription du membre au
--    premier grade, en UNE transaction. Saison lue au championnat (ligne 2), comme la nuit.
BEGIN;

CREATE OR REPLACE FUNCTION public.greve_generale_synchroniser(p_gg text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $f$
DECLARE v_gg public.greves_generales; v_p jsonb; v_d jsonb; v_id text; v_statut text; v_n integer := 0;
BEGIN
  IF public.mon_personnage() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO v_gg FROM public.greves_generales WHERE id = p_gg;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'greve_generale_introuvable'); END IF;
  FOR v_p IN SELECT e FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_gg.participants) = 'array'
                                                     THEN v_gg.participants ELSE '[]'::jsonb END) e LOOP
    SELECT data::jsonb INTO v_d FROM public.organisations
     WHERE id = v_p->>'orgaId' AND data IS JSON OBJECT FOR UPDATE;
    CONTINUE WHEN v_d IS NULL OR v_d->>'type' IS DISTINCT FROM 'syndicale'
               OR coalesce(v_d->>'country_origine', v_d->>'country') IS DISTINCT FROM v_gg.country
               OR coalesce(v_d->>'greveGeneraleEnCoursId', p_gg) <> p_gg;
    v_id := v_d->>'greveGeneraleEnCoursId'; v_statut := v_d->>'greveGeneraleStatut';
    IF v_gg.statut = 'consultation' THEN
      IF v_p->>'orgaId' = v_gg.syndicat_initiateur_id THEN v_id := p_gg; v_statut := 'actif';
      ELSIF v_p->>'statut' IN ('accepte', 'refuse') THEN v_statut := v_p->>'statut'; END IF;
    ELSIF v_gg.statut = 'active' AND v_p->>'statut' = 'accepte' THEN v_id := p_gg; v_statut := 'actif';
    ELSE v_id := NULL; v_statut := NULL;
    END IF;
    IF v_id IS DISTINCT FROM v_d->>'greveGeneraleEnCoursId' OR v_statut IS DISTINCT FROM v_d->>'greveGeneraleStatut' THEN
      v_d := v_d || jsonb_build_object('greveGeneraleEnCoursId', v_id, 'greveGeneraleStatut', v_statut);
      UPDATE public.organisations SET data = v_d::text WHERE id = v_p->>'orgaId';
      v_n := v_n + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'statut', v_gg.statut, 'syndicats_mis_a_jour', v_n);
END
$f$;
REVOKE ALL ON FUNCTION public.greve_generale_synchroniser(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.greve_generale_synchroniser(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.club_supporters_adherer(p_requete text, p_club text, p_meneur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $f$
DECLARE c_grades constant jsonb := '{"republic":"Sympathisant","narco":"Simpatizante","soviet":"Sympathisant","khalija":"Sympathisant"}';
  v_moi text; v_club record; v_id text; v_d jsonb; v_r jsonb; v_meneur text; v_saison integer; v_jour integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT id, nom, pays, ville INTO v_club FROM public.clubs_football WHERE id = p_club;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'club_introuvable'); END IF;
  v_id := 'orga_supporters_' || v_club.pays || '_' || v_club.ville;
  PERFORM pg_advisory_xact_lock(hashtextextended('supporters:' || v_id, 0));
  SELECT data::jsonb INTO v_d FROM public.organisations WHERE id = v_id FOR UPDATE;
  IF v_d IS NOT NULL AND EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_d->'membres', '[]'::jsonb)) m WHERE m->>'nom' = v_moi) THEN
    -- Geste rejoué après succès : le reçu de cotisation répond ; sinon, déjà membre.
    v_r := public.caisse_collective_recu_interne(p_requete, v_moi, 'rejoindre_club_supporters', p_club);
    RETURN coalesce(v_r, jsonb_build_object('ok', false, 'raison', 'deja_membre'));
  END IF;
  v_r := public.club_supporters_cotiser(p_requete, p_club);
  IF coalesce((v_r->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;
  v_jour := coalesce(public.jour_de_jeu_pays(v_club.pays), 1);
  IF v_d IS NULL THEN
    -- Le meneur est le PNJ affiché au siège des supporters de la ville (donnée d'écran) ; un nom de
    -- joueur ou un texte quelconque est refusé au profit du libellé générique.
    v_meneur := btrim(coalesce(p_meneur, ''));
    IF v_meneur !~ '\(PNJ\)$' OR length(v_meneur) > 80
       OR EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_meneur) THEN
      v_meneur := 'Meneur des Supporters (PNJ)'; END IF;
    v_d := jsonb_build_object('id', v_id, 'type', 'supporters', 'nom', 'Club de Supporters — ' || v_club.nom,
      'desc', 'Les fidèles du ' || v_club.nom || '.', 'fondateur', v_meneur, 'chef', v_meneur, 'chefEstPnj', true,
      'country', v_club.pays, 'city', v_club.ville, 'country_origine', v_club.pays, 'creeLe', v_jour,
      'membres', '[]'::jsonb, 'demandesAdhesion', '[]'::jsonb,
      'bonusLocaux', jsonb_build_object('pop', 0, 'inf', 0, 'dis', 0), 'caisse', 0, 'influence', 50,
      'election', NULL, 'visible', true);
    INSERT INTO public.organisations (id, country_origine, data) VALUES (v_id, v_club.pays, v_d::text);
  END IF;
  SELECT coalesce(nullif(data::jsonb->>'numero', '')::integer, 1) INTO v_saison FROM public.championnat WHERE id = 2;
  v_d := jsonb_set(v_d, '{membres}', coalesce(v_d->'membres', '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'nom', v_moi, 'grade', coalesce(c_grades->>v_club.pays, 'Sympathisant'), 'gradeIdx', 0, 'rejointLe', v_jour,
    'derniereCotisationSaison', coalesce(v_saison, 1))));
  UPDATE public.organisations SET data = v_d::text WHERE id = v_id;
  RETURN v_r || jsonb_build_object('organisation', v_id, 'grade', coalesce(c_grades->>v_club.pays, 'Sympathisant'));
END
$f$;
REVOKE ALL ON FUNCTION public.club_supporters_adherer(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.club_supporters_adherer(text, text, text) TO authenticated;

COMMIT;
