-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine renseignement -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- agent_au_bureau_min_def(text,text) -> boolean | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.agent_au_bureau_min_def(p_bat text, p_piece text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT p_bat = 'palais-gouvernement' AND p_piece = 'bureau_min_def';
$function$

-- agent_conseillere_observer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agent_conseillere_observer(p_agent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  a record; t record; o record; tr record;
  v_jour date := ((now() AT TIME ZONE 'Europe/Paris')::date - 1);
  v_dup numeric; v_chance integer; v_jet integer; v_ref text; v_nb integer := 0;
BEGIN
  SELECT ag.*, c.statut AS statut_cellule, c.id AS cel,
         pe.pays AS pays_eff, pe.ville AS ville_eff,
         pe.building_id AS bat_eff, pe.room_id AS room_eff
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE ag.id = p_agent_id AND ag.role = 'conseiller';
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.ville_eff IS NULL OR a.pays_eff IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_sans_position'); END IF;
  IF public.agent_au_bureau_min_def(a.bat_eff, a.room_eff) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_au_bureau'); END IF;

  FOR t IN
    SELECT d.name, public.assemblee_stat_base(d.stats, 'DUP') AS dup
      FROM public.personnages_donnees d
     WHERE d.country = a.pays_eff
       AND d.current_city = a.ville_eff
       AND d.current_building = a.bat_eff
       AND (d.poste ->> 'id' IN ('president','pm','min_ae','min_def','min_fin',
                                 'min_info','min_int','min_just','depute','maire')
            OR jsonb_typeof(d.poste_depute) = 'object')
  LOOP
    v_dup := t.dup;

    BEGIN
      INSERT INTO public.agent_tentatives (agent_id, cible, canal, jour_paris)
      VALUES (p_agent_id, t.name, 'trace', v_jour);

      v_chance := greatest(10, least(90, round(90 - 2 * v_dup)::integer));
      v_jet    := floor(random() * 100)::integer + 1;
      IF v_jet <= v_chance THEN
        SELECT at.id, at.type_action, at.city, at.cible AS victime INTO tr
          FROM public.actions_tracables at
         WHERE at.auteur = t.name
           AND NOT EXISTS (SELECT 1 FROM public.renseignements_connus rc
                            WHERE rc.titulaire = 'cellule:' || a.cel
                              AND rc.fait_objectif_ref = 'actions_tracables:' || at.id)
         ORDER BY at.jour DESC LIMIT 1;
        IF tr.id IS NOT NULL THEN
          INSERT INTO public.renseignements_connus
            (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
             fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
          VALUES ('rc_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' ||
                  substr(md5(random()::text), 1, 8),
                  'cellule:' || a.cel,
                  t.name || ' serait implique dans : ' || tr.type_action ||
                  coalesce(' (vise : ' || tr.victime || ')', '') ||
                  coalesce(', a ' || tr.city, '') || '.',
                  t.name, 'trace_criminelle', a.nom_couverture, 'observation',
                  'actions_tracables:' || tr.id, 0, 0, 2147483647);
          v_nb := v_nb + 1;
        END IF;
      END IF;
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    BEGIN
      INSERT INTO public.agent_tentatives (agent_id, cible, canal, jour_paris)
      VALUES (p_agent_id, t.name, 'appartenance', v_jour);

      v_chance := greatest(10, least(75, round(75 - 2 * v_dup)::integer));
      v_jet    := floor(random() * 100)::integer + 1;
      IF v_jet <= v_chance THEN
        SELECT og.id, (og.data::jsonb ->> 'nom') AS nom_org,
               (og.data::jsonb ->> 'type') AS type_org
          INTO o
          FROM public.organisations og
         WHERE (og.data::jsonb ->> 'type') IN ('criminelle', 'loge')
           AND EXISTS (SELECT 1 FROM jsonb_array_elements(
                         coalesce(og.data::jsonb -> 'membres', '[]'::jsonb)) m
                        WHERE m ->> 'nom' = t.name)
           AND NOT EXISTS (SELECT 1 FROM public.renseignements_connus rc
                            WHERE rc.titulaire = 'cellule:' || a.cel
                              AND rc.fait_objectif_ref = 'appartenance:' || og.id || ':' || t.name)
         ORDER BY random() LIMIT 1;
        IF o.id IS NOT NULL THEN
          INSERT INTO public.renseignements_connus
            (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
             fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
          VALUES ('ra_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' ||
                  substr(md5(random()::text), 1, 8),
                  'cellule:' || a.cel,
                  t.name || ' appartiendrait a ' ||
                  CASE o.type_org WHEN 'loge' THEN 'la loge' ELSE 'l''organisation' END ||
                  ' « ' || coalesce(o.nom_org, '?') || ' ».',
                  t.name, 'appartenance_secrete', a.nom_couverture, 'observation',
                  'appartenance:' || o.id || ':' || t.name, 0, 0, 2147483647);
          v_nb := v_nb + 1;
        END IF;
      END IF;
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
  END LOOP;

  IF v_nb > 0 THEN PERFORM public.agent_trace_deposer(p_agent_id); END IF;
  RETURN jsonb_build_object('ok', true, 'faits', v_nb);
END;
$function$

-- agent_coordinateur_multimodal(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agent_coordinateur_multimodal(p_agent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  a record; p record; f record;
  v_jour date := ((now() AT TIME ZONE 'Europe/Paris')::date - 1);
  v_ref text; v_nb integer := 0; v_txt text;
BEGIN
  SELECT ag.*, c.statut AS statut_cellule, c.id AS cel,
         pe.pays AS pays_eff, pe.ville AS ville_eff,
         pe.building_id AS bat_eff, pe.room_id AS room_eff
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE ag.id = p_agent_id AND ag.role = 'coordinateur';
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.ville_eff IS NULL OR a.pays_eff IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_sans_position'); END IF;
  IF public.agent_au_bureau_min_def(a.bat_eff, a.room_eff) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_au_bureau'); END IF;
  IF a.bat_eff IS NULL OR a.bat_eff NOT LIKE 'centre-multinodal%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_centre_multimodal'); END IF;

  FOR p IN
    WITH suite AS (
      SELECT h.name, h.building_id, h.created_at,
             lag(h.building_id)  OVER w AS avant,
             lead(h.building_id) OVER w AS apres
        FROM public.historique_deplacements h
       WHERE h.country = a.pays_eff AND h.city = a.ville_eff
      WINDOW w AS (PARTITION BY h.name ORDER BY h.created_at)
    )
    SELECT s.name,
           count(*)                              AS passages,
           min(s.created_at)                     AS premier,
           max(s.created_at)                     AS dernier,
           (array_remove(array_agg(s.avant ORDER BY s.created_at), NULL))[1]  AS origine,
           (array_remove(array_agg(s.apres ORDER BY s.created_at DESC), NULL))[1] AS destination
      FROM suite s
     WHERE s.building_id = a.bat_eff
       AND (s.created_at AT TIME ZONE 'Europe/Paris')::date = v_jour
     GROUP BY s.name
  LOOP
    v_ref := 'multimodal:' || a.bat_eff || ':' || p.name || ':' || v_jour;
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.renseignements_connus rc
                           WHERE rc.titulaire = 'cellule:' || a.cel
                             AND rc.fait_objectif_ref = v_ref);

    v_txt := p.name || ' : ' || p.passages || ' passage' ||
             CASE WHEN p.passages > 1 THEN 's' ELSE '' END ||
             ' au centre multimodal de ' || a.ville_eff ||
             ', entre ' || to_char(p.premier AT TIME ZONE 'Europe/Paris', 'HH24:MI') ||
             ' et ' || to_char(p.dernier AT TIME ZONE 'Europe/Paris', 'HH24:MI') ||
             coalesce(', en provenance de ' || p.origine, '') ||
             coalesce(', reparti vers ' || p.destination, '') || '.';

    INSERT INTO public.renseignements_connus
      (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
       fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
    VALUES ('rm_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' ||
            substr(md5(random()::text), 1, 8),
            'cellule:' || a.cel, v_txt, p.name, 'mouvements', a.nom_couverture, 'observation',
            v_ref, 0, 0, 2147483647);
    v_nb := v_nb + 1;
  END LOOP;

  FOR f IN
    SELECT cd.id, cd.personne, cd.objet_nom, cd.quantite
      FROM public.confiscations_douanieres cd
     WHERE cd.pays = a.pays_eff AND cd.ville = a.ville_eff
       AND cd.building_id = a.bat_eff
       AND (cd.cree_le AT TIME ZONE 'Europe/Paris')::date = v_jour
  LOOP
    v_ref := 'confiscation:' || f.id;
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.renseignements_connus rc
                           WHERE rc.titulaire = 'cellule:' || a.cel
                             AND rc.fait_objectif_ref = v_ref);
    INSERT INTO public.renseignements_connus
      (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
       fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
    VALUES ('rf_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' ||
            substr(md5(random()::text), 1, 8),
            'cellule:' || a.cel,
            'Les douanes ont confisque a ' || f.personne || ' : ' || f.objet_nom ||
            coalesce(' (x' || f.quantite || ')', '') || '.',
            f.personne, 'confiscation', a.nom_couverture, 'observation',
            v_ref, 0, 0, 2147483647);
    v_nb := v_nb + 1;
  END LOOP;

  IF v_nb > 0 THEN PERFORM public.agent_trace_deposer(p_agent_id); END IF;
  RETURN jsonb_build_object('ok', true, 'faits', v_nb);
END;
$function$

-- agent_coordinateur_port(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agent_coordinateur_port(p_agent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  a record; c record; v_ref text; v_nb integer := 0;
  v_reel integer; v_noms text; v_recoupe boolean;
  v_jour date := ((now() AT TIME ZONE 'Europe/Paris')::date - 1);
  v_port jsonb; v_arr jsonb;
BEGIN
  SELECT ag.*, ce.statut AS statut_cellule, ce.id AS cel,
         pe.pays AS pays_eff, pe.ville AS ville_eff,
         pe.building_id AS bat_eff, pe.room_id AS room_eff
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement ce ON ce.id = ag.cellule_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE ag.id = p_agent_id AND ag.role = 'coordinateur';
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.ville_eff IS NULL OR a.pays_eff IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_sans_position'); END IF;
  IF public.agent_au_bureau_min_def(a.bat_eff, a.room_eff) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_au_bureau'); END IF;
  IF a.bat_eff IS NULL OR a.bat_eff NOT LIKE 'port-%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_port'); END IF;

  FOR c IN
    SELECT f.id, f.declaration_douaniere, f.statut, f.quantite_arrivee
      FROM public.caisses_fret f
     WHERE (f.building_origine = a.bat_eff OR f.building_destination = a.bat_eff)
       AND f.statut IN ('fermee', 'en_transit', 'arrivee')
  LOOP
    SELECT coalesce(sum(cc.quantite), 0),
           coalesce(string_agg(DISTINCT lower(cc.objet ->> 'name'), ' '), '')
      INTO v_reel, v_noms
      FROM public.contenu_caisses_fret cc WHERE cc.caisse_id = c.id;

    IF c.quantite_arrivee IS NOT NULL AND c.quantite_arrivee <> v_reel THEN
      v_ref := 'fret_quantite:' || c.id || ':' || v_jour;
      IF NOT EXISTS (SELECT 1 FROM public.renseignements_connus rc
                      WHERE rc.titulaire = 'cellule:' || a.cel AND rc.fait_objectif_ref = v_ref) THEN
        INSERT INTO public.renseignements_connus
          (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
           fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
        VALUES ('rp_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || substr(md5(random()::text),1,8),
                'cellule:' || a.cel,
                'Une caisse arrivee a ' || a.bat_eff || ' comptait ' || c.quantite_arrivee ||
                ' unite(s) a l''arrivee ; il en reste ' || v_reel || '.',
                c.id, 'fret_divergence', a.nom_couverture, 'observation', v_ref, 0, 0, 2147483647);
        v_nb := v_nb + 1;
      END IF;
    END IF;

    IF coalesce(btrim(c.declaration_douaniere), '') <> '' AND v_reel > 0 THEN
      SELECT bool_or(
               v_noms LIKE '%' || rtrim(md, 's') || '%'
               OR EXISTS (SELECT 1 FROM unnest(regexp_split_to_array(v_noms, '[^[:alnum:]]+')) mo
                           WHERE length(mo) >= 4
                             AND lower(c.declaration_douaniere) LIKE '%' || rtrim(mo, 's') || '%'))
        INTO v_recoupe
        FROM unnest(regexp_split_to_array(lower(c.declaration_douaniere), '[^[:alnum:]]+')) md
       WHERE length(md) >= 4;

      IF v_recoupe IS NOT NULL AND v_recoupe = false THEN
        v_ref := 'fret_nature:' || c.id || ':' || v_jour;
        IF NOT EXISTS (SELECT 1 FROM public.renseignements_connus rc
                        WHERE rc.titulaire = 'cellule:' || a.cel AND rc.fait_objectif_ref = v_ref) THEN
          INSERT INTO public.renseignements_connus
            (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
             fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
          VALUES ('rp_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || substr(md5(random()::text),1,8),
                  'cellule:' || a.cel,
                  'Une caisse declaree « ' || c.declaration_douaniere ||
                  ' » ne contient aucune marchandise correspondant a cette declaration.',
                  c.id, 'fret_divergence', a.nom_couverture, 'observation', v_ref, 0, 0, 2147483647);
          v_nb := v_nb + 1;
        END IF;
      END IF;
    END IF;
  END LOOP;

  SELECT (b.data #>> '{}')::jsonb -> 'port' INTO v_port
    FROM public.batiments_etat b
   WHERE b.id = a.pays_eff || '_' || a.ville_eff || '_' || a.bat_eff;
  IF v_port IS NOT NULL AND jsonb_typeof(v_port -> 'arrivages') = 'array' THEN
    FOR v_arr IN SELECT x FROM jsonb_array_elements(v_port -> 'arrivages') x LIMIT 5
    LOOP
      v_ref := 'fret_arrivage:' || coalesce(v_arr ->> 'jour', '?') || ':' ||
               coalesce(v_arr ->> 'resource', '?') || ':' || coalesce(v_arr ->> 'origine', '?');
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.renseignements_connus rc
                             WHERE rc.titulaire = 'cellule:' || a.cel AND rc.fait_objectif_ref = v_ref);
      INSERT INTO public.renseignements_connus
        (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
         fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
      VALUES ('rp_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || substr(md5(random()::text),1,8),
              'cellule:' || a.cel,
              'Arrivage au port le ' || coalesce(left(v_arr ->> 'jour', 10), '?') || ' : ' ||
              coalesce(v_arr ->> 'qte', '?') || ' de ' || coalesce(v_arr ->> 'resource', '?') ||
              ', origine ' || coalesce(v_arr ->> 'origine', 'inconnue') || '.',
              a.bat_eff, 'fret_flux', a.nom_couverture, 'observation', v_ref, 0, 0, 2147483647);
      v_nb := v_nb + 1;
    END LOOP;
  END IF;

  IF v_nb > 0 THEN PERFORM public.agent_trace_deposer(p_agent_id); END IF;
  RETURN jsonb_build_object('ok', true, 'faits', v_nb);
END;
$function$

-- agent_deposer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agent_deposer(p_agent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT country, current_city, current_building, current_room INTO d
    FROM public.personnages_donnees WHERE name = v_moi;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_indefinie'); END IF;

  SELECT ag.*, c.statut AS statut_cellule INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id FOR UPDATE;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.leader_courant IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_agent'); END IF;
  IF a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_indisponible', 'statut', a.statut); END IF;

  UPDATE public.agents_renseignement
     SET leader_courant = NULL, pays = d.country, ville = d.current_city,
         building_id = d.current_building, room_id = d.current_room, maj_le = now()
   WHERE id = p_agent_id;
  RETURN jsonb_build_object('ok', true, 'agent', p_agent_id, 'pays', d.country,
    'ville', d.current_city, 'batiment', d.current_building, 'piece', d.current_room);
END;
$function$

-- agent_garde_observer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agent_garde_observer(p_agent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_reco constant numeric := 75;
  a record; r record;
  v_bande text; v_modif integer; v_camo numeric; v_chance integer; v_jet integer;
  v_ref text; v_deg jsonb; v_nb integer := 0;
BEGIN
  SELECT ag.*, c.statut AS statut_cellule, c.pays_proprietaire, c.id AS cel,
         pe.pays AS pays_eff, pe.ville AS ville_eff,
         pe.building_id AS bat_eff, pe.room_id AS room_eff
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE ag.id = p_agent_id AND ag.role = 'garde';
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.ville_eff IS NULL OR a.pays_eff IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_sans_position'); END IF;
  IF public.agent_au_bureau_min_def(a.bat_eff, a.room_eff) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_au_bureau'); END IF;

  FOR r IN
    SELECT m.pays AS pays_cible,
           m.ville AS ville, m.building_id AS bat,
           count(*)::integer AS effectif,
           avg(coalesce((sm.formation->>'reconnaissance')::numeric, 0)) AS reco_moy,
           count(*) FILTER (WHERE EXISTS (
             SELECT 1 FROM public.pnj_possessions p
              WHERE p.pnj_id = m.id AND p.origine = 'blob_accessoires'
                AND p.objet->>'produitMilitaire' = 'tenue_camouflage'))::integer AS equipes
      FROM public.pnj_membres m
      JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE m.famille = 'soldat' AND m.statut = 'actif'
       AND sm.en_reserve = false
       AND m.pays IS DISTINCT FROM a.pays_proprietaire
       AND coalesce(m.ville,'') = a.ville_eff
     GROUP BY 1, 2, 3
  LOOP
    v_bande := public.militaire_bande_distance(a.pays_eff, a.ville_eff, a.bat_eff,
                                               r.pays_cible, r.ville, r.bat);
    v_modif := public.militaire_modif_distance(v_bande);
    IF v_modif IS NULL THEN CONTINUE; END IF;
    v_camo   := public.militaire_camouflage_groupe(r.reco_moy, r.effectif, r.equipes);
    v_chance := public.militaire_chance_detection(c_reco, v_camo, v_modif, 0);
    v_jet    := floor(random() * 100)::integer + 1;
    CONTINUE WHEN v_jet > v_chance;

    v_ref := 'forces:' || r.pays_cible || ':' || r.ville || ':' || coalesce(r.bat, '-')
             || ':' || (now() AT TIME ZONE 'Europe/Paris')::date;
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.renseignements_connus rc
                           WHERE rc.titulaire = 'cellule:' || a.cel
                             AND rc.fait_objectif_ref = v_ref);

    v_deg := public.militaire_degrader(v_bande, r.effectif, r.pays_cible, r.ville, r.bat);
    INSERT INTO public.renseignements_connus
      (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
       fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
    VALUES ('rg_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' ||
            substr(md5(random()::text), 1, 8),
            'cellule:' || a.cel,
            'Forces reperees a ' || r.ville ||
            coalesce(' (' || (v_deg->>'batiment') || ')', '') || ' : ' ||
            (v_deg->>'libelle') || ' — ' ||
            CASE WHEN (v_deg->>'nationalite_sure')::boolean THEN (v_deg->>'nationalite')
                 ELSE 'nationalite incertaine' END || '.',
            r.pays_cible, 'renseignement_militaire', a.nom_couverture, 'observation',
            v_ref, 0, 0, 2147483647);
    v_nb := v_nb + 1;
  END LOOP;

  IF v_nb > 0 THEN PERFORM public.agent_trace_deposer(p_agent_id); END IF;
  RETURN jsonb_build_object('ok', true, 'faits', v_nb);
END;
$function$

-- agent_portrait_chemin(text,text) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.agent_portrait_chemin(p_role text, p_pays text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT 'images/personnages/' || CASE coalesce(p_role,'') || '|' || coalesce(p_pays,'republic')
    WHEN 'garde|republic'         THEN 'p-67740f3df7'
    WHEN 'garde|narco'            THEN 'p-1f148ae9f5'
    WHEN 'garde|soviet'           THEN 'p-221564b95c'
    WHEN 'garde|khalija'          THEN 'p-a085743493'
    WHEN 'traducteur|republic'    THEN 'p-9e88f09ad6'
    WHEN 'traducteur|narco'       THEN 'p-dd5ad03955'
    WHEN 'traducteur|soviet'      THEN 'p-98e6627171'
    WHEN 'traducteur|khalija'     THEN 'p-643e623f47'
    WHEN 'conseiller|republic'    THEN 'p-5669ed962a'
    WHEN 'conseiller|narco'       THEN 'p-3ff97a66be'
    WHEN 'conseiller|soviet'      THEN 'p-94c4b18cd9'
    WHEN 'conseiller|khalija'     THEN 'p-bf4a001945'
    WHEN 'coordinateur|republic'  THEN 'p-84f967d6cd'
    WHEN 'coordinateur|narco'     THEN 'p-3ce0e49fa3'
    WHEN 'coordinateur|soviet'    THEN 'p-6ec78181dc'
    WHEN 'coordinateur|khalija'   THEN 'p-9e17eaed14'
    ELSE 'p-inconnu'
  END || '.png';
$function$

-- agent_position_effective(text) -> TABLE(pays text, ville text, building_id text, room_id text, porte boolean) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agent_position_effective(p_agent_id text)
 RETURNS TABLE(pays text, ville text, building_id text, room_id text, porte boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT
    CASE WHEN ag.leader_courant IS NULL THEN ag.pays        ELSE d.country          END,
    CASE WHEN ag.leader_courant IS NULL THEN ag.ville       ELSE d.current_city     END,
    CASE WHEN ag.leader_courant IS NULL THEN ag.building_id ELSE d.current_building END,
    CASE WHEN ag.leader_courant IS NULL THEN ag.room_id     ELSE d.current_room     END,
    ag.leader_courant IS NOT NULL
  FROM public.agents_renseignement ag
  LEFT JOIN public.personnages_donnees d ON d.name = ag.leader_courant
  WHERE ag.id = p_agent_id;
$function$

-- agent_prendre(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agent_prendre(p_agent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT country, current_city, current_building, current_room INTO d
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT ag.*, c.pays_proprietaire, c.ministre, c.statut AS statut_cellule INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id FOR UPDATE;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cellule_inactive'); END IF;
  IF a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_indisponible', 'statut', a.statut); END IF;
  IF a.leader_courant IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_en_groupe', 'leader', a.leader_courant); END IF;

  IF a.ville IS NULL THEN
    IF d.country IS DISTINCT FROM a.pays_proprietaire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_empire');
    END IF;
  ELSE
    IF d.current_building IS NULL OR d.current_room IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'position_indefinie'); END IF;
    -- Co-presence PHYSIQUE COMPLETE, pays reel inclus. Avant cette migration le pays n'etait
    -- pas compare (il etait suppose egal a la couverture) ; deux villes homonymes dans deux
    -- empires auraient suffi a reprendre un agent a distance.
    IF d.country IS DISTINCT FROM a.pays
       OR d.current_city IS DISTINCT FROM a.ville
       OR d.current_building IS DISTINCT FROM a.building_id
       OR d.current_room IS DISTINCT FROM a.room_id THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit');
    END IF;
    IF d.country IS DISTINCT FROM a.pays_proprietaire AND v_moi IS DISTINCT FROM a.ministre THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_empire');
    END IF;
  END IF;

  UPDATE public.agents_renseignement
     SET leader_courant = v_moi, pays = NULL, ville = NULL,
         building_id = NULL, room_id = NULL, maj_le = now()
   WHERE id = p_agent_id;
  RETURN jsonb_build_object('ok', true, 'agent', p_agent_id, 'leader', v_moi);
END;
$function$

-- agent_trace_deposer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agent_trace_deposer(p_agent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  a record; v_risque integer; v_jet integer; v_jour integer; v_id text;
BEGIN
  SELECT ag.id, COALESCE(m.car_dup, ag.dup) AS dup, ag.nom_couverture, ag.statut,
         c.statut AS statut_cellule,
         pe.pays AS pays_eff, pe.ville AS ville_eff,
         pe.building_id AS bat_eff, pe.room_id AS room_eff
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN public.pnj_membres m ON m.id = ag.pnj_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE ag.id = p_agent_id;

  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.ville_eff IS NULL OR a.pays_eff IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_sans_position'); END IF;
  IF public.agent_au_bureau_min_def(a.bat_eff, a.room_eff) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_au_bureau'); END IF;

  v_risque := greatest(5, 30 - coalesce(a.dup, 8));
  v_jet    := floor(random() * 100)::integer + 1;
  IF v_jet > v_risque THEN
    RETURN jsonb_build_object('ok', true, 'trace', false, 'risque', v_risque);
  END IF;

  v_jour := public.jour_de_jeu_pays(a.pays_eff);
  v_id   := 'agent-' || a.id || '-j' || v_jour;

  -- La trace porte la COUVERTURE, jamais le vrai nom. Invariant de confidentialite conserve.
  INSERT INTO public.actions_tracables
    (id, auteur, cible, type_action, country, city, jour, jour_expiration, decouvert)
  VALUES (v_id, a.nom_couverture, NULL, 'presence_suspecte',
          a.pays_eff, a.ville_eff, v_jour, v_jour + 7, false)
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'trace', true, 'risque', v_risque, 'reference', v_id);
END; $function$

-- agent_traducteur_ecouter(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agent_traducteur_ecouter(p_agent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_max constant integer := 3;
  a record; t record; v_jour integer; v_nb integer := 0; v_ref text;
BEGIN
  SELECT ag.*, c.statut AS statut_cellule, c.id AS cel,
         pe.pays AS pays_eff, pe.ville AS ville_eff,
         pe.building_id AS bat_eff, pe.room_id AS room_eff
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE ag.id = p_agent_id AND ag.role = 'traducteur';
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.ville_eff IS NULL OR a.pays_eff IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_sans_position'); END IF;
  IF public.agent_au_bureau_min_def(a.bat_eff, a.room_eff) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_au_bureau'); END IF;

  v_jour := public.jour_de_jeu_pays(a.pays_eff);

  FOR t IN
    SELECT at.id, at.auteur, at.cible, at.type_action, at.jour
      FROM public.actions_tracables at
     WHERE at.country = a.pays_eff
       AND at.city = a.ville_eff
       AND at.jour_expiration >= v_jour
       AND at.auteur <> a.nom_couverture
       AND NOT EXISTS (SELECT 1 FROM public.renseignements_connus rc
                        WHERE rc.titulaire = 'cellule:' || a.cel
                          AND rc.fait_objectif_ref = 'actions_tracables:' || at.id)
     ORDER BY random() * (1 + (at.jour::numeric / greatest(v_jour, 1))) DESC
     LIMIT c_max
  LOOP
    v_ref := 'actions_tracables:' || t.id;
    INSERT INTO public.renseignements_connus
      (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
       fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
    VALUES ('rt_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' ||
            substr(md5(random()::text), 1, 8),
            'cellule:' || a.cel,
            'On rapporte a ' || a.ville_eff || ' que ' || t.auteur || ' serait implique dans : '
              || t.type_action || coalesce(' (vise : ' || t.cible || ')', '') || '.',
            t.auteur, 'rumeur_locale', a.nom_couverture, 'observation',
            v_ref, 0, 0, 2147483647);
    v_nb := v_nb + 1;
  END LOOP;

  IF v_nb > 0 THEN PERFORM public.agent_trace_deposer(p_agent_id); END IF;
  RETURN jsonb_build_object('ok', true, 'faits', v_nb);
END;
$function$

-- agent_transferer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agent_transferer(p_agent_id text, p_destinataire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; e record; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_destinataire), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_absent'); END IF;
  IF p_destinataire = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_est_moi'); END IF;

  SELECT country, current_city, current_building, current_room INTO d
    FROM public.personnages_donnees WHERE name = v_moi;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_indefinie'); END IF;

  SELECT country, current_city, current_building, current_room INTO e
    FROM public.personnages_donnees WHERE name = p_destinataire;
  IF e.current_building IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;

  -- CO-PRESENCE EXIGEE : on ne confie pas quelqu'un a distance.
  IF e.country IS DISTINCT FROM d.country
     OR e.current_city IS DISTINCT FROM d.current_city
     OR e.current_building IS DISTINCT FROM d.current_building
     OR e.current_room IS DISTINCT FROM d.current_room THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit');
  END IF;

  SELECT ag.*, c.statut AS statut_cellule INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id FOR UPDATE;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cellule_inactive'); END IF;
  IF a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_indisponible', 'statut', a.statut); END IF;
  IF a.leader_courant IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_agent'); END IF;

  -- Le rattachement a l'operation (cellule_id) n'est PAS touche : seul le porteur change.
  UPDATE public.agents_renseignement
     SET leader_courant = p_destinataire, pays = NULL, ville = NULL,
         building_id = NULL, room_id = NULL, maj_le = now()
   WHERE id = p_agent_id;

  RETURN jsonb_build_object('ok', true, 'agent', p_agent_id, 'nouveau_leader', p_destinataire);
END;
$function$

-- agents_couverture_de_mon_groupe() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agents_couverture_de_mon_groupe()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', ag.id, 'nom', ag.nom_couverture,
           'portrait', public.agent_portrait_chemin(ag.role, ag.pays_couverture))
           ORDER BY ag.nom_couverture), '[]'::jsonb)
    INTO v_res
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.leader_courant = v_moi AND ag.statut = 'actif' AND c.statut = 'active';
  RETURN jsonb_build_object('ok', true, 'agents', v_res);
END;
$function$

-- agents_couverture_ici() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agents_couverture_ici()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d
    FROM public.personnages_donnees WHERE name = v_moi;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'agents', '[]'::jsonb); END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', ag.id, 'nom', ag.nom_couverture,
           'portrait', public.agent_portrait_chemin(ag.role, ag.pays_couverture))
           ORDER BY ag.nom_couverture), '[]'::jsonb)
    INTO v_res
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.statut = 'actif' AND c.statut = 'active'
     AND ag.leader_courant IS NULL
     AND ag.pays        IS NOT DISTINCT FROM d.country
     AND ag.ville       IS NOT DISTINCT FROM d.current_city
     AND ag.building_id IS NOT DISTINCT FROM d.current_building
     AND ag.room_id     IS NOT DISTINCT FROM d.current_room;
  RETURN jsonb_build_object('ok', true, 'agents', v_res);
END;
$function$

-- agents_de_mon_groupe() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agents_de_mon_groupe()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', ag.id, 'couverture', ag.nom_couverture, 'role', ag.role, 'statut', ag.statut)
           ORDER BY ag.role), '[]'::jsonb)
    INTO v_res FROM public.agents_renseignement ag
   WHERE ag.leader_courant = v_moi;
  RETURN jsonb_build_object('ok', true, 'agents', v_res);
END;
$function$

-- agents_renseignement_ici() -> TABLE(nom_couverture text) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.agents_renseignement_ici()
 RETURNS TABLE(nom_couverture text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_bat text; v_room text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN; END IF;

  SELECT d.country, d.current_city, d.current_building, d.current_room
    INTO v_pays, v_ville, v_bat, v_room
    FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_pays IS NULL OR v_bat IS NULL OR v_room IS NULL THEN RETURN; END IF;

  RETURN QUERY
    SELECT a.nom_couverture
      FROM public.agents_renseignement a
      LEFT JOIN LATERAL public.agent_position_effective(a.id) pe ON true
     WHERE a.statut = 'actif'
       AND pe.pays        IS NOT DISTINCT FROM v_pays
       AND pe.ville       IS NOT DISTINCT FROM v_ville
       AND pe.building_id IS NOT DISTINCT FROM v_bat
       AND pe.room_id     IS NOT DISTINCT FROM v_room
       AND a.leader_courant IS DISTINCT FROM v_moi   -- on ne se detecte pas soi-meme
     ORDER BY a.nom_couverture;
END;
$function$

-- cellule_alerter_ministre(text,text,text,text) -> void | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cellule_alerter_ministre(p_cellule_id text, p_couverture text, p_sujet text, p_corps text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text; v_destinataire text;
BEGIN
  SELECT c.pays_proprietaire INTO v_pays
    FROM public.cellules_renseignement c WHERE c.id = p_cellule_id;
  IF v_pays IS NULL THEN RETURN; END IF;

  -- Titulaire reel du poste : un PJ s'il y en a un, sinon le PNJ du registre.
  SELECT d.name INTO v_destinataire FROM public.personnages_donnees d
   WHERE d.country = v_pays AND d.poste ->> 'id' = 'min_def' LIMIT 1;
  IF v_destinataire IS NULL THEN
    SELECT t.nom_pnj INTO v_destinataire FROM public.titulaires_pnj t
     WHERE t.country = v_pays AND t.poste_id = 'min_def' LIMIT 1;
  END IF;
  IF v_destinataire IS NULL THEN RETURN; END IF;

  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES ('ce-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
          substr(md5(random()::text), 1, 6),
          'Service de renseignement', v_destinataire, p_sujet, p_corps,
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);
END;
$function$

-- cellule_rapports_mes_cellules(integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cellule_rapports_mes_cellules(p_limite integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_pays text; v_res jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;

  SELECT coalesce(jsonb_agg(x ORDER BY x ->> 'jour' DESC), '[]'::jsonb) INTO v_res
    FROM (SELECT rc.contenu || jsonb_build_object('nb_faits', rc.nb_faits) AS x
            FROM public.rapports_cellules rc
            JOIN public.cellules_renseignement c ON c.id = rc.cellule_id
           WHERE c.pays_proprietaire = v_pays
           ORDER BY rc.jour DESC
           LIMIT greatest(1, least(coalesce(p_limite, 10), 60))) s;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'rapports', v_res);
END;
$function$

-- cellule_renseignement_clore(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cellule_renseignement_clore(p_cellule_id text, p_mode text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_statut text; v_evades integer := 0; v_disparus integer := 0; v_morts integer := 0;
BEGIN
  SELECT c.statut INTO v_statut FROM public.cellules_renseignement c
   WHERE c.id = p_cellule_id FOR UPDATE;
  IF v_statut IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cellule_introuvable');
  END IF;
  IF v_statut <> 'active' THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'cellule_deja_close');
  END IF;

  SELECT count(*) INTO v_morts FROM public.agents_renseignement
   WHERE cellule_id = p_cellule_id AND statut = 'mort';

  -- Agents DETENUS : la detention est CLOTUREE, jamais supprimee. Le registre
  -- affichera donc « Evasion », et l'histoire de la detention reste lisible.
  WITH detenus AS (
    SELECT id, detention_id FROM public.agents_renseignement
     WHERE cellule_id = p_cellule_id AND statut = 'detenu'
  ), fermeture AS (
    UPDATE public.detentions d
       SET mode_fin = 'evasion',
           jour_fin_effective = public.jour_de_jeu_pays(d.country),
           date_fin_effective = now()
      FROM detenus x
     WHERE d.id = x.detention_id AND d.mode_fin IS NULL
    RETURNING d.id
  )
  SELECT count(*) INTO v_evades FROM fermeture;

  UPDATE public.agents_renseignement
     SET statut = 'disparu', leader_courant = NULL,
         ville = NULL, building_id = NULL, room_id = NULL, maj_le = now()
   WHERE cellule_id = p_cellule_id AND statut IN ('actif', 'detenu');
  GET DIAGNOSTICS v_disparus = ROW_COUNT;

  UPDATE public.cellules_renseignement
     SET statut = CASE WHEN p_mode = 'echec_agents' THEN 'echec' ELSE 'terminee' END,
         mode_fin = p_mode, terminee_le = now()
   WHERE id = p_cellule_id;

  RETURN jsonb_build_object('ok', true, 'cellule', p_cellule_id, 'mode_fin', p_mode,
    'agents_disparus', v_disparus, 'evasions', v_evades, 'morts', v_morts);
END;
$function$

-- cellule_renseignement_creer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cellule_renseignement_creer(p_pays_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa   constant integer := 3;
  c_cout constant numeric := 500;
  v_nom text; v_poste text; v_pays text;
  v_pa integer; v_caisse text; v_mvt jsonb;
  v_cellule text; v_echeance timestamptz;
  v_nb_id integer; v_libres_h integer; v_libres_f integer;
  v_besoin_h integer; v_besoin_f integer;
  v_agents jsonb := '[]'::jsonb;
  r record; v_couv text; v_prec text; v_idx integer := 0;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  IF p_pays_cible IS NULL OR btrim(p_pays_cible) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'couverture_absente'); END IF;

  SELECT count(*) INTO v_nb_id FROM public.renseignement_identites_reelles;
  IF v_nb_id < 4 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'identites_reelles_incompletes',
                              'definies', v_nb_id, 'attendues', 4); END IF;

  SELECT count(*) FILTER (WHERE sexe = 'H'), count(*) FILTER (WHERE sexe = 'F')
    INTO v_besoin_h, v_besoin_f FROM public.renseignement_identites_reelles;

  SELECT count(*) FILTER (WHERE c.sexe = 'H'), count(*) FILTER (WHERE c.sexe = 'F')
    INTO v_libres_h, v_libres_f
    FROM public.renseignement_couvertures c
   WHERE c.pays = p_pays_cible
     AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                      WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                        AND a.statut IN ('actif', 'detenu'));
  IF v_libres_h < v_besoin_h OR v_libres_f < v_besoin_f THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pool_couvertures_insuffisant',
      'libres_h', v_libres_h, 'requis_h', v_besoin_h,
      'libres_f', v_libres_f, 'requis_f', v_besoin_f); END IF;

  SELECT coalesce(pa, 0) INTO v_pa FROM public.personnages_donnees WHERE name = v_nom FOR UPDATE;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', c_pa, 'disponibles', v_pa); END IF;

  v_caisse := v_pays || '_gouvernement-min_def';
  v_mvt := public.caisse_institution_mouvement(v_caisse, -c_cout, false);
  IF coalesce((v_mvt ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
      'caisse', v_caisse, 'requis', c_cout, 'detail', v_mvt ->> 'raison'); END IF;

  UPDATE public.personnages_donnees SET pa = v_pa - c_pa WHERE name = v_nom;

  v_cellule  := 'cel-' || (extract(epoch from clock_timestamp())*1000)::bigint
                       || '-' || substr(md5(random()::text), 1, 6);
  v_echeance := now() + interval '10 days';

  INSERT INTO public.cellules_renseignement
    (id, pays_proprietaire, pays_cible, ministre, statut, cout_fr, caisse, echeance_le)
  VALUES (v_cellule, v_pays, p_pays_cible, v_nom, 'active', c_cout, v_caisse, v_echeance);

  FOR r IN SELECT role, vrai_nom, dup, sexe
             FROM public.renseignement_identites_reelles ORDER BY role
  LOOP
    SELECT a.nom_couverture INTO v_prec
      FROM public.agents_renseignement a
      JOIN public.cellules_renseignement c2 ON c2.id = a.cellule_id
     WHERE a.role = r.role AND a.pays_couverture = p_pays_cible
       AND c2.pays_proprietaire = v_pays
     ORDER BY a.cree_le DESC LIMIT 1;

    SELECT c.nom INTO v_couv
      FROM public.renseignement_couvertures c
     WHERE c.pays = p_pays_cible
       AND c.sexe IS NOT DISTINCT FROM r.sexe
       AND c.nom IS DISTINCT FROM coalesce(v_prec, '')
       AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                        WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                          AND a.statut IN ('actif', 'detenu'))
     ORDER BY random() LIMIT 1;

    IF v_couv IS NULL THEN
      SELECT c.nom INTO v_couv
        FROM public.renseignement_couvertures c
       WHERE c.pays = p_pays_cible
         AND c.sexe IS NOT DISTINCT FROM r.sexe
         AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                          WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                            AND a.statut IN ('actif', 'detenu'))
       ORDER BY random() LIMIT 1;
    END IF;
    IF v_couv IS NULL THEN RAISE EXCEPTION 'pool_couvertures_epuise'; END IF;

    v_idx := v_idx + 1;
    INSERT INTO public.agents_renseignement
      (id, cellule_id, role, vrai_nom, dup, pays_couverture, nom_couverture, statut, leader_courant)
    VALUES (v_cellule || '-a' || v_idx, v_cellule, r.role, r.vrai_nom, r.dup,
            p_pays_cible, v_couv, 'actif', v_nom);
    v_agents := v_agents || jsonb_build_array(jsonb_build_object(
      'role', r.role, 'vrai_nom', r.vrai_nom, 'couverture', v_couv,
      'sexe', r.sexe, 'dup', r.dup, 'statut', 'actif'));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'cellule', v_cellule, 'pays_couverture', p_pays_cible,
    'pays_cible', p_pays_cible, 'echeance', v_echeance, 'cout', c_cout, 'caisse', v_caisse,
    'pa_restants', v_pa - c_pa, 'agents', v_agents);
END;
$function$

-- cellule_renseignement_mes_cellules() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cellule_renseignement_mes_cellules()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_pays text; v_res jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  SELECT coalesce(jsonb_agg(x ORDER BY x ->> 'cree_le' DESC), '[]'::jsonb) INTO v_res
  FROM (
    SELECT jsonb_build_object(
      'cellule', c.id, 'pays_couverture', c.pays_cible, 'pays_cible', c.pays_cible,
      'statut', c.statut, 'mode_fin', c.mode_fin, 'cree_le', c.cree_le,
      'echeance', c.echeance_le, 'terminee_le', c.terminee_le,
      'agents', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                    'id', ag.id, 'role', ag.role, 'vrai_nom', ag.vrai_nom,
                    'couverture', ag.nom_couverture, 'dup', ag.dup, 'statut', ag.statut,
                    'leader', ag.leader_courant,
                    'pays', pe.pays, 'ville', pe.ville,
                    'batiment', pe.building_id, 'piece', pe.room_id,
                    'porte', pe.porte,
                    'au_bureau', public.agent_au_bureau_min_def(pe.building_id, pe.room_id),
                    'portrait', public.agent_portrait_chemin(ag.role, ag.pays_couverture))
                    ORDER BY ag.role), '[]'::jsonb)
                   FROM public.agents_renseignement ag
                   LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
                  WHERE ag.cellule_id = c.id)
    ) AS x
    FROM public.cellules_renseignement c
   WHERE c.pays_proprietaire = v_pays
  ) s;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'cellules', v_res);
END;
$function$

-- cellule_renseignement_terminer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cellule_renseignement_terminer(p_cellule_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_pays text; v_proprio text;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  SELECT c.pays_proprietaire INTO v_proprio
    FROM public.cellules_renseignement c WHERE c.id = p_cellule_id;
  IF v_proprio IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cellule_introuvable');
  END IF;
  IF v_proprio IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cellule_d_un_autre_empire');
  END IF;
  -- Aucun remboursement : le cout n'est jamais rendu.
  RETURN public.cellule_renseignement_clore(p_cellule_id, 'volontaire');
END;
$function$

-- cellules_rapports_generer() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cellules_rapports_generer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c record; v_jour date := ((now() AT TIME ZONE 'Europe/Paris')::date - 1);
  v_faits jsonb; v_n integer := 0; v_nb integer;
BEGIN
  FOR c IN SELECT id, pays_proprietaire, pays_cible
             FROM public.cellules_renseignement WHERE statut = 'active'
  LOOP
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.rapports_cellules rc
                           WHERE rc.cellule_id = c.id AND rc.jour = v_jour);

    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'categorie', r.categorie, 'fait', r.contenu, 'source', r.source)
             ORDER BY r.categorie, r.created_at), '[]'::jsonb)
      INTO v_faits
      FROM public.renseignements_connus r
     WHERE r.titulaire = 'cellule:' || c.id
       AND r.jour_observe = v_jour;

    INSERT INTO public.rapports_cellules (cellule_id, jour, contenu, nb_faits)
    VALUES (c.id, v_jour,
            jsonb_build_object('cellule', c.id, 'pays_cible', c.pays_cible,
                               'jour', v_jour, 'faits', v_faits),
            jsonb_array_length(v_faits))
    ON CONFLICT (cellule_id, jour) DO NOTHING;

    -- Le nombre est lu UNE fois et sert a la fois au chiffre et a l'accord.
    v_nb := jsonb_array_length(v_faits);

    PERFORM public.cellule_alerter_ministre(c.id, NULL,
      'Rapport de renseignement du ' || to_char(v_jour, 'DD/MM/YYYY'),
      'Le rapport quotidien de votre cellule ' || c.id ||
      ' est disponible dans votre Bureau du Ministre de la Défense, rubrique ' ||
      '« Renseignement militaire » → « Lire les rapports ». ' ||
      v_nb || CASE WHEN v_nb > 1 THEN ' faits consignés.' ELSE ' fait consigné.' END);
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'rapports', v_n);
END;
$function$

