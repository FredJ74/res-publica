-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine militaire -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- militaire_terminal_manger(text,text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_terminal_manger(p_requete text, p_matricules text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_gain constant integer := 1;
  c_pa_max constant integer := 12;
  c_max_jour constant integer := 2;
  g record; v_deja record; v_jour text; r record; v_res jsonb;
  v_avec integer := 0; v_sans integer := 0; v_refus jsonb := '[]'::jsonb;
  v_ids text[] := '{}'; v_mats text[] := '{}'; v_id bigint; v_u integer; v_objet jsonb;
  v_data jsonb; v_sec jsonb;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^mil-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF p_matricules IS NULL OR array_length(p_matricules, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_selection'); END IF;

  SELECT * INTO v_deja FROM public.militaire_terminal_requetes WHERE requete = p_requete;
  IF FOUND THEN RETURN v_deja.resultat || jsonb_build_object('rejeu', true); END IF;

  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(g.o_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = g.o_section;

  FOR r IN
    SELECT sm.pnj_id, sm.matricule, m.pa,
           CASE WHEN coalesce(b.sol->>'dernier_ration','') = v_jour
                THEN coalesce((b.sol->>'nb_ration')::integer, 1) ELSE 0 END AS nb
      FROM public.pnj_soldats_metier sm
      JOIN public.pnj_membres m ON m.id = sm.pnj_id
      LEFT JOIN LATERAL (
        SELECT s AS sol FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
         WHERE s->>'matricule' = sm.matricule LIMIT 1) b ON true
     WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
       AND m.statut = 'actif' AND coalesce(sm.en_reserve,false) = false
       AND sm.matricule = ANY(p_matricules)
     ORDER BY sm.matricule
  LOOP
    IF NOT public.militaire_terminal_liaison(g.o_moi, r.pnj_id) THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'hors_liaison');
      CONTINUE;
    END IF;

    v_id := NULL; v_objet := NULL;
    SELECT p.id, p.objet INTO v_id, v_objet FROM public.pnj_possessions p
     WHERE p.pnj_id = r.pnj_id AND p.objet->>'produitMilitaire' = 'ration_combat'
     ORDER BY p.id LIMIT 1 FOR UPDATE;

    IF v_id IS NULL OR r.pa >= c_pa_max OR r.nb >= c_max_jour THEN
      v_sans := v_sans + 1;
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison',
        CASE WHEN v_id IS NULL THEN 'sans_ration'
             WHEN r.pa >= c_pa_max THEN 'pa_au_maximum'
             ELSE 'maximum_quotidien' END, 'execute', true);
      CONTINUE;
    END IF;

    v_u := public.militaire_unites_objet(v_objet);
    IF v_u <= 1 THEN DELETE FROM public.pnj_possessions WHERE id = v_id;
    ELSE UPDATE public.pnj_possessions
            SET objet = v_objet || jsonb_build_object('qty', v_u - 1) WHERE id = v_id; END IF;

    v_ids  := v_ids  || r.pnj_id;
    v_mats := v_mats || r.matricule;
    v_avec := v_avec + 1;
  END LOOP;

  IF v_avec > 0 THEN
    PERFORM public.pnj_pa_crediter(v_ids, c_gain);
    SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = g.o_compagnie FOR UPDATE;
    UPDATE public.compagnies_militaires
       SET data = jsonb_set(v_data, '{sections}', (
             SELECT coalesce(jsonb_agg(
               CASE WHEN s->>'id' = g.o_section
                    THEN jsonb_set(s, '{soldats}', (
                           SELECT coalesce(jsonb_agg(
                             CASE WHEN (so->>'matricule') = ANY(v_mats)
                                  THEN so || jsonb_build_object('dernier_ration', v_jour,
                                         'nb_ration', (CASE WHEN coalesce(so->>'dernier_ration','') = v_jour
                                                            THEN coalesce((so->>'nb_ration')::integer,1)
                                                            ELSE 0 END) + 1)
                                  ELSE so END ORDER BY o2), '[]'::jsonb)
                             FROM jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb))
                                  WITH ORDINALITY AS t2(so, o2)))
                    ELSE s END ORDER BY o1), '[]'::jsonb)
               FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb))
                    WITH ORDINALITY AS t1(s, o1))),
           updated_at = now()
     WHERE id = g.o_compagnie;
    PERFORM public.militaire_blob_projeter(g.o_compagnie);
  END IF;

  v_res := jsonb_build_object('ok', true, 'action', 'manger',
    'avec_ration', v_avec, 'sans_ration', v_sans, 'gain_pa', c_gain, 'details', v_refus);
  INSERT INTO public.militaire_terminal_requetes (requete, acteur, action, resultat)
  VALUES (p_requete, g.o_moi, 'manger', v_res);
  RETURN v_res;
