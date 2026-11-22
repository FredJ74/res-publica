-- LOT DE KRASNOV, POINT 9 : ACTIONS DE PIÈCE, TOUS LES LIEUX (GAME-DESIGN-KRASNOV-LOT-20261120.md ; étape I de la mission
-- du 22/11/2026, nuit).
--   * « Inspecter la pièce » : un seul ordre à 1 PA qui réunit « Fouiller les lieux » (caméras cachées, 2 PA jusqu'ici) et
--     « Débusquer quelqu'un de caché » (1 PA). Mêmes taux qu'avant (fouiller_lieux, crim_fouiller_cachettes, inchangées) ;
--     le débusqué reçoit la même ligne de journal (crim_evenement_interne 'debusque', #1156). Dans une vue de rue : caméras
--     seulement (personne ne se cache dans la rue).
--   * « Désinstaller du matériel » remplace « Emporter ce qu'il y a ici » : liste du matériel installé, 2 PA par matériel ;
--     l'objet tombe au sol (objets_abandonnes), n'est plus lié à la pièce et se ramasse sans PA (objet_abandonne_ramasser).
--     Légal chez soi et dans le local d'une organisation dont on est membre (local_jouissance_interne), ou pour son propre
--     matériel ; ailleurs, acte illégal soumis aux règles communes du vol (crim_resoudre_interne, comme le cambriolage :
--     jet contre les présents, trace, plainte possible). Après une bagarre gagnée, le moteur commun livre l'objet en main.
-- Fonctions nouvelles uniquement : aucune fonction commune modifiée. Le goulag n'est pas touché. Idempotente.
BEGIN;

CREATE OR REPLACE FUNCTION public.inspecter_piece()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); l record; d record; v_couin boolean; v_mod integer; v_taux integer;
        c public.cameras_posees; v_trouvees jsonb := '[]'::jsonb; v_per numeric; v_force boolean; k record; v_t integer;
        v_trouves jsonb := '[]'::jsonb; v_masque boolean; v_tresor jsonb := '{}'::jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT name, pa, stats, inventory, est_emprisonne, country, current_city, current_building, current_room INTO d
    FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(d.est_emprisonne), 'null') <> 'null' AND d.est_emprisonne <> 'false'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  SELECT * INTO l FROM public.surveillance_lieu_interne(a);
  IF l.batiment IS NULL OR l.piece IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'lieu_invalide'); END IF;
  IF coalesce(d.pa, 0) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  UPDATE public.personnages_donnees SET pa = pa - 1 WHERE name = a;

  -- Caméras cachées (mêmes taux que fouiller_lieux : 15 % à mains nues, 75 % avec le Couinator, ± la PER).
  v_couin := EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) o
                      WHERE o->>'generique_id' = 'couinator-3000');
  v_mod := coalesce(CASE WHEN coalesce(d.stats->>'PER', '') ~ '^-?[0-9]+(\.[0-9]+)?$' THEN floor((d.stats->>'PER')::numeric)::integer END, 10) - 10;
  v_taux := greatest(1, least(99, CASE WHEN v_couin THEN 75 ELSE 15 END + v_mod));
  FOR c IN SELECT * FROM public.cameras_posees
            WHERE pays = l.pays AND ville = l.ville AND batiment = l.batiment AND piece = l.piece
              AND NOT public.equipement_a_moi_interne(proprietaire, a) ORDER BY posee_le FOR UPDATE LOOP
    IF floor(random() * 100)::integer + 1 <= v_taux THEN
      INSERT INTO public.cameras_decouvertes (acteur, camera_id) VALUES (a, c.id)
      ON CONFLICT (acteur, camera_id) DO UPDATE SET trouvee_le = now();
      v_trouvees := v_trouvees || jsonb_build_array(jsonb_build_object('id', c.id));
    END IF;
  END LOOP;

  -- Personnes cachées, dans une pièce seulement (mêmes taux que crim_fouiller_cachettes).
  v_force := public.crim_force_ordre_interne(a);
  IF coalesce(d.current_building, '') <> '' AND coalesce(d.current_room, '') <> '' THEN
    v_per := public.crim_stat_interne(a, 'PER', 10);
    FOR k IN SELECT x.personnage FROM public.caches_pj x JOIN public.personnages_donnees p ON p.name = x.personnage
              WHERE x.personnage <> a AND p.country = d.country AND p.current_city = d.current_city
                AND p.current_building = d.current_building AND p.current_room = d.current_room
                AND x.pays = p.country AND x.ville = p.current_city AND x.batiment = p.current_building AND x.piece = p.current_room
              ORDER BY x.le FOR UPDATE OF x LOOP
      v_t := public.crim_fouiller_taux_interne(v_per, public.crim_stat_interne(k.personnage, 'dis', 50),
                                               public.crim_objet_porte_interne(k.personnage, 'tenue_ninja'), v_force);
      IF floor(random() * 100)::integer + 1 <= v_t THEN
        PERFORM public.crim_debusquer_interne(k.personnage, 'fouille');
        v_masque := public.crim_masque_interne(k.personnage);
        v_trouves := v_trouves || jsonb_build_array(CASE WHEN v_masque THEN jsonb_build_object('masque', true)
                                                         ELSE jsonb_build_object('masque', false, 'nom', k.personnage) END);
        PERFORM public.crim_evenement_interne(k.personnage, 'debusque',
          CASE WHEN public.crim_masque_interne(a) THEN jsonb_build_object('par_masque', true) ELSE jsonb_build_object('par', a) END
            || jsonb_build_object('vous_masque', v_masque));
      END IF;
    END LOOP;
  END IF;

  -- Énigme du trésor des Tsars : la fouille du musée présidentiel peut toujours joindre le livre.
  v_tresor := coalesce(public.tresor_tsars_fouille_interne(a, l.batiment, l.piece), '{}'::jsonb);
  RETURN v_tresor || jsonb_build_object('ok', true, 'couinator', v_couin, 'taux', v_taux, 'trouvees', v_trouvees,
    'nb', jsonb_array_length(v_trouvees), 'trouves', v_trouves, 'nb_personnes', jsonb_array_length(v_trouves),
    'piece', coalesce(d.current_building, '') <> '' AND coalesce(d.current_room, '') <> '',
    'force_ordre', v_force, 'pa', d.pa - 1);