-- cellules_renseignement_balayer() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cellules_renseignement_balayer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_nat integer := 0; v_ech integer := 0;
BEGIN
  -- Echec : les quatre agents morts.
  FOR r IN SELECT c.id FROM public.cellules_renseignement c
            WHERE c.statut = 'active'
              AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                               WHERE a.cellule_id = c.id AND a.statut <> 'mort')
  LOOP
    PERFORM public.cellule_renseignement_clore(r.id, 'echec_agents');
    v_ech := v_ech + 1;
  END LOOP;

  -- Echeance atteinte.
  FOR r IN SELECT c.id FROM public.cellules_renseignement c
            WHERE c.statut = 'active' AND c.echeance_le <= now()
  LOOP
    PERFORM public.cellule_renseignement_clore(r.id, 'naturelle');
    v_nat := v_nat + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'fins_naturelles', v_nat, 'echecs', v_ech);
END;
$function$

-- cellules_renseignement_collecter() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cellules_renseignement_collecter()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_n integer := 0; v_faits integer := 0; v_res jsonb; v_res2 jsonb;
BEGIN
  FOR r IN
    SELECT a.id, a.role FROM public.agents_renseignement a
      JOIN public.cellules_renseignement c ON c.id = a.cellule_id
      LEFT JOIN LATERAL public.agent_position_effective(a.id) pe ON true
     WHERE c.statut = 'active' AND a.statut = 'actif'
       AND pe.ville IS NOT NULL AND pe.pays IS NOT NULL
       AND NOT public.agent_au_bureau_min_def(pe.building_id, pe.room_id)
  LOOP
    IF r.role = 'coordinateur' THEN
      v_res  := public.agent_coordinateur_multimodal(r.id);
      v_res2 := public.agent_coordinateur_port(r.id);
      v_faits := v_faits + coalesce((v_res ->> 'faits')::integer, 0)
                         + coalesce((v_res2 ->> 'faits')::integer, 0);
    ELSE
      v_res := CASE r.role
        WHEN 'garde'      THEN public.agent_garde_observer(r.id)
        WHEN 'traducteur' THEN public.agent_traducteur_ecouter(r.id)
        WHEN 'conseiller' THEN public.agent_conseillere_observer(r.id)
      END;
      v_faits := v_faits + coalesce((v_res ->> 'faits')::integer, 0);
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'agents', v_n, 'faits', v_faits);
END;
$function$