END; $function$;

-- militaire_terminal_rejoindre(text,text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_terminal_rejoindre(p_requete text, p_matricules text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  g record; v_deja record; r record; v_res jsonb; v_ville text;
  v_ids text[] := '{}'; v_refus jsonb := '[]'::jsonb;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^mil-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF p_matricules IS NULL OR array_length(p_matricules, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_selection'); END IF;

  SELECT * INTO v_deja FROM public.militaire_terminal_requetes WHERE requete = p_requete;
  IF FOUND THEN RETURN v_deja.resultat || jsonb_build_object('rejeu', true); END IF;

  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  SELECT current_city INTO v_ville FROM public.personnages_donnees WHERE name = g.o_moi;
  IF coalesce(v_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue'); END IF;

  FOR r IN
    SELECT sm.pnj_id, sm.matricule, m.leader_pj, pe.ville AS ville_reelle
      FROM public.pnj_soldats_metier sm
      JOIN public.pnj_membres m ON m.id = sm.pnj_id
      LEFT JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
     WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
       AND m.statut = 'actif' AND coalesce(sm.en_reserve,false) = false
       AND sm.matricule = ANY(p_matricules)
     ORDER BY sm.matricule
  LOOP
    IF r.leader_pj = g.o_moi THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'deja_avec_vous');
      CONTINUE;
    END IF;
    IF NOT public.militaire_terminal_liaison(g.o_moi, r.pnj_id) THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'hors_liaison');
      CONTINUE;
    END IF;
    IF r.ville_reelle IS DISTINCT FROM v_ville THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule,
        'raison', 'autre_ville_transport_requis', 'ville', r.ville_reelle);
      CONTINUE;
    END IF;
    v_ids := v_ids || r.pnj_id;
  END LOOP;

  IF array_length(v_ids,1) IS NOT NULL THEN
    UPDATE public.pnj_membres
       SET leader_pj = g.o_moi, leader_pnj_id = NULL,
           ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL, maj_le = now()
     WHERE id = ANY(v_ids);
    PERFORM public.militaire_blob_projeter(g.o_compagnie);
  END IF;

  v_res := jsonb_build_object('ok', true, 'action', 'rejoindre',
    'rejoints', coalesce(array_length(v_ids,1),0), 'details', v_refus);
  INSERT INTO public.militaire_terminal_requetes (requete, acteur, action, resultat)
  VALUES (p_requete, g.o_moi, 'rejoindre', v_res);
  RETURN v_res;
END; $function$;

-- militaire_terminal_section() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_terminal_section()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa_max          constant integer := 12;
  c_par_tente       constant integer := 13;
  c_max_ration_jour constant integer := 2;
  g record; v_sec jsonb; v_jour text;
  v_ville text; v_bat text; v_room text; v_pays text;
  v_radio_moi boolean; v_tentes integer; v_pj_groupe integer;
  v_soldats jsonb; v_inv jsonb;
BEGIN
  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(g.o_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = g.o_section;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  SELECT country, current_city, current_building, current_room
    INTO v_pays, v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = g.o_moi;

  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
           jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                     THEN pd.inventory ELSE '[]'::jsonb END) i
           WHERE pd.name = g.o_moi AND i->>'produitMilitaire' = 'radio') INTO v_radio_moi;

  SELECT coalesce((
    SELECT count(*) FROM public.personnages_donnees pd,
           jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                     THEN pd.inventory ELSE '[]'::jsonb END) i
     WHERE i->>'produitMilitaire' = 'tente'
       AND (pd.name = g.o_moi
            OR (pd.current_city = v_ville AND pd.current_building IS NOT DISTINCT FROM v_bat
                AND pd.current_room IS NOT DISTINCT FROM v_room
                AND EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
                             WHERE coalesce((s->>'pj')::boolean,false) AND s->>'nom' = pd.name)))
  ), 0) + coalesce((
    SELECT count(*) FROM public.pnj_possessions p
      JOIN public.pnj_membres m ON m.id = p.pnj_id
      JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
       AND m.statut = 'actif' AND m.leader_pj = g.o_moi
       AND p.objet->>'produitMilitaire' = 'tente'
  ), 0) INTO v_tentes;

  SELECT 1 + coalesce((
    SELECT count(*) FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
      JOIN public.personnages_donnees pd ON pd.name = s->>'nom'
     WHERE coalesce((s->>'pj')::boolean,false) AND s->>'nom' <> g.o_moi
       AND pd.current_city = v_ville
       AND pd.current_building IS NOT DISTINCT FROM v_bat
       AND pd.current_room IS NOT DISTINCT FROM v_room), 0) INTO v_pj_groupe;

  SELECT coalesce(jsonb_agg(t.ligne ORDER BY t.nom), '[]'::jsonb) INTO v_inv
    FROM (
      SELECT min(coalesce(i->>'name','?')) AS nom,
             jsonb_build_object(
               'signature', public.militaire_objet_signature(i),
               'name', min(coalesce(i->>'name','?')),
               'icon', min(coalesce(i->>'icon','ti-package')),
               'type', min(coalesce(i->>'type','')),
               'qte', sum(public.militaire_unites_objet(i))::integer,
               'arme', bool_or(i->>'type' = 'arme')) AS ligne
        FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                       THEN pd.inventory ELSE '[]'::jsonb END) i
       WHERE pd.name = g.o_moi
       GROUP BY public.militaire_objet_signature(i)
    ) t;

  SELECT coalesce(jsonb_agg(x.ligne ORDER BY x.matricule), '[]'::jsonb) INTO v_soldats
    FROM (
      SELECT sm.matricule,
             jsonb_build_object(
               'matricule', sm.matricule,
               'pa', m.pa, 'pa_max', c_pa_max,
               'arme', coalesce(sm.arme, 'corps_a_corps'),
               'arme_feu', EXISTS (SELECT 1 FROM public.militaire_armes_bonus b
                                    WHERE b.cle = coalesce(sm.arme,'corps_a_corps') AND b.mode='feu'),
               'avec_moi', (m.leader_pj = g.o_moi),
               'leader', m.leader_pj,
               'ville', CASE WHEN m.leader_pj = g.o_moi THEN NULL ELSE pe.ville END,
               'copresent', public.pnj_co_present(g.o_moi, m.id),
               'radio', EXISTS (SELECT 1 FROM public.pnj_possessions p
                                 WHERE p.pnj_id = m.id AND p.objet->>'produitMilitaire' = 'radio'),
               'a_ration', EXISTS (SELECT 1 FROM public.pnj_possessions p
                                    WHERE p.pnj_id = m.id
                                      AND p.objet->>'produitMilitaire' = 'ration_combat'),
               'rations_jour', CASE WHEN coalesce(b.sol->>'dernier_ration','') = v_jour
                                    THEN coalesce((b.sol->>'nb_ration')::integer, 1) ELSE 0 END,
               'max_ration_jour', c_max_ration_jour,
               'a_dormi', (coalesce(sm.dernier_sommeil,'') = v_jour),
               'possessions', coalesce((
                  SELECT jsonb_agg(q.ligne ORDER BY q.nom)
                    FROM (SELECT min(coalesce(p2.objet->>'name','?')) AS nom,
                                 jsonb_build_object(
                                   'signature', public.militaire_objet_signature(p2.objet),
                                   'name', min(coalesce(p2.objet->>'name','?')),
                                   'icon', min(coalesce(p2.objet->>'icon','ti-package')),
                                   'type', min(coalesce(p2.objet->>'type','')),
                                   'qte', sum(public.militaire_unites_objet(p2.objet))::integer) AS ligne
                            FROM public.pnj_possessions p2 WHERE p2.pnj_id = m.id
                           GROUP BY public.militaire_objet_signature(p2.objet)) q
                  ), '[]'::jsonb)
             ) AS ligne
        FROM public.pnj_soldats_metier sm
        JOIN public.pnj_membres m ON m.id = sm.pnj_id
        LEFT JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
        LEFT JOIN LATERAL (
          SELECT s AS sol FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
           WHERE s->>'matricule' = sm.matricule LIMIT 1) b ON true
       WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
         AND m.statut = 'actif' AND coalesce(sm.en_reserve, false) = false
    ) x;

  RETURN jsonb_build_object('ok', true,
    'moi', g.o_moi, 'pays', v_pays,
    'ma_ville', v_ville, 'suis_a_la_caserne', (v_bat = 'caserne-militaire'),
    'radio_moi', coalesce(v_radio_moi, false),
    'tentes', coalesce(v_tentes, 0),
    'capacite_tente', coalesce(v_tentes,0) * c_par_tente,
    'par_tente', c_par_tente,
    'places_pj', v_pj_groupe,
    'places_tente_libres', greatest(0, coalesce(v_tentes,0) * c_par_tente - v_pj_groupe),
    'mon_inventaire', v_inv,
    'soldats', v_soldats,
    'effectif', jsonb_array_length(v_soldats));
