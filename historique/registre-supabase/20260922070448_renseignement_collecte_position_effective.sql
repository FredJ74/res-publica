-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260922070448
-- Nom original      : renseignement_collecte_position_effective
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-22 07:04:48 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 03d82200ef3e5ab073b27f273aff4540
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- TRACE DE PRESENCE. Elle se depose la ou l'agent EST, pas la ou sa couverture pretend
-- qu'il est. Un agent porte laisse desormais une trace lui aussi : il circule reellement.
CREATE OR REPLACE FUNCTION public.agent_trace_deposer(p_agent_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  a record; v_risque integer; v_jet integer; v_jour integer; v_id text;
BEGIN
  SELECT ag.id, ag.dup, ag.nom_couverture, ag.statut, c.statut AS statut_cellule,
         pe.pays AS pays_eff, pe.ville AS ville_eff,
         pe.building_id AS bat_eff, pe.room_id AS room_eff
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
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

  INSERT INTO public.actions_tracables
    (id, auteur, cible, type_action, country, city, jour, jour_expiration, decouvert)
  VALUES (v_id, a.nom_couverture, NULL, 'presence_suspecte',
          a.pays_eff, a.ville_eff, v_jour, v_jour + 7, false)
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'trace', true, 'risque', v_risque, 'reference', v_id);
END;
$fn$;

-- TRADUCTEUR. Il ecoute les rumeurs de la ville OU IL SE TROUVE.
CREATE OR REPLACE FUNCTION public.agent_traducteur_ecouter(p_agent_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
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
$fn$;

-- CONSEILLERE. Elle observe les personnalites presentes dans LE BATIMENT OU ELLE EST.
CREATE OR REPLACE FUNCTION public.agent_conseillere_observer(p_agent_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  a record; t record; o record; tr record;
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
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
$fn$;

-- GARDE. La distance se mesure depuis SA POSITION REELLE. C'est le seul endroit ou
-- pays_couverture servait de point d'observation : il devient le pays effectif.
CREATE OR REPLACE FUNCTION public.agent_garde_observer(p_agent_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
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
    SELECT c.data->>'pays' AS pays_cible,
           sol->>'ville' AS ville, sol->>'buildingId' AS bat,
           count(*)::integer AS effectif,
           avg(coalesce((sol->'formation'->>'reconnaissance')::numeric, 0)) AS reco_moy,
           count(*) FILTER (WHERE EXISTS (
             SELECT 1 FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) ac
              WHERE ac->>'produitMilitaire' = 'tenue_camouflage'))::integer AS equipes
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE c.data->>'pays' IS DISTINCT FROM a.pays_proprietaire
       AND coalesce(sol->>'ville','') = a.ville_eff
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
$fn$;