-- contre_espionnage_approfondir(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.contre_espionnage_approfondir(p_couverture text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_pays text; v_statut text;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS NULL OR v_poste NOT IN ('commissaire', 'juge') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  SELECT ag.statut INTO v_statut
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE pe.pays IS NOT DISTINCT FROM v_pays AND ag.nom_couverture = p_couverture
     AND c.statut = 'active';
  IF v_statut IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_inconnue');
  END IF;
  IF v_statut <> 'detenu' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_detenue');
  END IF;

  BEGIN
    INSERT INTO public.contre_espionnage_tentatives (pays, couverture, jour_paris, instructeur)
    VALUES (v_pays, p_couverture, (now() AT TIME ZONE 'Europe/Paris')::date, v_nom);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_tente_aujourdhui');
  END;

  RETURN public.contre_espionnage_resoudre(v_pays, p_couverture, v_nom, 'detention');
END;
$function$

-- contre_espionnage_dossiers() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.contre_espionnage_dossiers()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_pays text; v_res jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS NULL OR v_poste NOT IN ('min_int', 'commissaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'couverture', d.cible,
           'niveau', d.niveau,
           'faits', d.faits) ORDER BY d.cible), '[]'::jsonb)
    INTO v_res
    FROM (
      SELECT r.cible,
             max(substring(r.categorie from 'contre_espionnage_niveau_(\d)')::integer) AS niveau,
             jsonb_agg(r.contenu ORDER BY r.categorie) AS faits
        FROM public.renseignements_connus r
       WHERE r.titulaire = 'etat:' || v_pays
         AND r.categorie LIKE 'contre_espionnage_niveau_%'
       GROUP BY r.cible
    ) d;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'poste', v_poste, 'dossiers', v_res);