END; $function$;

-- militaire_terminal_transferer(text,text,text,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_terminal_transferer(p_requete text, p_matricule text, p_signature text, p_qte integer, p_sens text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_plafond constant integer := 100;
  g record; v_deja record; v_pnj text; v_qte integer := coalesce(p_qte, 0);
  v_inv jsonb; v_reste integer; v_dispo integer := 0; v_occupe numeric;
  v_ligne jsonb; v_u integer; v_nouv jsonb := '[]'::jsonb;
  v_bouge integer := 0; v_nom text; v_arme text; v_id bigint; v_objet jsonb;
  v_res jsonb;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^mil-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF coalesce(p_sens,'') NOT IN ('donner','reprendre') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide'); END IF;
  IF v_qte < 1 OR v_qte > 100 OR v_qte IS DISTINCT FROM p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  IF coalesce(btrim(coalesce(p_signature,'')),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;

  SELECT * INTO v_deja FROM public.militaire_terminal_requetes WHERE requete = p_requete;
  IF FOUND THEN RETURN v_deja.resultat || jsonb_build_object('rejeu', true); END IF;

  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  SELECT sm.pnj_id INTO v_pnj
    FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
     AND sm.matricule = p_matricule AND m.statut = 'actif';
  IF v_pnj IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable'); END IF;
  IF NOT public.pnj_co_present(g.o_moi, v_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents'); END IF;

  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_inv FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;

  IF p_sens = 'donner' THEN
    SELECT coalesce(sum(public.militaire_unites_objet(i)), 0)::integer INTO v_dispo
      FROM jsonb_array_elements(v_inv) i
     WHERE public.militaire_objet_signature(i) = p_signature;
    IF v_dispo < v_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quantite_insuffisante',
        'disponibles', v_dispo, 'demande', v_qte); END IF;

    v_reste := v_qte;
    FOR v_ligne IN SELECT value FROM jsonb_array_elements(v_inv) LOOP
      IF v_reste > 0 AND public.militaire_objet_signature(v_ligne) = p_signature THEN
        v_u := public.militaire_unites_objet(v_ligne);
        v_nom := coalesce(v_ligne->>'name', '?');
        IF v_u <= v_reste THEN
          INSERT INTO public.pnj_possessions (pnj_id, objet, origine)
          VALUES (v_pnj, v_ligne, 'socle');
          v_reste := v_reste - v_u; v_bouge := v_bouge + v_u;
        ELSE
          INSERT INTO public.pnj_possessions (pnj_id, objet, origine)
          VALUES (v_pnj, v_ligne || jsonb_build_object('qty', v_reste), 'socle');
          v_nouv := v_nouv || jsonb_build_array(v_ligne || jsonb_build_object('qty', v_u - v_reste));
          v_bouge := v_bouge + v_reste; v_reste := 0;
        END IF;
      ELSE
        v_nouv := v_nouv || jsonb_build_array(v_ligne);
      END IF;
    END LOOP;
    UPDATE public.personnages_donnees SET inventory = v_nouv, updated_at = now()
     WHERE name = g.o_moi;

  ELSE
    SELECT coalesce(sum(public.militaire_unites_objet(p.objet)), 0)::integer INTO v_dispo
      FROM public.pnj_possessions p
     WHERE p.pnj_id = v_pnj AND public.militaire_objet_signature(p.objet) = p_signature;
    IF v_dispo < v_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quantite_insuffisante_soldat',
        'disponibles', v_dispo, 'demande', v_qte); END IF;

    SELECT coalesce(sum(greatest(1, coalesce((i->>'qty')::numeric,
             (i->>'encombrement')::numeric, 1))), 0) INTO v_occupe
      FROM jsonb_array_elements(v_inv) i;
    IF v_occupe + v_qte > c_plafond THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein',
        'occupe', v_occupe, 'plafond', c_plafond, 'demande', v_qte); END IF;

    v_reste := v_qte;
    FOR v_id, v_objet IN
      SELECT p.id, p.objet FROM public.pnj_possessions p
       WHERE p.pnj_id = v_pnj AND public.militaire_objet_signature(p.objet) = p_signature
       ORDER BY p.id FOR UPDATE
    LOOP
      EXIT WHEN v_reste <= 0;
      v_u := public.militaire_unites_objet(v_objet);
      v_nom := coalesce(v_objet->>'name', '?');
      IF v_u <= v_reste THEN
        DELETE FROM public.pnj_possessions WHERE id = v_id;
        v_inv := v_inv || jsonb_build_array(v_objet);
        v_reste := v_reste - v_u; v_bouge := v_bouge + v_u;
      ELSE
        UPDATE public.pnj_possessions
           SET objet = v_objet || jsonb_build_object('qty', v_u - v_reste) WHERE id = v_id;
        v_inv := v_inv || jsonb_build_array(v_objet || jsonb_build_object('qty', v_reste));
        v_bouge := v_bouge + v_reste; v_reste := 0;
      END IF;
    END LOOP;
    UPDATE public.personnages_donnees SET inventory = v_inv, updated_at = now()
     WHERE name = g.o_moi;
  END IF;

  v_arme := public.militaire_arme_recalculer(v_pnj);

  v_res := jsonb_build_object('ok', true, 'sens', p_sens, 'matricule', p_matricule,
    'signature', p_signature, 'quantite', v_bouge, 'objet', v_nom, 'arme', v_arme);
  INSERT INTO public.militaire_terminal_requetes (requete, acteur, action, resultat)
  VALUES (p_requete, g.o_moi, 'transfert', v_res);
  RETURN v_res;
END; $function$;

-- militaire_trousse_retirer() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_trousse_retirer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_plafond constant integer := 100;
  v_moi text; v_pays text; v_bat text; v_inv jsonb; v_occupe numeric;
  v_data jsonb; v_commun jsonb; v_tex integer; v_med integer; v_des integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country,'republic'), coalesce(current_building,''),
         CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_pays, v_bat, v_inv
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  -- La PIECE determine ce qu'on peut fabriquer ; le BATIMENT determine les matieres accessibles.
  IF v_bat <> 'caserne-militaire' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  SELECT coalesce(sum(greatest(1, coalesce((i->>'qty')::numeric, (i->>'encombrement')::numeric, 1))), 0)
    INTO v_occupe FROM jsonb_array_elements(v_inv) i;
  IF v_occupe + 1 > c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'plafond', c_plafond);
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes'); END IF;
  v_commun := CASE WHEN jsonb_typeof(v_data->'caserneMatieres')='object'
                   THEN v_data->'caserneMatieres' ELSE '{}'::jsonb END;
  v_tex := greatest(0, coalesce((v_commun->>'textile')::integer, 0));
  v_med := greatest(0, coalesce((v_commun->>'medicaments')::integer, 0));
  v_des := greatest(0, coalesce((v_commun->>'desinfectant')::integer, 0));

  IF v_tex < 1 OR v_med < 1 OR v_des < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ingredients_insuffisants',
      'textile', v_tex, 'medicaments', v_med, 'desinfectant', v_des);
  END IF;

  UPDATE public.budgets_nationaux
     SET data = v_data || jsonb_build_object('caserneMatieres',
           v_commun || jsonb_build_object('textile', v_tex - 1, 'medicaments', v_med - 1,
                                          'desinfectant', v_des - 1)),
         updated_at = now()
   WHERE id = v_pays;

  UPDATE public.personnages_donnees
     SET inventory = v_inv || jsonb_build_array(jsonb_build_object(
           'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
           'type', 'soin', 'sousType', 'militaire', 'produitMilitaire', 'trousse_secours',
           'origineMilitaire', true, 'usageUnique', true,
           'name', 'Trousse de premiers secours', 'icon', 'ti-first-aid-kit',
           'legal', true,
           'imageUrl', 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/militaire-trousse-secours.png',
           'desc', 'Trousse de premiers secours. Usage unique. Restaure des PA, d''autant plus que le soignant maîtrise le Secourisme.'))
   WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'fabriquee', true,
    'restant', jsonb_build_object('textile', v_tex - 1, 'medicaments', v_med - 1, 'desinfectant', v_des - 1));