END $$;

-- Matériel installé dans la pièce, avec ce que coûterait sa désinstallation (légale ou non).
CREATE OR REPLACE FUNCTION public.desinstaller_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record; v_chez_soi boolean;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, pa INTO d FROM public.personnages_donnees WHERE name = a;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  v_chez_soi := public.local_jouissance_interne(a, d.country, d.current_city, d.current_building, d.current_room);
  RETURN jsonb_build_object('ok', true, 'chez_soi', v_chez_soi, 'pa', coalesce(d.pa, 0), 'cout_pa', 2,
    'materiel', coalesce((SELECT jsonb_agg(jsonb_build_object('id', e.id, 'generique', e.generique_id,
        'nom', coalesce(e.objet ->> 'name', e.generique_id),
        'a_moi', public.equipement_a_moi_interne(e.proprietaire, a),
        'legal', v_chez_soi OR public.equipement_a_moi_interne(e.proprietaire, a),
        'ferme_a_cle', EXISTS (SELECT 1 FROM public.serrures x WHERE x.statut = 'posee' AND x.cible = 'armoire' AND x.fermee
                                 AND x.armoire_objet = e.objet ->> 'id')) ORDER BY e.installe_le)
      FROM public.equipements_installes e
     WHERE (e.pays, e.ville, e.batiment, e.piece) = (d.country, d.current_city, d.current_building, d.current_room)
       AND (e.generique_id <> 'armoire_souvenirs' OR v_chez_soi OR public.equipement_a_moi_interne(e.proprietaire, a))), '[]'::jsonb));
END $$;