END;
$function$

-- contre_espionnage_memoriser(text,text,integer,text,text,text,text) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.contre_espionnage_memoriser(p_pays text, p_couverture text, p_niveau integer, p_vrai_nom text, p_pays_agent text, p_instructeur text, p_ref text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_jamais constant integer := 2147483647;
  v_connu integer; v_n integer; v_texte text;
BEGIN
  v_connu := public.contre_espionnage_niveau_connu(p_pays, p_couverture);
  IF coalesce(p_niveau, 0) <= v_connu THEN
    RETURN v_connu;                      -- rien de neuf : le dossier est intact
  END IF;

  FOR v_n IN (v_connu + 1) .. p_niveau LOOP
    v_texte := CASE v_n
      WHEN 1 THEN 'L''identite publique « ' || p_couverture || ' » est une fausse identite.'
      WHEN 2 THEN '« ' || p_couverture || ' » est un agent etranger.'
      WHEN 3 THEN 'Sous l''identite « ' || p_couverture || ' » se cache ' || coalesce(p_vrai_nom, 'un inconnu') || '.'
      WHEN 4 THEN '« ' || p_couverture || ' » travaille pour ' || coalesce(p_pays_agent, 'une puissance etrangere') || '.'
    END;
    INSERT INTO public.renseignements_connus
      (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
       fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
    VALUES ('ce_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || v_n
              || '_' || substr(md5(random()::text), 1, 6),
            'etat:' || p_pays, v_texte, p_couverture,
            'contre_espionnage_niveau_' || v_n,
            coalesce(p_instructeur, 'enquete'), 'interrogatoire',
            p_ref, 0, 0, c_jamais);
  END LOOP;
  RETURN p_niveau;
END;
$function$

-- contre_espionnage_modificateur(numeric,numeric,numeric) -> integer | sql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.contre_espionnage_modificateur(p_per_commissaire numeric, p_dup_agent numeric, p_is_national numeric)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT round(3 * (coalesce(p_per_commissaire, 8) - coalesce(p_dup_agent, 8))
             + (coalesce(p_is_national, 50) - 50) / 2.0)::integer;
$function$

-- contre_espionnage_niveau_connu(text,text) -> integer | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.contre_espionnage_niveau_connu(p_pays text, p_couverture text)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(max(substring(r.categorie from 'contre_espionnage_niveau_(\d)')::integer), 0)
    FROM public.renseignements_connus r
   WHERE r.titulaire = 'etat:' || p_pays
     AND r.cible = p_couverture
     AND r.categorie LIKE 'contre_espionnage_niveau_%';
$function$

-- contre_espionnage_palier(integer) -> integer | sql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.contre_espionnage_palier(p_score integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN p_score IS NULL THEN 0
    WHEN p_score >= 92 THEN 4
    WHEN p_score >= 85 THEN 3
    WHEN p_score >= 70 THEN 2
    WHEN p_score >= 50 THEN 1
    ELSE 0
  END;
$function$

-- contre_espionnage_resoudre(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.contre_espionnage_resoudre(p_pays text, p_couverture text, p_instructeur text, p_ref text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ag record; v_per numeric; v_is numeric;
  v_mod integer; v_de integer; v_score integer; v_palier integer;
  v_avant integer; v_apres integer;
BEGIN
  SELECT COALESCE(m.car_dup, ag.dup) AS dup, ag.vrai_nom, ag.nom_couverture, c.pays_proprietaire
    INTO v_ag
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN public.pnj_membres m ON m.id = ag.pnj_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE pe.pays IS NOT DISTINCT FROM p_pays
     AND ag.nom_couverture = p_couverture
     AND ag.statut IN ('actif', 'detenu')
     AND c.statut = 'active';
  IF v_ag.dup IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_agent');
  END IF;

  SELECT public.assemblee_stat_base(d.stats, 'PER') INTO v_per
    FROM public.personnages_donnees d WHERE d.name = p_instructeur;
  v_per := coalesce(v_per, 8);
  v_is  := public.is_national(p_pays);

  v_mod    := public.contre_espionnage_modificateur(v_per, v_ag.dup, v_is);
  v_de     := floor(random() * 100)::integer + 1;
  v_score  := greatest(0, least(100, v_de + v_mod));
  v_palier := public.contre_espionnage_palier(v_score);

  v_avant := public.contre_espionnage_niveau_connu(p_pays, p_couverture);
  v_apres := public.contre_espionnage_memoriser(p_pays, p_couverture, v_palier,
               v_ag.vrai_nom, v_ag.pays_proprietaire, p_instructeur, p_ref);

  RETURN jsonb_build_object('ok', true, 'score', v_score, 'palier', v_palier,
    'niveau_avant', v_avant, 'niveau', v_apres,
    'progression', v_apres > v_avant);
END; $function$

-- convocation_douane_emettre(text,text,integer,integer,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.convocation_douane_emettre(p_cible text, p_motif text, p_jour_emission integer, p_heure_emission integer, p_jour_limite integer, p_heure_limite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_acteur text; v_liste jsonb; v_conv jsonb; v_id text; v_deja boolean;
BEGIN
  -- Leve si le compte connecte n'est pas le Chef des Douanes en exercice.
  v_acteur := public.exiger_poste('chef_douanes');
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF COALESCE(btrim(p_cible), '') = '' OR COALESCE(btrim(p_motif), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT convocations INTO v_liste FROM public.personnages_donnees
   WHERE name = p_cible FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;
  IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;

  -- Meme motif, meme jour d'emission, non traitee : c'est la meme convocation.
  SELECT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_liste) e
     WHERE e->>'motif' = p_motif
       AND COALESCE((e->>'jourEmission')::integer, -1) = COALESCE(p_jour_emission, -1)
       AND COALESCE((e->>'traitee')::boolean, false) = false
  ) INTO v_deja;
  IF v_deja THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'cible', p_cible);
  END IF;

  v_id := 'conv-' || replace(gen_random_uuid()::text, '-', '');
  v_conv := jsonb_build_object(
    'id', v_id, 'motif', p_motif,
    'jourEmission', p_jour_emission, 'heureEmission', p_heure_emission,
    'jourLimite', p_jour_limite, 'heureLimite', p_heure_limite,
    'traitee', false, 'emisePar', v_acteur);

  UPDATE public.personnages_donnees
     SET convocations = v_liste || jsonb_build_array(v_conv), updated_at = now()
   WHERE name = p_cible;

  RETURN jsonb_build_object('ok', true, 'convocation', v_conv, 'cible', p_cible, 'acteur', v_acteur);
END;
$function$

-- douane_autorite_de_perimetre(text,text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.douane_autorite_de_perimetre(p_pays text, p_perimetre text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text;
BEGIN
  -- Le service des douanes est unique et fige. Un perimetre inconnu n'ouvre aucune autorite.
  IF p_perimetre IS DISTINCT FROM 'ville_a:port-sainte-marie' THEN RETURN NULL; END IF;
  SELECT pd.name INTO v_nom
    FROM public.personnages_donnees pd
   WHERE COALESCE(pd.country, 'republic') = p_pays
     AND pd.poste->>'id' = 'chef_douanes'
   ORDER BY pd.name
   LIMIT 1;
  RETURN v_nom;              -- NULL legitime : aucun PJ ne porte le poste aujourd'hui.
END; $function$

-- douane_caracteristiques_metier() -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.douane_caracteristiques_metier()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.pnj_metier_profil('douanier');
$function$

-- douane_effectifs_publics() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.douane_effectifs_publics()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT COALESCE(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  -- L'ordre reproduit celui du tableau d'origine : anciennete, puis matricule.
  RETURN jsonb_build_object('ok', true, 'douaniers', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'matricule', fp.matricule, 'type', fp.type_unite,
             'maitreNom', fp.maitre_nom, 'chienNom', fp.chien_nom)
             ORDER BY fp.recrute_le, fp.matricule)
      FROM public.pnj_membres m
      JOIN public.pnj_force_publique_metier fp ON fp.pnj_id = m.id
     WHERE m.famille = 'douanier' AND m.pays = v_pays AND m.statut = 'actif'
  ), '[]'::jsonb));
END; $function$

-- douane_payer_effectifs(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.douane_payer_effectifs(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_cout_standard  constant integer := 50;
  c_cout_cynophile constant integer := 100;
  c_ville    constant text := 'ville_a';
  c_batiment constant text := 'port-sainte-marie';
  v_serveur boolean; v_moi text; v_poste text;
  v_id text; v_data jsonb; v_etat jsonb; v_eff jsonb; v_liste jsonb;
  v_jour date; v_deja text;
  v_du numeric := 0; v_verse numeric; v_r jsonb;
  v_n integer; v_gardes integer := 0; v_cumul numeric := 0; v_el jsonb;
  v_caisse text;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  v_serveur := public.est_appel_serveur();
  IF NOT v_serveur THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT (poste->>'id') INTO v_poste FROM public.personnages_donnees WHERE name = v_moi;
    IF v_poste IS DISTINCT FROM 'chef_douanes' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees
                    WHERE name = v_moi AND country = p_pays) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_hors_autorite');
    END IF;
  END IF;

  v_jour   := ((now() AT TIME ZONE 'Europe/Paris')::date - 1);
  v_id     := p_pays || '_' || c_ville || '_' || c_batiment;
  v_caisse := p_pays || '_gouvernement-min_int';

  SELECT data INTO v_data FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'aucun_service', 'verse', 0);
  END IF;
  v_etat := COALESCE(public.batiment_etat_lire(v_data), '{}'::jsonb);
  v_eff  := v_etat -> 'effectifsDouane';
  IF v_eff IS NULL OR jsonb_typeof(v_eff) <> 'object' THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'aucun_service', 'verse', 0);
  END IF;

  v_deja := v_eff ->> 'dernierPaiementJour';
  IF v_deja = v_jour::text THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'deja_paye', 'jour', v_jour, 'verse', 0);
  END IF;

  v_liste := COALESCE(v_eff -> 'douaniers', '[]'::jsonb);
  IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;
  v_n := jsonb_array_length(v_liste);
  IF v_n = 0 THEN
    v_etat := jsonb_set(v_etat, ARRAY['effectifsDouane','dernierPaiementJour'],
                        to_jsonb(v_jour::text), true);
    UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
     WHERE id = v_id;
    RETURN jsonb_build_object('ok', true, 'raison', 'effectif_vide', 'jour', v_jour, 'verse', 0);
  END IF;

  FOR v_el IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
    v_du := v_du + CASE WHEN COALESCE(v_el->>'type','standard') = 'cynophile'
                        THEN c_cout_cynophile ELSE c_cout_standard END;
  END LOOP;

  -- Debit plafonne sur la caisse du Ministere de l'Interieur. L'autorite propre a l'operation
  -- vient d'etre verifiee : on ouvre donc la porte interne prevue par la primitive, pour cette
  -- transaction seulement. Le Chef des Douanes n'obtient aucun droit generique sur la caisse.
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_r := public.caisse_institution_mouvement_plafonne(v_caisse, v_du);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF NOT COALESCE((v_r->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','debit_refuse'));
  END IF;
  v_verse := COALESCE((v_r->>'verse')::numeric, 0);

  -- Combien d'agents le versement couvre-t-il ? Les DERNIERS RECRUTES partent d'abord :
  -- equivalent exact de effectifs.douaniers.slice(0, nbGardes) du chemin client.
  FOR v_el IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
    v_cumul := v_cumul + CASE WHEN COALESCE(v_el->>'type','standard') = 'cynophile'
                              THEN c_cout_cynophile ELSE c_cout_standard END;
    EXIT WHEN v_cumul > v_verse;
    v_gardes := v_gardes + 1;
  END LOOP;

  IF v_gardes < v_n THEN
    SELECT COALESCE(jsonb_agg(e ORDER BY o), '[]'::jsonb) INTO v_liste
      FROM jsonb_array_elements(v_liste) WITH ORDINALITY AS t(e, o)
     WHERE o <= v_gardes;
    v_etat := jsonb_set(v_etat, ARRAY['effectifsDouane','douaniers'], v_liste, true);
  END IF;
  v_etat := jsonb_set(v_etat, ARRAY['effectifsDouane','dernierPaiementJour'],
                      to_jsonb(v_jour::text), true);

  UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'jour', v_jour, 'du', v_du, 'verse', v_verse,
                            'effectif_avant', v_n, 'effectif_apres', v_gardes,
                            'partis', v_n - v_gardes, 'caisse', v_caisse);
END;
$function$

-- douane_pnj_id(text,text,text) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.douane_pnj_id(p_pays text, p_ville text, p_matricule text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT 'douane-' || p_pays || '-' || p_ville || '-' || p_matricule;
$function$

-- filature_deplacements(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.filature_deplacements(p_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_jour integer; v_lignes jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  -- Autorite : le poste est relu EN BASE, jamais accepte du client.
  PERFORM public.exiger_poste('commissaire');

  IF coalesce(btrim(coalesce(p_cible,'')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;

  SELECT d.day INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- LES DERNIERES 24 HEURES, ET RIEN DE PLUS : le libelle de l'ordre fait foi.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'jour', h.jour, 'heure', h.heure,
           'building_id', h.building_id, 'room_id', h.room_id, 'city', h.city)
           ORDER BY h.jour, h.heure), '[]'::jsonb)
    INTO v_lignes
    FROM public.historique_deplacements h
   WHERE h.name = p_cible AND h.jour >= greatest(1, v_jour - 1);

  RETURN jsonb_build_object('ok', true, 'cible', p_cible, 'deplacements', v_lignes);
END;
$function$

-- renseignement_agents_disponibles() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.renseignement_agents_disponibles()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_poste text; v_res jsonb;
BEGIN
  SELECT a.poste_id INTO v_poste FROM public.acteur_poste_courant() a;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'role', i.role, 'vrai_nom', i.vrai_nom, 'dup', i.dup,
           'portrait', public.agent_portrait_chemin(i.role, 'republic'))
           ORDER BY i.role), '[]'::jsonb)
    INTO v_res FROM public.renseignement_identites_reelles i;
  RETURN jsonb_build_object('ok', true, 'agents', v_res);
END;
$function$

-- renseignement_autorite_de_perimetre(text,text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.renseignement_autorite_de_perimetre(p_pays text, p_perimetre text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Le perimetre d'une identite de renseignement est son PAYS. L'autorite est le PJ portant le
  -- poste min_def de ce pays -- c'est exactement la garde que cellule_renseignement_creer applique
  -- deja pour convoquer une cellule. Aucune autorite n'est inventee, et « personne » reste un etat
  -- valide : un poste tenu par un titulaire PNJ ne rend pas ce PNJ autorite.
  SELECT pa.titulaire FROM public.postes_attribues pa
   WHERE pa.poste_id = 'min_def' AND pa.country = COALESCE(p_perimetre, p_pays)
     AND pa.titulaire IS NOT NULL
   LIMIT 1;
$function$

-- renseignement_mission_raccorder() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.renseignement_mission_raccorder()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pnj text; v_dup integer;
BEGIN
  v_pnj := public.renseignement_pnj_id(NEW.role);
  SELECT m.car_dup INTO v_dup FROM public.pnj_membres m WHERE m.id = v_pnj;
  -- Si l'identite n'est pas au socle, on ne raccorde rien et on ne bloque rien : la mission vit
  -- comme avant. Fail-safe, pour qu'un socle incomplet n'empeche jamais de convoquer une cellule.
  IF v_dup IS NULL THEN RETURN NEW; END IF;
  NEW.pnj_id := v_pnj;
  -- La DUP de l'occurrence recopie celle du socle, qui fait desormais autorite : les quatre roles
  -- partagent 13. Recopiee plutot que lue a chaque fois, pour que les lignes HISTORIQUES gardent la
  -- DUP qu'elles avaient reellement au moment de leur mission -- l'historique ne se reecrit pas.
  NEW.dup := v_dup;
  RETURN NEW;
END; $function$

-- renseignement_pnj_id(text) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.renseignement_pnj_id(p_role text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 'agent-' || p_role; $function$