END;
$function$;

-- militaire_trousse_utiliser(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_trousse_utiliser(p_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa_max_pj constant integer := 30;
  v_moi text; v_inv jsonb; v_pos integer; v_sec numeric; v_gain integer;
  v_cible text; v_pa_avant integer; v_pa_apres integer;
  m record; c record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_cible := coalesce(nullif(btrim(coalesce(p_cible,'')), ''), v_moi);

  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END,
         coalesce((competences_militaires->>'secourisme')::numeric, 0)
    INTO v_inv, v_sec FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  -- CO-PRESENCE, MOTIF DE impact_deposer : pays + ville + batiment + piece identiques,
  -- verifiee AVANT toute ecriture pour qu'un refus ne consomme pas la trousse.
  IF v_cible <> v_moi THEN
    SELECT country, current_city, current_building, current_room INTO m
      FROM public.personnages_donnees WHERE name = v_moi;
    SELECT name, country, current_city, current_building, current_room INTO c
      FROM public.personnages_donnees WHERE name = v_cible;
    IF c.name IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable'); END IF;
    IF m.country IS DISTINCT FROM c.country
       OR m.current_city IS DISTINCT FROM c.current_city
       OR m.current_building IS DISTINCT FROM c.current_building
       OR m.current_room IS DISTINCT FROM c.current_room THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit');
    END IF;
  END IF;

  SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
   WHERE i->>'produitMilitaire' = 'trousse_secours' ORDER BY pos LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_trousse'); END IF;

  -- +2 de base, +1 par tranche COMPLETE de 25 de Secourisme DU SOIGNANT.
  v_gain := 2 + floor(least(100, greatest(0, v_sec)) / 25)::integer;

  SELECT coalesce(pa, 0) INTO v_pa_avant FROM public.personnages_donnees WHERE name = v_cible FOR UPDATE;
  IF v_pa_avant IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable'); END IF;
  v_pa_apres := least(c_pa_max_pj, v_pa_avant + v_gain);

  -- USAGE UNIQUE : la trousse quitte l'inventaire dans la MEME transaction que le gain.
  SELECT coalesce(jsonb_agg(i ORDER BY pos), '[]'::jsonb) INTO v_inv
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos) WHERE pos <> v_pos;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;
  UPDATE public.personnages_donnees SET pa = v_pa_apres WHERE name = v_cible;

  RETURN jsonb_build_object('ok', true, 'soignant', v_moi, 'cible', v_cible,
    'secourisme', v_sec, 'gain_theorique', v_gain,
    'pa_avant', v_pa_avant, 'pa_apres', v_pa_apres, 'gain_reel', v_pa_apres - v_pa_avant);
END; $function$;

-- militaire_unites_objet(jsonb) -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.militaire_unites_objet(p_objet jsonb)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT greatest(1, floor(coalesce((p_objet->>'qty')::numeric, 1))::integer);
$function$;

-- mutinerie_camp_de(text) -> text | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.mutinerie_camp_de(p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT mm.camp FROM public.mutineries_membres mm
    JOIN public.mutineries m ON m.camp = mm.camp
   WHERE mm.personnage = p_nom AND mm.statut = 'actif' AND m.statut = 'active'
   LIMIT 1;
$function$;

-- mutinerie_camps_presents(text,text,text,text) -> text[] | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.mutinerie_camps_presents(p_pays text, p_ville text, p_bat text, p_piece text)
 RETURNS text[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT coalesce(array_agg(DISTINCT t.camp), '{}'::text[]) FROM (
    SELECT coalesce(sm.mutin, m.pays) AS camp
      FROM public.pnj_membres m
      JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
      JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
     WHERE m.famille = 'soldat'
       AND m.statut  = 'actif'
       AND sm.en_reserve = false
       AND m.pays = p_pays
       AND coalesce(m.pa, 0) > 0
       AND pe.ville = p_ville AND pe.building_id = p_bat AND pe.room_id = p_piece
    UNION ALL
    SELECT coalesce(public.mutinerie_camp_de(pd.name), pd.country)
      FROM public.personnages_donnees pd
      JOIN public.services_militaires sm2 ON sm2.personnage = pd.name AND sm2.fin_ts IS NULL
     WHERE pd.country = p_pays AND pd.current_city = p_ville
       AND pd.current_building = p_bat AND pd.current_room = p_piece
       AND coalesce(pd.pa, 0) > 0
  ) t;
$function$;

-- mutinerie_est_camp(text) -> boolean | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.mutinerie_est_camp(p_camp text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.mutineries WHERE camp = p_camp);
$function$;

-- mutinerie_pays_du_camp(text) -> text | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.mutinerie_pays_du_camp(p_camp text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT coalesce((SELECT m.pays FROM public.mutineries m WHERE m.camp = p_camp), p_camp);
$function$;

-- mutinerie_social_national(text) -> numeric | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.mutinerie_social_national(p_pays text)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT CASE WHEN count(*) = 3 THEN round(avg((v.data ->> 'social')::numeric), 2) ELSE 45 END
    FROM public.indices_villes v
   WHERE v.id = ANY (ARRAY[p_pays || '_capitale', p_pays || '_ville_a', p_pays || '_ville_b'])
     AND jsonb_typeof(v.data -> 'social') = 'number';
$function$;