-- Pose l'objet d'un équipement au sol de sa pièce et retire l'équipement (renvoie l'identifiant de l'objet au sol).
CREATE OR REPLACE FUNCTION public.desinstaller_au_sol_interne(p_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE e public.equipements_installes; v_sol text;
BEGIN
  SELECT * INTO e FROM public.equipements_installes WHERE id = p_id FOR UPDATE;
  IF e.id IS NULL THEN RETURN NULL; END IF;
  v_sol := 'sol-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.objets_abandonnes (id, country, city, building_id, room_id, data)
  VALUES (v_sol, e.pays, e.ville, e.batiment, e.piece, (e.objet - 'porte_par')::text);
  DELETE FROM public.equipements_installes WHERE id = e.id;
  RETURN v_sol;
END $$;

CREATE OR REPLACE FUNCTION public.desinstaller_materiel(p_requete uuid, p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('id', p_id); v jsonb; m record; e public.equipements_installes;
        v_legal boolean; v_sol text; v_ent text; v_plan jsonb; v_paie jsonb; t jsonb; r jsonb; v_nom text; v_dis numeric; v_per numeric;
        v_proprio text; v_jets jsonb; v_out jsonb; f public.crim_affaires%ROWTYPE;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'equipement_introuvable'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'desinstaller_materiel', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT name, public.crim_carriere_interne(name) AS career, country, current_city, current_building, current_room, est_emprisonne, pa INTO m
    FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(m.est_emprisonne), 'null') <> 'null' AND m.est_emprisonne <> 'false'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  IF m.current_building IS NULL OR m.current_room IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  SELECT * INTO e FROM public.equipements_installes WHERE id = p_id FOR UPDATE;
  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'equipement_introuvable'); END IF;
  IF (e.pays, e.ville, e.batiment, e.piece) IS DISTINCT FROM (m.country, m.current_city, m.current_building, m.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF EXISTS (SELECT 1 FROM public.serrures x WHERE x.statut = 'posee' AND x.cible = 'armoire' AND x.fermee AND x.armoire_objet = e.objet ->> 'id') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'armoire_fermee_a_cle'); END IF;
  v_legal := public.local_jouissance_interne(a, m.country, m.current_city, m.current_building, m.current_room)
             OR public.equipement_a_moi_interne(e.proprietaire, a);
  IF e.generique_id = 'armoire_souvenirs' AND NOT v_legal THEN RETURN jsonb_build_object('ok', false, 'raison', 'equipement_introuvable'); END IF;
  IF coalesce(m.pa, 0) < 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', 2, 'pa', coalesce(m.pa, 0)); END IF;
  v_nom := coalesce(e.objet ->> 'name', e.generique_id, 'du matériel');

  IF v_legal THEN
    UPDATE public.personnages_donnees SET pa = pa - 2 WHERE name = a;
    v_sol := public.desinstaller_au_sol_interne(e.id);
    RETURN public.achat_requete_clore_interne(a, p_requete, 'desinstaller_materiel', prm,
      jsonb_build_object('ok', true, 'legal', true, 'issue', 'reussite', 'au_sol', true, 'objet_sol', v_sol, 'nom', v_nom,
        'pa', (SELECT pa FROM public.personnages_donnees WHERE name = a)));
  END IF;

  -- Ailleurs : vol, règles communes (moteur du cambriolage, butin « matériel »).
  v_jets := CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END;
  v_ent := public.commerce_de_la_piece_interne(a);
  v_plan := jsonb_build_object('genre', 'materiel', 'equipement', e.id, 'nom', v_nom, 'generique', e.generique_id,
                               'proprietaire', e.proprietaire, 'au_sol', true);
  v_paie := public.payer_ordre(a, 'cambrioler', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  t := public.crim_temoin_interne(a, v_ent);
  IF t IS NULL THEN
    r := public.crim_resoudre_interne('cambrioler', a, NULL, jsonb_build_object(
      'reussite_auto', true, 'detection_base', public.crim_param_interne('cambriolage_detection', 30),
      'detection_min', public.crim_param_interne('detection_min', 5),
      'acte_peine_reussite', 'vol', 'acte_peine_echec', 'vol', 'type_recherche', 'delit_mineur',
      'indices', jsonb_build_object('butin', 'materiel'), 'butin', 'materiel', 'butin_plan', v_plan, 'lieu_vide', true, 'jets', v_jets));
    v_proprio := public.crim_proprietaire_pj_interne(e.proprietaire);
    UPDATE public.crim_affaires SET cible = coalesce(v_proprio, e.proprietaire), maj_le = now() WHERE id = (r ->> 'affaire')::bigint;
  ELSE
    v_dis := public.crim_stat_interne(a, 'dis', 50);
    v_per := public.crim_per_groupe_interne(t);
    r := public.crim_resoudre_interne('cambrioler', a, CASE WHEN (t ->> 'pj')::boolean THEN t ->> 'nom' ELSE t ->> 'pnj_id' END, jsonb_build_object(
      'taux', public.crim_voler_taux_interne('hasard', v_dis, v_per, m.career),
      'min', public.crim_param_interne('vol_min', 5), 'max', public.crim_param_interne('vol_max', 85),
      'critique_reussite_part', public.crim_param_interne('vol_critique_reussite_part', 5), 'critique_sans_detection', true,
      'combat', true, 'per_victime', (t ->> 'per')::numeric, 'remarque_echec', public.crim_voler_remarque_interne(v_per, v_dis),
      'detection_base', public.crim_param_interne('cambriolage_detection', 30), 'detection_min', public.crim_param_interne('detection_min', 5),
      'acte_peine_reussite', 'vol', 'acte_peine_echec', 'vol', 'type_recherche', 'delit_mineur', 'cible_info', t,
      'titre_reussite', 'Vol', 'titre_echec', 'Tentative de vol',
      'msg_reussite', '{Auteur} a démonté ' || v_nom || ' sous vos yeux.',
      'msg_echec', '{Auteur} a tenté de démonter ' || v_nom || ' sous vos yeux.',
      'msg_employeur_reussite', '{Auteur} a démonté ' || v_nom || ' sous les yeux de votre employé(e) {cible}. Une plainte a été déposée.',
      'msg_employeur_echec', '{Auteur} a tenté de démonter ' || v_nom || ' sous les yeux de votre employé(e) {cible}. Une plainte a été déposée.',
      'motif_plainte', 'Vol de matériel dans votre local',
      'indices', jsonb_build_object('butin', 'materiel'), 'butin', 'materiel', 'butin_plan', v_plan,
      'temoin_comptoir', coalesce((t ->> 'comptoir')::boolean, false), 'jets', v_jets));
  END IF;
  IF r ->> 'issue' = 'reussite' THEN
    v_sol := public.desinstaller_au_sol_interne(e.id);
    SELECT * INTO f FROM public.crim_affaires WHERE id = (r ->> 'affaire')::bigint FOR UPDATE;
    IF f.id IS NOT NULL THEN
      UPDATE public.crim_affaires SET details = details || jsonb_build_object('livre', v_sol IS NOT NULL, 'butin_livre', v_nom || ' (au sol)'),
             maj_le = now() WHERE id = f.id;
      v_proprio := public.crim_proprietaire_pj_interne(e.proprietaire);
      IF v_sol IS NOT NULL AND v_proprio IS NOT NULL AND v_proprio <> a AND NOT (f.cible IS NOT DISTINCT FROM v_proprio AND f.remarque) THEN
        INSERT INTO public.crim_constats (destinataire, pays, ville, batiment, piece, entreprise, titre, corps, affaire)
        VALUES (v_proprio, f.pays, f.ville, f.batiment, f.piece, v_ent, 'Vol constaté',
          'En revenant, vous constatez que votre matériel a été démonté : ' || v_nom || ' (' || coalesce(f.piece, f.batiment) || '). Vous pouvez porter plainte pour vol.',
          f.id);
      END IF;
    END IF;
    IF v_sol IS NOT NULL THEN PERFORM public.crime_trace_rumeur_interne(a, 'vol', coalesce(public.crim_proprietaire_pj_interne(e.proprietaire), e.proprietaire)); END IF;
  ELSIF r ->> 'issue' = 'combat' THEN
    r := public.crim_combat_ouvrir_interne(a, r, t, 'mains', p_requete);
  END IF;
  v_out := jsonb_build_object('ok', true, 'legal', false, 'nom', v_nom, 'paie', v_paie, 'lieu_vide', t IS NULL,
             'au_sol', v_sol IS NOT NULL, 'objet_sol', v_sol)
    || (r - 'notifie' - 'affaire' - 'garde')
    || (SELECT jsonb_build_object('pa', pa, 'moral', moral, 'recherche', recherche) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'desinstaller_materiel', prm, v_out);
END $$;

REVOKE ALL ON FUNCTION public.desinstaller_au_sol_interne(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.inspecter_piece(), public.desinstaller_lire(), public.desinstaller_materiel(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inspecter_piece(), public.desinstaller_lire(), public.desinstaller_materiel(uuid, uuid) TO authenticated;

DO $$ BEGIN
  IF to_regprocedure('public.inspecter_piece()') IS NULL OR to_regprocedure('public.desinstaller_materiel(uuid,uuid)') IS NULL
     OR to_regprocedure('public.desinstaller_lire()') IS NULL THEN
    RAISE EXCEPTION 'pieces_inspecter_desinstaller : contrôle structurel en échec';
  END IF;
END $$;
COMMIT;
