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

-- militaire_competences(text) -> jsonb | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_competences(p_nom text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT jsonb_build_object(
           'combat_rapproche', coalesce((competences_militaires->>'combat_rapproche')::numeric, 0),
           'tir',              coalesce((competences_militaires->>'tir')::numeric, 0),
           'reconnaissance',   coalesce((competences_militaires->>'reconnaissance')::numeric, 0),
           'secourisme',       coalesce((competences_militaires->>'secourisme')::numeric, 0))
    FROM public.personnages_donnees WHERE name = p_nom;
$function$

-- militaire_decorer(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_decorer(p_decore text, p_intitule text, p_citation text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_poste text; v_niveau text; v_pays_moi text; v_pays_cible text; v_id bigint;
  v_intitule text; v_citation text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT a.poste_id INTO v_poste FROM public.acteur_poste_courant() a;
  v_niveau := CASE v_poste WHEN 'commandant' THEN 'compagnie'
                           WHEN 'min_def'    THEN 'armee'
                           WHEN 'president'  THEN 'etat' END;
  IF v_niveau IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
      'poste', coalesce(v_poste, '(aucun)'));
  END IF;

  v_intitule := btrim(coalesce(p_intitule, ''));
  IF length(v_intitule) < 3 OR length(v_intitule) > 120 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'intitule_invalide');
  END IF;
  v_citation := nullif(btrim(coalesce(p_citation, '')), '');
  IF length(coalesce(v_citation, '')) > 600 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'citation_trop_longue');
  END IF;

  IF btrim(coalesce(p_decore,'')) = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'auto_decoration_refusee');
  END IF;

  SELECT country INTO v_pays_moi   FROM public.personnages_donnees WHERE name = v_moi;
  SELECT country INTO v_pays_cible FROM public.personnages_donnees WHERE name = btrim(coalesce(p_decore,''));
  IF v_pays_cible IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'decore_introuvable'); END IF;
  IF v_pays_cible IS DISTINCT FROM v_pays_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  BEGIN
    INSERT INTO public.decorations_militaires (decore, pays, niveau, intitule, citation, decerne_par, poste_decernant)
    VALUES (btrim(p_decore), v_pays_cible, v_niveau, v_intitule, v_citation, v_moi, v_poste)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_decernee');
  END;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'decore', btrim(p_decore),
    'niveau', v_niveau, 'intitule', v_intitule, 'decerne_par', v_moi, 'poste', v_poste);
END;
$function$

-- militaire_defense_pnj(text) -> numeric | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.militaire_defense_pnj(p_cle text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT 8::numeric;
$function$

-- militaire_degats_pct(text) -> numeric | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.militaire_degats_pct(p_degre text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p_degre
    WHEN 'critique'    THEN 1.00
    WHEN 'partielle_1' THEN 0.75
    WHEN 'partielle_2' THEN 0.50
    ELSE                    0.00
  END;
$function$

-- militaire_degrader(text,integer,text,text,text) -> jsonb | sql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_degrader(p_bande text, p_effectif integer, p_pays text, p_ville text, p_batiment text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE p_bande
    -- Proche : lieu au batiment, nationalite sure, petite fourchette autour du reel.
    WHEN 'proche' THEN jsonb_build_object(
      'precision', 'proche', 'ville', p_ville, 'batiment', p_batiment,
      'nationalite', p_pays, 'nationalite_sure', true,
      'effectif_min', greatest(1, p_effectif - 1), 'effectif_max', p_effectif + 1,
      'libelle', (greatest(1, p_effectif - 1))::text || ' à ' || (p_effectif + 1)::text || ' soldats')
    -- Moyenne : lieu a la ville, nationalite sure, tranche de 5.
    WHEN 'moyenne' THEN jsonb_build_object(
      'precision', 'moyenne', 'ville', p_ville, 'batiment', NULL,
      'nationalite', p_pays, 'nationalite_sure', true,
      'effectif_min', greatest(1, (p_effectif / 5) * 5),
      'effectif_max', ((p_effectif / 5) + 1) * 5,
      'libelle', greatest(1, (p_effectif / 5) * 5)::text || ' à ' || (((p_effectif / 5) + 1) * 5)::text || ' hommes')
    -- Longue : lieu a la ville, nationalite INCERTAINE, effectif tres approximatif.
    WHEN 'longue' THEN jsonb_build_object(
      'precision', 'longue', 'ville', p_ville, 'batiment', NULL,
      'nationalite', p_pays, 'nationalite_sure', false,
      'effectif_min', NULL, 'effectif_max', NULL,
      'libelle', CASE WHEN p_effectif < 10 THEN 'moins de 10 hommes'
                      WHEN p_effectif < 30 THEN 'une dizaine d''hommes, peut-être plus'
                      ELSE 'plusieurs dizaines d''hommes' END)
    -- Au-dela : rien d'autre qu'un signe de vie. Ni effectif, ni nationalite.
    ELSE jsonb_build_object(
      'precision', 'limite', 'ville', p_ville, 'batiment', NULL,
      'nationalite', NULL, 'nationalite_sure', false,
      'effectif_min', NULL, 'effectif_max', NULL,
      'libelle', 'Mouvement de troupes possible dans ce secteur')
  END;
$function$

-- militaire_degre_combat(integer,integer) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.militaire_degre_combat(p_taux integer, p_jet integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE
    WHEN p_jet = 1 THEN 'echec_critique'
    ELSE (SELECT CASE
            WHEN s >= 95 THEN 'critique'
            WHEN s >= 70 THEN 'partielle_1'
            WHEN s >= 50 THEN 'partielle_2'
            WHEN s >= 10 THEN 'echec'
            ELSE                'echec_critique'
          END
          FROM (SELECT least(100, greatest(0,
                  p_jet + (coalesce(p_taux, 50) - 50) / 2.0)) AS s) x)
  END;
$function$

-- militaire_degre_par_rang(integer) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.militaire_degre_par_rang(p_rang integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE greatest(0, least(4, coalesce(p_rang, 0)))
    WHEN 0 THEN 'echec_critique'
    WHEN 1 THEN 'echec'
    WHEN 2 THEN 'partielle_2'
    WHEN 3 THEN 'partielle_1'
    ELSE        'critique'
  END;
$function$

-- militaire_degre_rang(text) -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.militaire_degre_rang(p_degre text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p_degre
    WHEN 'echec_critique' THEN 0
    WHEN 'echec'          THEN 1
    WHEN 'partielle_2'    THEN 2
    WHEN 'partielle_1'    THEN 3
    WHEN 'critique'       THEN 4
  END;
$function$

-- militaire_demettre_lieutenant(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_demettre_lieutenant(p_compagnie_id text, p_section_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_data jsonb; v_secs jsonb; v_ancien text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'capitaineNom' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_capitaine_de_cette_compagnie'); END IF;

  SELECT s->>'lieutenantNom' INTO v_ancien
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id LIMIT 1;
  IF v_ancien IS NULL OR v_ancien = '' THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'section_deja_vacante'); END IF;

  SELECT COALESCE(jsonb_agg(
           CASE WHEN s->>'id' = p_section_id THEN s - 'lieutenantNom' ELSE s END ORDER BY ord), '[]'::jsonb)
    INTO v_secs
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);

  UPDATE public.compagnies_militaires SET data = v_data || jsonb_build_object('sections', v_secs)
   WHERE id = p_compagnie_id;
  UPDATE public.personnages_donnees SET poste = NULL, updated_at = now()
   WHERE name = v_ancien AND poste->>'id' = 'lieutenant'
     AND poste->>'compagnieId' = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'ancien_lieutenant', v_ancien, 'section', p_section_id);
END; $function$

-- militaire_deposer_soldats(text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_deposer_soldats(p_compagnie_id text, p_section_id text, p_nb integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE g record; v_ville text; v_bat text; v_room text; v_dispo int;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;

  SELECT current_city, current_building, current_room INTO v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = g.o_moi;
  IF COALESCE(v_bat,'') = '' OR COALESCE(v_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue');
  END IF;

  SELECT count(*) INTO v_dispo
    FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND m.statut = 'actif' AND m.leader_pj = g.o_moi;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_assez_avec_vous', 'disponibles', v_dispo);
  END IF;

  UPDATE public.pnj_membres
     SET leader_pj = NULL, leader_pnj_id = NULL,
         ville = v_ville, building_id = v_bat, room_id = v_room, maj_le = now()
   WHERE id IN (SELECT m.id FROM public.pnj_membres m
                  JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
                 WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
                   AND m.statut = 'actif' AND m.leader_pj = g.o_moi
                 ORDER BY sm.matricule LIMIT p_nb);
  PERFORM public.militaire_blob_projeter(p_compagnie_id);

  RETURN jsonb_build_object('ok', true, 'deposes', p_nb,
                            'ville', v_ville, 'batiment', v_bat, 'piece', v_room);
END; $function$

-- militaire_desertions_verifier(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_desertions_verifier(p_pays text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pays text := coalesce(nullif(btrim(coalesce(p_pays, '')), ''), 'republic');
  v_maintenant numeric := floor(extract(epoch FROM now()) * 1000);
  c record; v_data jsonb; v_sec jsonb; v_liste jsonb;
  v_noms text[]; v_nouveaux jsonb := '[]'::jsonb;
BEGIN
  IF public.mon_personnage() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  FOR c IN SELECT id, data FROM public.compagnies_militaires
            WHERE data->>'pays' = v_pays FOR UPDATE LOOP
    v_data := c.data;
    FOR v_sec IN SELECT s FROM jsonb_array_elements(coalesce(v_data->'sections', '[]'::jsonb)) s LOOP
      SELECT array_agg(e->>'nom') INTO v_noms
        FROM jsonb_array_elements(coalesce(v_sec->'civilsRequisitionnes', '[]'::jsonb)) e
       WHERE coalesce(e->>'statut', '') = 'convoque'
         AND (CASE WHEN (e->>'deadline') ~ '^[0-9]+(\.[0-9]+)?$'
                   THEN (e->>'deadline')::numeric ELSE NULL END) < v_maintenant;

      IF v_noms IS NOT NULL AND array_length(v_noms, 1) > 0 THEN
        SELECT coalesce(jsonb_agg(CASE WHEN e->>'nom' = ANY(v_noms)
                                       THEN e || jsonb_build_object('statut', 'deserteur') ELSE e END), '[]'::jsonb)
          INTO v_liste
          FROM jsonb_array_elements(coalesce(v_sec->'civilsRequisitionnes', '[]'::jsonb)) e;
        v_data := public.militaire_sections_remplacer(v_data, v_sec->>'id',
                    v_sec || jsonb_build_object('civilsRequisitionnes', v_liste));

        UPDATE public.personnages_donnees p
           SET requisition = jsonb_build_object('compagnieId', c.id, 'sectionId', v_sec->>'id',
                                                'statut', 'deserteur')
         WHERE p.name = ANY(v_noms);

        SELECT v_nouveaux || coalesce(jsonb_agg(jsonb_build_object(
                 'nom', n, 'compagnieId', c.id, 'sectionId', v_sec->>'id',
                 'section', v_sec->>'numero')), '[]'::jsonb)
          INTO v_nouveaux FROM unnest(v_noms) n;
      END IF;
    END LOOP;
    IF v_data IS DISTINCT FROM c.data THEN
      UPDATE public.compagnies_militaires SET data = v_data WHERE id = c.id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'deserteurs', v_nouveaux);
END;
$function$

-- militaire_detachement_ici() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_detachement_ici()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; a record; v_out jsonb := '[]'::jsonb; r record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  IF a.country IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  FOR r IN
    SELECT m.pays,
           c.id AS compagnie_id,
           sm.section_id,
           sec->>'lieutenantNom' AS lieutenant,
           sec->>'mission'       AS mission,
           count(*)::integer     AS effectif
      FROM public.pnj_membres m
      JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
      JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
      -- La compagnie et sa section : metier militaire, toujours lu dans le blob.
      JOIN public.compagnies_militaires c
        ON m.id LIKE c.id || '-%'
      LEFT JOIN LATERAL (
        SELECT s FROM jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) s
         WHERE s->>'id' = sm.section_id LIMIT 1) j(sec) ON true
     WHERE m.famille = 'soldat'
       AND m.statut  = 'actif'
       AND sm.en_reserve = false          -- <<< les reservistes ne sont pas un detachement
       AND pe.ville       = a.current_city
       AND pe.building_id = a.current_building
       AND pe.room_id     = a.current_room
     GROUP BY 1,2,3,4,5
  LOOP
    IF r.pays = a.country THEN
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'pays', r.pays, 'mien', true, 'compagnie_id', r.compagnie_id,
        'section_id', r.section_id, 'lieutenant', r.lieutenant,
        'mission', r.mission, 'effectif', r.effectif));
    ELSE
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'pays', r.pays, 'mien', false,
        'estime', public.militaire_degrader('proche', r.effectif, r.pays,
                    a.current_city, a.current_building)));
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'detachements', v_out);
END;
$function$

-- militaire_engagement_affecter_compagnie(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_engagement_affecter_compagnie(p_engagement_id text, p_compagnie_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_pays text; v_e record; v_cie jsonb;
BEGIN
  v_moi := public.exiger_poste('commandant');
  IF v_moi IS NULL THEN v_moi := public.mon_personnage(); END IF;
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country,'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO v_e FROM public.engagements_militaires WHERE id = p_engagement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'engagement_introuvable'); END IF;
  -- ETAT PRECEDENT verifie : on ne saute pas une etape et on ne rejoue pas.
  IF v_e.statut <> 'attente_commandant' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etape_invalide', 'statut', v_e.statut);
  END IF;
  IF v_e.data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  SELECT data INTO v_cie FROM public.compagnies_militaires WHERE id = p_compagnie_id;
  IF v_cie IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_cie->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  UPDATE public.engagements_militaires
     SET statut = 'attente_capitaine',
         data = data || jsonb_build_object('compagnieId', p_compagnie_id, 'parCommandant', v_moi)
   WHERE id = p_engagement_id;
  RETURN jsonb_build_object('ok', true, 'statut', 'attente_capitaine', 'compagnie', p_compagnie_id);
END; $function$

-- militaire_engagement_affecter_section(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_engagement_affecter_section(p_engagement_id text, p_section_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_places constant integer := 24;
  v_moi text; v_pays text; v_e record; v_data jsonb; v_secs jsonb; v_nom text;
  v_reserve jsonb; v_deja integer; v_tire integer; v_pris jsonb; v_reste jsonb; v_ok boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country,'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO v_e FROM public.engagements_militaires WHERE id = p_engagement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'engagement_introuvable'); END IF;
  IF v_e.statut <> 'attente_capitaine' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etape_invalide', 'statut', v_e.statut);
  END IF;
  v_nom := v_e.data->>'nom';

  SELECT data INTO v_data FROM public.compagnies_militaires
   WHERE id = v_e.data->>'compagnieId' FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  -- AUTORITE : le Capitaine de CETTE compagnie, et personne d'autre.
  IF v_data->>'capitaineNom' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_capitaine_de_cette_compagnie');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_introuvable');
  END IF;

  -- Meme regle de contingent que militaire_accepter_lieutenant : la section se peuple depuis la
  -- reserve, sans jamais depasser 24, et peut naitre incomplete.
  SELECT count(*) INTO v_deja
    FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE s->>'id' = p_section_id;
  v_reserve := CASE WHEN jsonb_typeof(v_data->'reserve')='array' THEN v_data->'reserve' ELSE '[]'::jsonb END;
  v_tire := least(greatest(0, c_places - v_deja), jsonb_array_length(v_reserve));
  SELECT coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos <= v_tire), '[]'::jsonb),
         coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos > v_tire), '[]'::jsonb)
    INTO v_pris, v_reste FROM jsonb_array_elements(v_reserve) WITH ORDINALITY AS t(sol, pos);

  SELECT coalesce(jsonb_agg(
           CASE WHEN s->>'id' = p_section_id AND coalesce(s->>'lieutenantNom','') = ''
                THEN s || jsonb_build_object('lieutenantNom', v_nom,
                       'soldats', coalesce(s->'soldats','[]'::jsonb) || v_pris)
                ELSE s END ORDER BY ord), '[]'::jsonb)
    INTO v_secs FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);
  SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(v_secs) s
                  WHERE s->>'id' = p_section_id AND s->>'lieutenantNom' = v_nom) INTO v_ok;
  IF NOT v_ok THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_indisponible'); END IF;

  UPDATE public.compagnies_militaires
     SET data = v_data || jsonb_build_object('sections', v_secs, 'reserve', v_reste)
   WHERE id = v_e.data->>'compagnieId';
  -- LE POSTE DU CANDIDAT, ecrit ICI. C'est ce que le client ne pouvait plus faire.
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','lieutenant','name','Lieutenant',
                   'compagnieId', v_e.data->>'compagnieId', 'sectionId', p_section_id),
         updated_at = now()
   WHERE name = v_nom;
  UPDATE public.engagements_militaires
     SET statut = 'affecte', data = data || jsonb_build_object('sectionId', p_section_id, 'parCapitaine', v_moi)
   WHERE id = p_engagement_id;

  RETURN jsonb_build_object('ok', true, 'statut', 'affecte', 'nom', v_nom,
    'section', p_section_id, 'hommes', v_tire, 'incomplete', (v_deja + v_tire) < c_places);
END; $function$

-- militaire_engagement_creer() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_engagement_creer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_pays text; v_poste text; v_id text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country,'republic'), coalesce(poste->>'id','')
    INTO v_pays, v_poste FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_poste IN ('lieutenant','capitaine','commandant') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_officier');
  END IF;
  IF EXISTS (SELECT 1 FROM public.engagements_militaires
              WHERE statut IN ('attente_commandant','attente_capitaine')
                AND data->>'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_en_cours');
  END IF;

  v_id := 'eng-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.engagements_militaires (id, statut, data)
  VALUES (v_id, 'attente_commandant',
          jsonb_build_object('pays', v_pays, 'nom', v_moi, 'depuis', to_jsonb(now())));
  RETURN jsonb_build_object('ok', true, 'engagement', v_id, 'pays', v_pays);
END; $function$

-- militaire_entrainer_section(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_entrainer_section(p_compagnie_id text, p_section_id text, p_stat text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_max     constant integer := 12;
  c_pa      constant integer := 6;
  c_gain    constant integer := 3;
  c_plafond constant integer := 100;
  g record; v_sec jsonb; v_sols jsonb; v_pa_chef integer;
  v_elus_pnj jsonb; v_elus_pj jsonb; v_n integer; v_nom text; v_ids text[];
BEGIN
  IF p_stat NOT IN ('combat_rapproche','tir','reconnaissance','secourisme') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'domaine_invalide', 'domaine', p_stat);
  END IF;

  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  SELECT coalesce(pa, 0) INTO v_pa_chef FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;
  IF v_pa_chef < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_chef_insuffisants',
                              'requis', c_pa, 'pa_reel', v_pa_chef);
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;

  -- SELECTION COMMUNE PJ + PNJ, regle inchangee : les moins formes d'abord, jusqu'a 12 au total,
  -- et seulement ceux qui ont REELLEMENT leurs 6 PA. Les PA d'un PNJ se lisent desormais au socle.
  CREATE TEMP TABLE IF NOT EXISTS pg_temp_elus (nom text, matricule text, est_pj boolean, niveau numeric) ON COMMIT DROP;
  DELETE FROM pg_temp_elus;

  INSERT INTO pg_temp_elus (nom, matricule, est_pj, niveau)
  SELECT NULL, sm.matricule, false, coalesce((sm.formation->>p_stat)::numeric, 0)
    FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND m.statut = 'actif' AND m.pa >= c_pa
  UNION ALL
  SELECT pd.name, NULL, true, coalesce((pd.competences_militaires->>p_stat)::numeric, 0)
    FROM jsonb_array_elements(v_sols) sol
    JOIN public.personnages_donnees pd ON pd.name = sol->>'nom'
   WHERE coalesce((sol->>'pj')::boolean, false) AND coalesce(pd.pa, 0) >= c_pa;

  DELETE FROM pg_temp_elus WHERE ctid NOT IN (
    SELECT ctid FROM pg_temp_elus ORDER BY niveau, coalesce(matricule, nom) LIMIT c_max);

  SELECT count(*) INTO v_n FROM pg_temp_elus;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_soldat_en_etat', 'pa_requis', c_pa);
  END IF;

  SELECT coalesce(jsonb_agg(matricule), '[]'::jsonb) INTO v_elus_pnj FROM pg_temp_elus WHERE NOT est_pj;
  SELECT coalesce(jsonb_agg(nom), '[]'::jsonb)       INTO v_elus_pj  FROM pg_temp_elus WHERE est_pj;
  SELECT coalesce(array_agg(p_compagnie_id || '-' || matricule), '{}'::text[])
    INTO v_ids FROM pg_temp_elus WHERE NOT est_pj;

  -- PA : au socle, par la primitive generique. FORMATION : au blob, donnee metier.
  IF array_length(v_ids, 1) IS NOT NULL THEN
    PERFORM public.pnj_pa_debiter(v_ids, c_pa);
  END IF;

  SELECT coalesce(jsonb_agg(
           CASE WHEN v_elus_pnj ? (sol->>'matricule')
                THEN sol || jsonb_build_object('formation',
                              coalesce(CASE WHEN jsonb_typeof(sol->'formation') = 'object'
                                            THEN sol->'formation' END, '{}'::jsonb)
                              || jsonb_build_object(p_stat, least(c_plafond,
                                   coalesce((sol->'formation'->>p_stat)::numeric, 0) + c_gain)))
                ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  PERFORM public.militaire_blob_projeter(p_compagnie_id);

  FOR v_nom IN SELECT nom FROM pg_temp_elus WHERE est_pj LOOP
    UPDATE public.personnages_donnees
       SET pa = greatest(0, coalesce(pa, 0) - c_pa),
           competences_militaires = coalesce(competences_militaires, '{}'::jsonb)
             || jsonb_build_object(p_stat, least(c_plafond,
                  coalesce((competences_militaires->>p_stat)::numeric, 0) + c_gain))
     WHERE name = v_nom;
  END LOOP;

  UPDATE public.personnages_donnees SET pa = v_pa_chef - c_pa WHERE name = g.o_moi;

  RETURN jsonb_build_object('ok', true, 'domaine', p_stat, 'progresses', v_n,
    'pnj', jsonb_array_length(v_elus_pnj), 'pj', jsonb_array_length(v_elus_pj),
    'gain', c_gain, 'plafond', c_plafond, 'pa_soldat', c_pa, 'pa_chef', c_pa,
    'pa_restants_chef', v_pa_chef - c_pa, 'matricules', v_elus_pnj, 'joueurs', v_elus_pj);
END; $function$

-- militaire_entree_zone() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_entree_zone()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_bonus_jumelles constant integer := 30;
  v_moi text; v_pays text; v_ville text; v_bat text; v_piece text;
  v_jour text; v_zone text; v_cle text; v_garde_posee boolean := false;
  v_reco numeric; v_jumelles boolean;
  v_mes_pnj integer; v_ma_reco numeric; v_mes_equipes integer; v_mon_effectif integer;
  v_militaire boolean; v_contacts jsonb := '[]'::jsonb; v_mutuels integer := 0;
  r record; v_bande text; v_modif integer;
  v_camo_eux numeric; v_camo_moi numeric;
  v_chance_moi integer; v_chance_eux integer; v_vu_par_moi boolean; v_vu_par_eux boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_city,''), coalesce(current_building,''),
         coalesce(current_room,''), coalesce((competences_militaires->>'reconnaissance')::numeric, 0),
         EXISTS (SELECT 1 FROM jsonb_array_elements(
                   CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END) i
                  WHERE i->>'produitMilitaire' = 'jumelles')
    INTO v_pays, v_ville, v_bat, v_piece, v_reco, v_jumelles
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  SELECT count(*)::integer,
         coalesce(avg(coalesce((sm.formation->>'reconnaissance')::numeric, 0)), 0),
         count(*) FILTER (WHERE EXISTS (
           SELECT 1 FROM public.pnj_possessions p
            WHERE p.pnj_id = m.id AND p.origine = 'blob_accessoires'
              AND p.objet->>'produitMilitaire' = 'tenue_camouflage'))::integer
    INTO v_mes_pnj, v_ma_reco, v_mes_equipes
    FROM public.pnj_membres m
    JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE m.famille = 'soldat' AND m.statut = 'actif'
     AND sm.en_reserve = false
     AND m.leader_pj = v_moi;

  v_militaire := EXISTS (SELECT 1 FROM public.services_militaires sm
                          WHERE sm.personnage = v_moi AND sm.fin_ts IS NULL);

  IF coalesce(v_mes_pnj,0) = 0 AND NOT v_militaire THEN
    RETURN jsonb_build_object('ok', true, 'force', false, 'contacts', '[]'::jsonb);
  END IF;
  v_mon_effectif := coalesce(v_mes_pnj,0) + 1;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;
  v_zone := v_pays || '/' || v_ville || '/' || v_bat || '/' || v_piece;
  v_cle  := v_moi || ':' || v_jour || ':' || v_zone;

  FOR r IN
    SELECT m.pays AS pays_cible,
           m.ville AS ville, m.building_id AS bat, m.room_id AS piece,
           count(*)::integer AS effectif,
           avg(coalesce((sm.formation->>'reconnaissance')::numeric, 0)) AS reco_moy,
           count(*) FILTER (WHERE EXISTS (
             SELECT 1 FROM public.pnj_possessions p
              WHERE p.pnj_id = m.id AND p.origine = 'blob_accessoires'
                AND p.objet->>'produitMilitaire' = 'tenue_camouflage'))::integer AS equipes,
           bool_or(EXISTS (
             SELECT 1 FROM public.pnj_possessions p
              WHERE p.pnj_id = m.id AND p.origine = 'blob_accessoires'
                AND p.objet->>'produitMilitaire' = 'jumelles')) AS a_jumelles
      FROM public.pnj_membres m
      JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE m.famille = 'soldat' AND m.statut = 'actif'
       AND sm.en_reserve = false
       AND m.pays IS DISTINCT FROM v_pays
       AND m.ville = v_ville
       AND m.leader_pj IS NULL AND m.leader_pnj_id IS NULL
       AND EXISTS (SELECT 1 FROM public.guerres g
                    WHERE g.statut = 'active'
                      AND ((g.data->>'attaquant' = v_pays AND g.data->>'attaque' = c.data->>'pays')
                        OR (g.data->>'attaque'  = v_pays AND g.data->>'attaquant' = c.data->>'pays')))
     GROUP BY 1, 2, 3, 4
  LOOP
    v_bande := public.militaire_bande_distance(v_pays, v_ville, v_bat, v_pays, r.ville, r.bat);
    v_modif := public.militaire_modif_distance(v_bande);
    CONTINUE WHEN v_modif IS NULL;

    -- GARDE PARESSEUSE : posee ici, juste avant le PREMIER jet reel, et une seule fois.
    IF NOT v_garde_posee THEN
      BEGIN
        INSERT INTO public.militaire_detections (id, personnage, jour, zone)
        VALUES (v_cle, v_moi, v_jour, v_zone);
        v_garde_posee := true;
      EXCEPTION WHEN unique_violation THEN
        RETURN jsonb_build_object('ok', true, 'force', true, 'deja_sonde', true,
          'contacts', '[]'::jsonb);
      END;
    END IF;

    v_camo_eux := public.militaire_camouflage_groupe(r.reco_moy, r.effectif, r.equipes);
    v_camo_moi := public.militaire_camouflage_groupe(v_ma_reco, v_mon_effectif, v_mes_equipes);

    v_chance_moi := public.militaire_chance_detection(
      v_reco, v_camo_eux, v_modif, CASE WHEN v_jumelles THEN c_bonus_jumelles ELSE 0 END);
    v_chance_eux := public.militaire_chance_detection(
      r.reco_moy, v_camo_moi, v_modif, CASE WHEN coalesce(r.a_jumelles,false) THEN c_bonus_jumelles ELSE 0 END);

    v_vu_par_moi := (floor(random() * 100)::integer + 1) <= v_chance_moi;
    v_vu_par_eux := (floor(random() * 100)::integer + 1) <= v_chance_eux;

    IF v_vu_par_moi THEN
      v_contacts := v_contacts || jsonb_build_array(
        public.militaire_degrader(v_bande, r.effectif, r.pays_cible, r.ville, r.bat));
    END IF;

    IF v_vu_par_moi AND v_vu_par_eux THEN
      INSERT INTO public.contacts_militaires (pays_a, pays_b, ville, batiment, piece, effectif_a, effectif_b)
      VALUES (v_pays, r.pays_cible, r.ville, r.bat, r.piece, v_mon_effectif, r.effectif);
      v_mutuels := v_mutuels + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'force', true, 'effectif', v_mon_effectif,
    'reconnaissance', v_reco, 'jumelles', v_jumelles,
    'contacts', v_contacts, 'contacts_mutuels', v_mutuels);
END;
$function$

-- militaire_equiper_accessoire(text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_equiper_accessoire(p_compagnie_id text, p_section_id text, p_matricule text, p_objet_id text, p_sens text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_plafond constant integer := 100;
  g record; v_inv jsonb; v_occupe numeric; v_objet jsonb; v_pos integer;
  v_pnj text; v_ligne bigint;
BEGIN
  IF coalesce(p_sens,'') NOT IN ('equiper','desequiper') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
  END IF;
  IF coalesce(btrim(coalesce(p_matricule,'')),'') = ''
     OR coalesce(btrim(coalesce(p_objet_id,'')),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- AUTORITE INCHANGEE : Lieutenant structurel de cette section, meme empire.
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  -- Le soldat est desormais identifie par la couche METIER du socle, qui porte sa section.
  SELECT sm.pnj_id INTO v_pnj
    FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND sm.matricule = p_matricule AND m.statut = 'actif';
  IF v_pnj IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable', 'matricule', p_matricule);
  END IF;

  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_inv FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;

  IF p_sens = 'equiper' THEN
    SELECT i, pos INTO v_objet, v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
     WHERE i->>'id' = p_objet_id LIMIT 1;
    IF v_objet IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent_de_l_inventaire');
    END IF;
    SELECT coalesce(jsonb_agg(i ORDER BY pos), '[]'::jsonb) INTO v_inv
      FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos) WHERE pos <> v_pos;
    INSERT INTO public.pnj_possessions (pnj_id, objet, origine)
    VALUES (v_pnj, v_objet, 'blob_accessoires');
    UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = g.o_moi;

  ELSE
    SELECT p.id, p.objet INTO v_ligne, v_objet FROM public.pnj_possessions p
     WHERE p.pnj_id = v_pnj AND p.objet->>'id' = p_objet_id
     ORDER BY p.id LIMIT 1 FOR UPDATE;
    IF v_ligne IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'objet_non_porte');
    END IF;
    SELECT coalesce(sum(greatest(1, coalesce((i->>'qty')::numeric, (i->>'encombrement')::numeric, 1))), 0)
      INTO v_occupe FROM jsonb_array_elements(v_inv) i;
    IF v_occupe + 1 > c_plafond THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'plafond', c_plafond);
    END IF;
    DELETE FROM public.pnj_possessions WHERE id = v_ligne;
    UPDATE public.personnages_donnees
       SET inventory = v_inv || jsonb_build_array(v_objet) WHERE name = g.o_moi;
  END IF;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'matricule', p_matricule,
    'objet', v_objet->>'name', 'produit', v_objet->>'produitMilitaire', 'objet_id', p_objet_id);
END; $function$

-- militaire_equiper_soldat(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_equiper_soldat(p_compagnie_id text, p_section_id text, p_matricule text, p_categorie text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  g record; v_sec jsonb; v_stock jsonb; v_sol jsonb; v_anc text; v_dispo int;
  v_pnj text; v_rendu text;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF p_categorie NOT IN ('corps_a_corps','arme_de_poing','mitraillette') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'categorie_invalide');
  END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_stock := CASE WHEN jsonb_typeof(v_sec->'stockArmes') = 'object' THEN v_sec->'stockArmes'
                  ELSE jsonb_build_object('arme_de_poing',0,'mitraillette',0) END;
  SELECT s INTO v_sol FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'matricule' = p_matricule LIMIT 1;
  IF v_sol IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable'); END IF;

  SELECT sm.pnj_id INTO v_pnj
    FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND sm.matricule = p_matricule AND m.statut = 'actif';
  IF v_pnj IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable'); END IF;

  v_anc := public.militaire_arme_operationnelle(v_pnj);
  IF v_anc = p_categorie THEN RETURN jsonb_build_object('ok', true, 'rejeu', true, 'arme', v_anc); END IF;

  IF p_categorie <> 'corps_a_corps' THEN
    v_dispo := GREATEST(0, COALESCE((v_stock->>p_categorie)::int, 0));
    IF v_dispo <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_section_insuffisant', 'categorie', p_categorie);
    END IF;
    v_stock := v_stock || jsonb_build_object(p_categorie, v_dispo - 1);
  END IF;

  IF v_anc IN ('arme_de_poing','mitraillette') THEN
    v_stock := v_stock || jsonb_build_object(v_anc,
                 GREATEST(0, COALESCE((v_stock->>v_anc)::int, 0)) + 1);
    DELETE FROM public.pnj_possessions
     WHERE id = (SELECT p.id FROM public.pnj_possessions p
                  WHERE p.pnj_id = v_pnj AND p.objet->>'type' = 'arme'
                    AND coalesce(p.objet->>'produitMilitaire', p.objet->>'name') = v_anc
                  ORDER BY p.id LIMIT 1);
  END IF;

  IF p_categorie <> 'corps_a_corps' THEN
    INSERT INTO public.pnj_possessions (pnj_id, objet, origine)
    VALUES (v_pnj, jsonb_build_object(
      'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
      'type', 'arme', 'sousType', 'militaire', 'origineMilitaire', true,
      'lot', 'stock-section', 'produitMilitaire', p_categorie,
      'name', CASE p_categorie WHEN 'arme_de_poing' THEN 'Pistolet militaire'
                               ELSE 'Mitraillette' END,
      'icon', 'ti-crosshair', 'legal', true,
      'imageUrl', CASE p_categorie
        WHEN 'arme_de_poing' THEN 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-militaire.png'
        ELSE 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-mitraillette-militaire.png' END,
      'desc', 'Arme reglementaire, remise depuis le stock de la section.'), 'socle');
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('stockArmes', v_stock))
   WHERE id = p_compagnie_id;
  v_rendu := public.militaire_arme_recalculer(v_pnj);

  RETURN jsonb_build_object('ok', true, 'matricule', p_matricule, 'arme', v_rendu,
                            'ancienne', v_anc, 'stock', v_stock);
END; $function$

-- militaire_gilet_absorber(boolean,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_gilet_absorber(p_est_pj boolean, p_nom text, p_compagnie_id text, p_section_id text, p_matricule text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_pos integer; v_protege boolean; v_pnj text; v_ligne bigint; v_objet jsonb;
BEGIN
  -- LE PJ : inchange, son gilet est dans son propre inventaire.
  IF p_est_pj THEN
    SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
      INTO v_inv FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
    IF v_inv IS NULL THEN RETURN jsonb_build_object('protege', false, 'raison', 'porteur_introuvable'); END IF;
    SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
     WHERE i->>'produitMilitaire' = 'gilet_pare_balles'
       AND coalesce((i->>'fragilise')::boolean, false) = false ORDER BY pos LIMIT 1;
    IF v_pos IS NULL THEN RETURN jsonb_build_object('protege', false, 'raison', 'aucun_gilet_intact'); END IF;
    v_protege := (random() < 0.5);
    IF v_protege THEN
      SELECT coalesce(jsonb_agg(CASE WHEN pos = v_pos
               THEN i || jsonb_build_object('fragilise', true,
                      'desc', coalesce(i->>'desc','') || ' Fragilisé : a déjà encaissé un impact.')
               ELSE i END ORDER BY pos), '[]'::jsonb)
        INTO v_inv FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos);
      UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_nom;
    END IF;
    RETURN jsonb_build_object('protege', v_protege, 'gilet_fragilise', v_protege);
  END IF;

  -- LE PNJ : son gilet vit desormais dans le socle. Le plus ancien gilet intact, comme avant.
  SELECT p.id, p.objet INTO v_ligne, v_objet
    FROM public.pnj_possessions p
    JOIN public.pnj_soldats_metier sm ON sm.pnj_id = p.pnj_id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND sm.matricule = p_matricule
     AND p.objet->>'produitMilitaire' = 'gilet_pare_balles'
     AND coalesce((p.objet->>'fragilise')::boolean, false) = false
   ORDER BY p.id LIMIT 1 FOR UPDATE;
  IF v_ligne IS NULL THEN
    RETURN jsonb_build_object('protege', false, 'raison', 'aucun_gilet_intact');
  END IF;

  -- Le jet AVANT l'ecriture : sur un echec le gilet reste intact. Regle inchangee.
  v_protege := (random() < 0.5);
  IF v_protege THEN
    UPDATE public.pnj_possessions
       SET objet = v_objet || jsonb_build_object('fragilise', true)
     WHERE id = v_ligne;
  END IF;
  RETURN jsonb_build_object('protege', v_protege, 'gilet_fragilise', v_protege);
END; $function$

-- militaire_grade_effectif(text) -> text | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_grade_effectif(p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT COALESCE(
    (SELECT pd.poste->>'id' FROM public.personnages_donnees pd
      WHERE pd.name = p_nom AND pd.poste->>'id' IN ('lieutenant','capitaine','commandant')),
    (SELECT 'soldat' FROM public.compagnies_militaires c,
            jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
            jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
      WHERE coalesce((sol->>'pj')::boolean,false) AND sol->>'nom' = p_nom LIMIT 1));
$function$

-- militaire_groupe_sous_seuil(bigint,text) -> boolean | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_groupe_sous_seuil(p_bataille_id bigint, p_groupe_id text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT (SELECT count(*) FROM public.batailles_engagements e
           WHERE e.bataille_id = p_bataille_id AND e.groupe_id = p_groupe_id
             AND e.sorti_round IS NULL) * 2
         <= coalesce((SELECT g.effectif_initial FROM public.batailles_groupes g
                       WHERE g.bataille_id = p_bataille_id AND g.groupe_id = p_groupe_id), 0);
$function$

-- militaire_lien_operationnel_rompre(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_lien_operationnel_rompre(p_leader text, p_ville text, p_bat text, p_room text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_total int := 0; v_cie text;
BEGIN
  IF coalesce(btrim(coalesce(p_leader, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_invalide');
  END IF;

  UPDATE public.pnj_membres
     SET leader_pj = NULL, leader_pnj_id = NULL,
         ville = p_ville, building_id = p_bat, room_id = p_room, maj_le = now()
   WHERE famille = 'soldat' AND statut = 'actif' AND leader_pj = p_leader;
  GET DIAGNOSTICS v_total = ROW_COUNT;

  -- Toutes les compagnies concernees sont reprojetees, pas seulement une.
  FOR v_cie IN SELECT DISTINCT sm.compagnie_id FROM public.pnj_soldats_metier sm
                 WHERE sm.compagnie_id IS NOT NULL LOOP
    PERFORM public.militaire_blob_projeter(v_cie);
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'soldats', v_total,
                            'ville', p_ville, 'batiment', p_bat, 'piece', p_room);
END; $function$

-- militaire_ma_section() -> record | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_ma_section(OUT o_moi text, OUT o_compagnie text, OUT o_section text, OUT o_data jsonb, OUT o_raison text)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  o_moi := public.mon_personnage();
  IF o_moi IS NULL THEN o_raison := 'acteur_non_authentifie'; RETURN; END IF;

  SELECT c.id, s->>'id', c.data
    INTO o_compagnie, o_section, o_data
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s
   WHERE s->>'lieutenantNom' = o_moi
     AND c.data->>'pays' = (SELECT country FROM public.personnages_donnees WHERE name = o_moi)
   LIMIT 1;

  IF o_compagnie IS NULL THEN o_raison := 'pas_lieutenant_de_section'; RETURN; END IF;
  o_raison := NULL;
END; $function$

-- militaire_malus_taille(integer) -> integer | sql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_malus_taille(p_effectif integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN coalesce(p_effectif,0) <= 1  THEN 0
    WHEN p_effectif <= 4   THEN -5
    WHEN p_effectif <= 9   THEN -10
    WHEN p_effectif <= 15  THEN -20
    WHEN p_effectif <= 25  THEN -30
    WHEN p_effectif <= 50  THEN -40
    ELSE -50 END;
$function$

-- militaire_mes_batailles(integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_mes_batailles(p_limite integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(jsonb_agg(x ORDER BY x->>'debut' DESC), '[]'::jsonb) INTO v_res FROM (
    SELECT jsonb_build_object(
      'id', b.id, 'debut', b.debut_ts, 'fin', b.fin_ts, 'statut', b.statut, 'issue', b.issue,
      'lieu', jsonb_build_object('ville', b.ville, 'batiment', b.batiment, 'piece', b.piece),
      'mon_camp', e.camp, 'mon_etat', e.etat_final, 'sorti_round', e.sorti_round,
      'rounds', (SELECT coalesce(jsonb_agg(r.rapport ORDER BY r.numero), '[]'::jsonb)
                   FROM public.batailles_rounds r
                  WHERE r.bataille_id = b.id AND r.camp = e.camp)) AS x
      FROM public.batailles_engagements e
      JOIN public.batailles b ON b.id = e.bataille_id
     WHERE e.personnage = v_moi
     ORDER BY b.debut_ts DESC LIMIT greatest(1, least(50, coalesce(p_limite, 10)))) t;
  RETURN jsonb_build_object('ok', true, 'batailles', v_res);
END;
$function$

-- militaire_mes_candidatures() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_mes_candidatures()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_liste jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', cm.id, 'grade', cm.grade_vise, 'statut', cm.statut, 'depuis', cm.cree_le,
           'echeance', CASE WHEN cm.statut = 'acceptee' THEN cm.echeance END)
           ORDER BY cm.cree_le), '[]'::jsonb)
    INTO v_liste
    FROM public.candidatures_militaires cm
   WHERE cm.candidat = v_moi AND cm.statut IN ('active','acceptee');

  RETURN jsonb_build_object('ok', true, 'candidatures', v_liste,
    'affectation_a_decouvrir', EXISTS (SELECT 1 FROM public.candidatures_militaires
       WHERE candidat = v_moi AND statut = 'acceptee' AND echeance > now()));
END;
$function$

-- militaire_mobilisation_fixer(boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_mobilisation_fixer(p_actif boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- AUTORITE. exiger_poste leve si le poste n'est pas atteste : on ne se contente pas de lire
  -- poste->>'id' sur la fiche, qui est ce que le navigateur affiche.
  PERFORM public.exiger_poste('min_def');

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- ECRITURE CHIRURGICALE : une seule cle, sous verrou, sans relire ni reecrire le reste du blob.
  UPDATE public.budgets_nationaux
     SET data = jsonb_set(coalesce(data, '{}'::jsonb), '{mobilisationNationaleActive}',
                          to_jsonb(coalesce(p_actif, false)), true),
         updated_at = now()
   WHERE id = v_pays;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'budget_introuvable', 'pays', v_pays);
  END IF;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'actif', coalesce(p_actif, false));
END;
$function$

-- militaire_modif_distance(text) -> integer | sql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_modif_distance(p_bande text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE p_bande WHEN 'proche' THEN 0 WHEN 'moyenne' THEN -20
                      WHEN 'longue' THEN -40 ELSE NULL END;
$function$

-- militaire_mon_pays() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_mon_pays()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT d.country FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() LIMIT 1;
$function$

-- militaire_mutinerie_declencher() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_mutinerie_declencher()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_effectif_max constant integer := 24;
  c_bonus_max    constant integer := 4;
  c_seuil_crise  constant numeric := 35;
  g record; v_moi text; v_pays text; v_cie text; v_sec text;
  v_cha numeric; v_base integer; v_social numeric; v_ie numeric;
  v_deg_s numeric; v_deg_e numeric; v_score numeric; v_bonus integer;
  v_vises integer; v_dispo integer; v_camp text; v_choisis text[]; v_sols jsonb; v_secj jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), poste->>'compagnieId', poste->>'sectionId',
         public.assemblee_stat_base(stats, 'CHA')
    INTO v_pays, v_cie, v_sec, v_cha
    FROM public.personnages_donnees
   WHERE name = v_moi AND poste->>'id' = 'lieutenant';
  IF v_cie IS NULL OR v_sec IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_lieutenant');
  END IF;

  IF public.mutinerie_camp_de(v_moi) IS NOT NULL
     OR EXISTS (SELECT 1 FROM public.mutineries_membres WHERE personnage = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_mutin');
  END IF;

  -- AUTORITE ET VERROU : le Lieutenant STRUCTUREL de cette section, verrou pose sur la compagnie.
  SELECT * INTO g FROM public.militaire_section_de_moi(v_cie, v_sec);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  -- BAREME DE CHARISME (game design). CHA 17+ traite comme 16 : le bareme ne monte pas au-dela.
  v_base := CASE WHEN v_cha <= 13 THEN 12 WHEN v_cha < 15 THEN 15
                 WHEN v_cha < 16 THEN 18 ELSE 20 END;

  -- BONUS DE CRISE NATIONALE : social pese 2/3, economie 1/3. Une situation saine (>= 35)
  -- n'apporte rien. 'ie' est lu pour de vrai bien qu'aucune mecanique ne le fasse encore bouger :
  -- la mutinerie sera prete le jour ou il deviendra vivant.
  v_social := public.mutinerie_social_national(v_pays);
  v_ie     := public.helvetia_ie_national(v_pays);
  v_deg_s  := greatest(0, (c_seuil_crise - v_social) / c_seuil_crise);
  v_deg_e  := greatest(0, (c_seuil_crise - v_ie)     / c_seuil_crise);
  v_score  := (2.0/3.0) * v_deg_s + (1.0/3.0) * v_deg_e;
  v_bonus  := least(c_bonus_max, greatest(0, ceil(c_bonus_max * v_score)::integer));

  v_vises := least(c_effectif_max, v_base + v_bonus);

  SELECT s INTO v_secj FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = v_sec;
  v_sols := CASE WHEN jsonb_typeof(v_secj->'soldats') = 'array' THEN v_secj->'soldats' ELSE '[]'::jsonb END;

  -- SOLDATS REELLEMENT DISPONIBLES : les PNJ vivants de la section, jamais un PJ (un joueur ne se
  -- rallie pas malgre lui), jamais un effectif invente.
  SELECT count(*)::integer INTO v_dispo FROM jsonb_array_elements(v_sols) sol
   WHERE NOT coalesce((sol->>'pj')::boolean, false)
     AND coalesce((sol->>'pa')::integer, 0) > 0
     AND (sol->>'mutin') IS NULL;
  v_vises := least(v_vises, v_dispo);

  v_camp := 'mutin:' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 12);
  INSERT INTO public.mutineries (camp, pays, fondateur, compagnie_id, section_id)
  VALUES (v_camp, v_pays, v_moi, v_cie, v_sec);
  INSERT INTO public.mutineries_membres (camp, personnage, role_origine)
  VALUES (v_camp, v_moi, 'lieutenant');

  -- TIRAGE ALEATOIRE parmi les soldats disponibles. Les non-tires restent strictement loyalistes.
  IF v_vises > 0 THEN
    SELECT coalesce(array_agg(mat), '{}'::text[]) INTO v_choisis FROM (
      SELECT sol->>'matricule' AS mat FROM jsonb_array_elements(v_sols) sol
       WHERE NOT coalesce((sol->>'pj')::boolean, false)
         AND coalesce((sol->>'pa')::integer, 0) > 0
         AND (sol->>'mutin') IS NULL
       ORDER BY random() LIMIT v_vises) x;

    SELECT coalesce(jsonb_agg(
             CASE WHEN sol->>'matricule' = ANY (v_choisis)
                  THEN sol || jsonb_build_object('mutin', v_camp) ELSE sol END ORDER BY pos), '[]'::jsonb)
      INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

    UPDATE public.compagnies_militaires
       SET data = public.militaire_sections_remplacer(g.o_data, v_sec,
                    v_secj || jsonb_build_object('soldats', v_sols))
     WHERE id = v_cie;
  END IF;

  RETURN jsonb_build_object('ok', true, 'camp', v_camp, 'cha', v_cha,
    'base', v_base, 'bonus_crise', v_bonus, 'social', v_social, 'ie', v_ie,
    'soldats_rallies', v_vises, 'soldats_disponibles', v_dispo,
    'soldats_restes_loyalistes', greatest(0, v_dispo - v_vises));
END;
$function$

-- militaire_objet_signature(jsonb) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.militaire_objet_signature(p_objet jsonb)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT lower(btrim(coalesce(nullif(btrim(coalesce(p_objet->>'produitMilitaire','')), ''),
                              p_objet->>'name', '?')))
      || '|' || lower(coalesce(p_objet->>'type', ''));
$function$

-- militaire_observer() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_observer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa constant integer := 1;
  c_bonus_jumelles constant integer := 30;
  v_moi text; v_pays text; v_ville text; v_bat text; v_pa integer; v_reco numeric;
  v_a_jumelles boolean; v_contacts jsonb := '[]'::jsonb;
  r record; v_bande text; v_modif integer; v_camo numeric; v_chance integer; v_jet integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_city,''), coalesce(current_building,''),
         coalesce(pa,0), coalesce((competences_militaires->>'reconnaissance')::numeric, 0),
         EXISTS (SELECT 1 FROM jsonb_array_elements(
                   CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END) i
                  WHERE i->>'produitMilitaire' = 'jumelles')
    INTO v_pays, v_ville, v_bat, v_pa, v_reco, v_a_jumelles
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF NOT v_a_jumelles THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_jumelles'); END IF;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa);
  END IF;

  UPDATE public.personnages_donnees SET pa = v_pa - c_pa WHERE name = v_moi;

  FOR r IN
    SELECT m.pays AS pays_cible, m.ville, m.building_id AS bat,
           count(*)::integer AS effectif,
           avg(coalesce((sm.formation->>'reconnaissance')::numeric, 0)) AS reco_moy,
           count(*) FILTER (WHERE EXISTS (
             SELECT 1 FROM public.pnj_possessions p
              WHERE p.pnj_id = m.id AND p.origine = 'blob_accessoires'
                AND p.objet->>'produitMilitaire' = 'tenue_camouflage'))::integer AS equipes
      FROM public.pnj_membres m
      JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE m.famille = 'soldat'
       AND m.statut  = 'actif'
       AND sm.en_reserve = false
       AND m.pays IS DISTINCT FROM v_pays
       AND coalesce(m.ville,'') <> ''
       AND EXISTS (SELECT 1 FROM public.guerres g
                    WHERE g.statut = 'active'
                      AND ((g.data->>'attaquant' = v_pays AND g.data->>'attaque' = m.pays)
                        OR (g.data->>'attaque'  = v_pays AND g.data->>'attaquant' = m.pays)))
     GROUP BY 1, 2, 3
  LOOP
    v_bande := public.militaire_bande_distance(v_pays, v_ville, v_bat, v_pays, r.ville, r.bat);
    v_modif := public.militaire_modif_distance(v_bande);
    IF v_modif IS NULL THEN v_modif := -60; END IF;
    v_camo := public.militaire_camouflage_groupe(r.reco_moy, r.effectif, r.equipes);
    v_chance := public.militaire_chance_detection(v_reco, v_camo, v_modif, c_bonus_jumelles);
    v_jet := floor(random() * 100)::integer + 1;
    CONTINUE WHEN v_jet > v_chance;
    v_contacts := v_contacts || jsonb_build_array(
      public.militaire_degrader(CASE WHEN v_modif = -60 THEN 'limite' ELSE v_bande END,
                                r.effectif, r.pays_cible, r.ville, r.bat));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pa_restants', v_pa - c_pa,
    'reconnaissance', v_reco, 'contacts', v_contacts);
END; $function$

-- militaire_ordre_collectif(text,text,text,text,text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_ordre_collectif(p_compagnie_id text, p_section_id text, p_action text, p_leader text DEFAULT NULL::text, p_matricules text[] DEFAULT NULL::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pnj_par_tente    constant integer := 12;   -- 1 tente = 13 personnes, le leader compris
  c_gain             constant integer := 1;
  c_pa_max_pnj       constant integer := 12;
  c_max_ration_jour  constant integer := 2;
  v_moi text; v_data jsonb; v_sec jsonb; v_sols jsonb; v_leader text;
  v_jour text; v_n integer := 0; v_tentes integer; v_requis integer;
  v_rations integer; v_inv jsonb; v_pos integer; i integer;
  v_a_distance boolean := false; v_radio_chef boolean; v_radio_leader boolean;
  sol jsonb; v_eligible boolean; v_src text; v_deja integer;
  v_sources jsonb := '{}'::jsonb; v_socle jsonb := '{}'::jsonb;
  v_besoin_chef integer := 0; v_propres integer := 0;
  v_nouv jsonb := '[]'::jsonb; v_mat text; v_id_poss bigint; v_ids text[] := '{}';
BEGIN
  IF p_action NOT IN ('ration', 'bivouac') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'action_invalide');
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;

  v_leader := coalesce(nullif(btrim(coalesce(p_leader,'')), ''), v_moi);

  IF v_sec->>'lieutenantNom' = v_moi THEN
    v_a_distance := (v_leader <> v_moi);
  ELSIF v_leader = v_moi THEN
    NULL;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  IF v_a_distance THEN
    SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i2
             WHERE pd.name = v_moi AND i2->>'produitMilitaire' = 'radio') INTO v_radio_chef;
    SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i2
             WHERE pd.name = v_leader AND i2->>'produitMilitaire' = 'radio') INTO v_radio_leader;
    IF NOT coalesce(v_radio_chef,false) OR NOT coalesce(v_radio_leader,false) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'radio_manquante',
        'radio_lieutenant', coalesce(v_radio_chef,false), 'radio_leader', coalesce(v_radio_leader,false));
    END IF;
  END IF;

  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  -- PA ET LEADER VIENNENT DU SOCLE. Une seule lecture, indexee par matricule.
  SELECT COALESCE(jsonb_object_agg(sm.matricule,
           jsonb_build_object('pa', m.pa, 'leader', m.leader_pj)), '{}'::jsonb)
    INTO v_socle
    FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id AND m.statut = 'actif';

  -- ===== PASSE 1 : DECIDER, SANS RIEN ECRIRE =====
  FOR sol IN SELECT value FROM jsonb_array_elements(v_sols) LOOP
    v_mat := sol->>'matricule';
    v_eligible := NOT coalesce((sol->>'pj')::boolean,false)
              AND (v_socle->v_mat->>'leader') = v_leader
              AND coalesce((v_socle->v_mat->>'pa')::numeric, 0) < c_pa_max_pnj
              AND (p_matricules IS NULL OR v_mat = ANY(p_matricules));
    IF v_eligible AND p_action = 'ration' THEN
      v_deja := CASE WHEN coalesce(sol->>'dernier_ration','') = v_jour
                     THEN coalesce((sol->>'nb_ration')::integer, 1) ELSE 0 END;
      v_eligible := v_deja < c_max_ration_jour;
    ELSIF v_eligible THEN
      v_eligible := coalesce(sol->>'dernier_bivouac','') <> v_jour;
    END IF;
    CONTINUE WHEN NOT v_eligible;
    v_n := v_n + 1;
    v_ids := v_ids || (p_compagnie_id || '-' || v_mat);

    IF p_action = 'ration' THEN
      IF EXISTS (SELECT 1 FROM public.pnj_possessions p
                  WHERE p.pnj_id = p_compagnie_id || '-' || v_mat
                    AND p.objet->>'produitMilitaire' = 'ration_combat') THEN
        v_src := 'propre';
      ELSE
        v_src := 'chef';
      END IF;
      v_sources := v_sources || jsonb_build_object(v_mat, v_src);
      IF v_src = 'chef' THEN v_besoin_chef := v_besoin_chef + 1;
      ELSE v_propres := v_propres + 1; END IF;
    ELSE
      v_sources := v_sources || jsonb_build_object(v_mat, 'chef');
    END IF;
  END LOOP;

  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_soldat_concerne');
  END IF;

  -- ===== RESSOURCES : VALIDATION GLOBALE AVANT TOUTE ECRITURE =====
  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_inv FROM public.personnages_donnees WHERE name = v_leader FOR UPDATE;
  IF p_action = 'ration' THEN
    SELECT count(*) INTO v_rations FROM jsonb_array_elements(v_inv) i2
     WHERE i2->>'produitMilitaire' = 'ration_combat';
    IF coalesce(v_rations,0) < v_besoin_chef THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'rations_insuffisantes',
        'requis', v_besoin_chef, 'disponibles', coalesce(v_rations,0),
        'soldats_concernes', v_n, 'rations_propres', v_propres);
    END IF;
  ELSE
    SELECT count(*) INTO v_tentes FROM jsonb_array_elements(v_inv) i2
     WHERE i2->>'produitMilitaire' = 'tente';
    v_requis := ceil(v_n::numeric / c_pnj_par_tente)::integer;
    IF coalesce(v_tentes,0) < v_requis THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'tentes_insuffisantes',
        'requis', v_requis, 'disponibles', coalesce(v_tentes,0),
        'pnj_par_tente', c_pnj_par_tente, 'capacite_tente_personnes', c_pnj_par_tente + 1);
    END IF;
  END IF;

  -- ===== PASSE 2 : APPLIQUER. Les PA par le socle, les compteurs par le blob. =====
  PERFORM public.pnj_pa_crediter(v_ids, c_gain);

  FOR sol IN SELECT value FROM jsonb_array_elements(v_sols) LOOP
    v_mat := sol->>'matricule';
    v_src := v_sources->>v_mat;
    IF v_src IS NULL THEN
      v_nouv := v_nouv || jsonb_build_array(sol);
      CONTINUE;
    END IF;
    IF p_action = 'ration' THEN
      sol := sol || jsonb_build_object('dernier_ration', v_jour,
               'nb_ration', (CASE WHEN coalesce(sol->>'dernier_ration','') = v_jour
                                  THEN coalesce((sol->>'nb_ration')::integer, 1) ELSE 0 END) + 1);
      IF v_src = 'propre' THEN
        SELECT p.id INTO v_id_poss FROM public.pnj_possessions p
         WHERE p.pnj_id = p_compagnie_id || '-' || v_mat
           AND p.objet->>'produitMilitaire' = 'ration_combat' ORDER BY p.id LIMIT 1;
        DELETE FROM public.pnj_possessions WHERE id = v_id_poss;
      END IF;
    ELSE
      sol := sol || jsonb_build_object('dernier_bivouac', v_jour);
    END IF;
    v_nouv := v_nouv || jsonb_build_array(sol);
  END LOOP;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_nouv))
   WHERE id = p_compagnie_id;
  PERFORM public.militaire_blob_projeter(p_compagnie_id);

  IF p_action = 'ration' AND v_besoin_chef > 0 THEN
    FOR i IN 1 .. v_besoin_chef LOOP
      SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i2, pos)
       WHERE i2->>'produitMilitaire' = 'ration_combat' ORDER BY pos LIMIT 1;
      SELECT coalesce(jsonb_agg(i2 ORDER BY pos), '[]'::jsonb) INTO v_inv
        FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i2, pos) WHERE pos <> v_pos;
    END LOOP;
    UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_leader;
  END IF;

  RETURN jsonb_build_object('ok', true, 'action', p_action, 'leader', v_leader,
    'soldats', v_n, 'a_distance', v_a_distance, 'gain_pa', c_gain,
    'individuel', (p_matricules IS NOT NULL),
    'tentes_requises', CASE WHEN p_action='bivouac' THEN v_requis END,
    'pnj_par_tente', CASE WHEN p_action='bivouac' THEN c_pnj_par_tente END,
    'rations_consommees', CASE WHEN p_action='ration' THEN v_n END,
    'rations_propres', CASE WHEN p_action='ration' THEN v_propres END,
    'rations_du_chef', CASE WHEN p_action='ration' THEN v_besoin_chef END,
    'max_ration_jour', CASE WHEN p_action='ration' THEN c_max_ration_jour END);
END; $function$

-- militaire_ordre_pnj(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_ordre_pnj(p_pnj_id text, p_action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; s record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT m.id, m.statut, m.leader_pj, m.famille,
         sm.compagnie_id, sm.section_id, sm.matricule, sm.en_reserve
    INTO s
    FROM public.pnj_membres m
    LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE m.id = p_pnj_id;
  IF s.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pnj_introuvable'); END IF;
  IF s.matricule IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_soldat', 'famille', s.famille); END IF;
  IF s.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pnj_inactif', 'statut', s.statut); END IF;
  IF s.en_reserve OR s.section_id IS NULL OR s.compagnie_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'soldat_en_reserve'); END IF;
  RETURN public.militaire_ordre_collectif(s.compagnie_id, s.section_id, p_action,
                                          s.leader_pj, ARRAY[s.matricule]);
END; $function$

-- militaire_pa_restants(integer,text) -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.militaire_pa_restants(p_pa integer, p_degre text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT greatest(0, floor(greatest(0, coalesce(p_pa, 0))
                           * (1 - public.militaire_degats_pct(p_degre)))::integer);
$function$

-- militaire_places_libres_grade(text,text,text,text) -> integer | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_places_libres_grade(p_pays text, p_grade text, p_compagnie_id text, p_section_id text)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE c_places constant integer := 24;
        v_occupe integer; v_reserve integer; v_sec jsonb;
BEGIN
  SELECT count(*) INTO v_reserve FROM public.candidatures_militaires cm
   WHERE cm.statut = 'acceptee' AND cm.echeance > now()
     AND cm.pays = p_pays AND cm.grade_vise = p_grade
     AND cm.compagnie_id IS NOT DISTINCT FROM p_compagnie_id
     AND cm.section_id IS NOT DISTINCT FROM p_section_id;

  IF p_grade = 'capitaine' THEN
    SELECT count(*) INTO v_occupe FROM public.compagnies_militaires c
     WHERE c.id = p_compagnie_id AND coalesce(c.data->>'capitaineNom','') <> '';
    RETURN greatest(0, 1 - v_occupe - v_reserve);

  ELSIF p_grade = 'lieutenant' THEN
    SELECT s INTO v_sec FROM public.compagnies_militaires c,
           jsonb_array_elements(c.data->'sections') s
     WHERE c.id = p_compagnie_id AND s->>'id' = p_section_id;
    IF v_sec IS NULL THEN RETURN 0; END IF;
    v_occupe := CASE WHEN coalesce(v_sec->>'lieutenantNom','') <> '' THEN 1 ELSE 0 END;
    RETURN greatest(0, 1 - v_occupe - v_reserve);

  ELSIF p_grade = 'soldat' THEN
    -- Seuls les JOUEURS bloquent reellement une place : la filiere existante evince le premier
    -- PNJ venu et le renvoie INTACT en reserve pour faire entrer un joueur. Compter les PNJ
    -- comme des places prises fermerait une section pleine de PNJ a tout engagement.
    SELECT s INTO v_sec FROM public.compagnies_militaires c,
           jsonb_array_elements(c.data->'sections') s
     WHERE c.id = p_compagnie_id AND s->>'id' = p_section_id;
    IF v_sec IS NULL THEN RETURN 0; END IF;
    SELECT count(*) INTO v_occupe
      FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
     WHERE coalesce((s->>'pj')::boolean, false);
    RETURN greatest(0, c_places - v_occupe - v_reserve);
  END IF;
  RETURN 0;
END;
$function$

-- militaire_position_repli(text,text,text,text) -> jsonb | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_position_repli(p_nom text, p_ville text, p_bat text, p_piece text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT jsonb_build_object('ville', h.city, 'batiment', h.building_id, 'piece', h.room_id)
    FROM public.historique_deplacements h
   WHERE p_nom IS NOT NULL AND h.name = p_nom
     AND NOT (h.city = p_ville AND h.building_id = p_bat AND h.room_id = p_piece)
   ORDER BY h.created_at DESC LIMIT 1;
$function$

-- militaire_presentation_affectation() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_presentation_affectation()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa constant integer := 1;
  v_moi text; v_pays text; v_bat text; v_pa integer;
  v_req jsonb; v_recherche jsonb; v_recherche2 jsonb;
  v_statut text; v_deserteur boolean; v_maintenant numeric; v_deadline numeric;
  v_cid text; v_sid text; v_data jsonb; v_sec jsonb; v_liste jsonb;
  v_inscrit boolean := false; v_numero text; v_paye jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(p.country, 'republic'), coalesce(p.current_building, ''), coalesce(p.pa, 0),
         p.requisition, coalesce(p.recherche, '[]'::jsonb)
    INTO v_pays, v_bat, v_pa, v_req, v_recherche
    FROM public.personnages_donnees p WHERE p.name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- La colonne est jsonb, mais le client y ecrivait un JSON.stringify : la valeur peut donc
  -- etre soit un objet, soit une CHAINE json contenant l'objet. Les deux sont acceptees.
  IF jsonb_typeof(v_req) = 'string' THEN
    BEGIN v_req := (v_req #>> '{}')::jsonb; EXCEPTION WHEN others THEN v_req := NULL; END;
  END IF;
  IF v_req IS NULL OR jsonb_typeof(v_req) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_convocation');
  END IF;

  v_statut := coalesce(v_req->>'statut', '');
  v_deserteur := (v_statut = 'deserteur');
  IF v_statut NOT IN ('convoque', 'deserteur') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_convocation', 'statut', v_statut);
  END IF;
  -- Presence reelle exigee, comme militaire_retrait et militaire_candidater_soldat.
  IF v_bat <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  v_maintenant := floor(extract(epoch FROM now()) * 1000);
  v_deadline := CASE WHEN (v_req->>'deadline') ~ '^[0-9]+(\.[0-9]+)?$'
                     THEN (v_req->>'deadline')::numeric ELSE NULL END;
  -- Un DESERTEUR se rend a tout moment, sans delai : c'est ce qui fait de la reddition une
  -- option de jeu. Un convoque, lui, reste tenu par son delai.
  IF NOT v_deserteur AND v_deadline IS NOT NULL AND v_deadline < v_maintenant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_depasse');
  END IF;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa, 'pa_reel', v_pa);
  END IF;

  -- 1. LE BLOB DE LA COMPAGNIE, ecrit par le serveur (le civil n'a aucune autorite dessus).
  v_cid := v_req->>'compagnieId';
  v_sid := v_req->>'sectionId';
  IF v_cid IS NOT NULL THEN
    SELECT c.data INTO v_data FROM public.compagnies_militaires c WHERE c.id = v_cid FOR UPDATE;
  END IF;
  IF v_data IS NOT NULL THEN
    SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections', '[]'::jsonb)) s
     WHERE s->>'id' = v_sid;
    IF v_sec IS NOT NULL THEN
      v_numero := v_sec->>'numero';
      SELECT coalesce(jsonb_agg(CASE WHEN e->>'nom' = v_moi
                                     THEN e || jsonb_build_object('statut', 'affecte') ELSE e END), '[]'::jsonb),
             coalesce(bool_or(e->>'nom' = v_moi), false)
        INTO v_liste, v_inscrit
        FROM jsonb_array_elements(coalesce(v_sec->'civilsRequisitionnes', '[]'::jsonb)) e;
      UPDATE public.compagnies_militaires
         SET data = public.militaire_sections_remplacer(v_data, v_sid,
                      v_sec || jsonb_build_object('civilsRequisitionnes', coalesce(v_liste, '[]'::jsonb)))
       WHERE id = v_cid;
    END IF;
  END IF;

  -- 2. LA FICHE DU JOUEUR. La presentation ETEINT les poursuites pour desertion -- et elles
  -- seules : on FILTRE le tableau `recherche`, on ne le remplace jamais (tout autre motif,
  -- crime, condamnation en attente, motif d'un autre empire, survit intact).
  v_req := v_req || jsonb_build_object('statut', 'affecte');
  v_recherche2 := v_recherche;
  IF v_deserteur THEN
    SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_recherche2
      FROM jsonb_array_elements(v_recherche) e
     WHERE NOT (coalesce(e->>'acte', '') = 'desertion'
                AND coalesce(e->>'country', v_pays) = v_pays);
  END IF;
  UPDATE public.personnages_donnees
     SET requisition = v_req, recherche = v_recherche2
   WHERE name = v_moi;

  -- 3. LE PAIEMENT, en dernier et sous le meme verrou : payer_ordre relit le cout dans le
  -- miroir declare. Un refus a ce stade annule TOUT (exception = rollback), jamais un effet
  -- accorde sans contrepartie.
  v_paye := public.payer_ordre(v_moi, 'se_presenter_affectation', c_pa, 0);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_presentation_affectation: paiement refuse (%)',
      coalesce(v_paye->>'raison', 'motif inconnu');
  END IF;

  RETURN jsonb_build_object('ok', true, 'deserteur', v_deserteur, 'section', v_numero,
    'compagnie', v_cid, 'inscrit', v_inscrit, 'requisition', v_req,
    'recherche', v_recherche2, 'pa', v_paye->'pa');
END;
$function$

-- militaire_proposer_capitaine(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_proposer_capitaine(p_compagnie_id text, p_destinataire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_acteur text; v_pays text; v_data jsonb; v_id text;
BEGIN
  v_acteur := public.exiger_poste('commandant');           -- leve si ce n'est pas le Commandant
  IF v_acteur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;

  SELECT data::jsonb INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF COALESCE(v_data->>'capitaineNom','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_deja_commandee', 'capitaine', v_data->>'capitaineNom');
  END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name = p_destinataire AND country = v_pays;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;

  DELETE FROM public.nominations_militaires
   WHERE compagnie_id = p_compagnie_id AND grade = 'capitaine' AND traitee = false;
  v_id := 'nomil-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.nominations_militaires (id, pays, grade, compagnie_id, section_id, destinataire, par)
  VALUES (v_id, v_pays, 'capitaine', p_compagnie_id, NULL, p_destinataire, v_acteur);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'destinataire', p_destinataire);
END; $function$

-- militaire_proposer_lieutenant(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_proposer_lieutenant(p_compagnie_id text, p_section_id text, p_destinataire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_pays text; v_data jsonb; v_sec jsonb; v_id text; v_nb int;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'capitaineNom' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_capitaine_de_cette_compagnie'); END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;
  v_nb := COALESCE(jsonb_array_length(v_data->'sections'), 0);
  IF v_nb > 4 THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_incoherente', 'sections', v_nb); END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id LIMIT 1;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
  IF COALESCE(v_sec->>'lieutenantNom','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_deja_commandee'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name = p_destinataire AND country = v_pays;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;

  DELETE FROM public.nominations_militaires
   WHERE compagnie_id = p_compagnie_id AND section_id = p_section_id
     AND grade = 'lieutenant' AND traitee = false;
  v_id := 'nomil-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.nominations_militaires (id, pays, grade, compagnie_id, section_id, destinataire, par)
  VALUES (v_id, v_pays, 'lieutenant', p_compagnie_id, p_section_id, p_destinataire, v_moi);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'destinataire', p_destinataire);
END; $function$

-- militaire_ration_consommer() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_ration_consommer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa_max_pj    constant integer := 30;
  c_gain         constant integer := 1;
  c_max_par_jour constant integer := 2;
  v_moi text; v_inv jsonb; v_stats jsonb; v_pos integer;
  v_pa_avant integer; v_pa_apres integer; v_reste integer;
  v_jour text; v_deja integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  -- VERROU AVANT TOUTE LECTURE : deux appels simultanes sont serialises ici, le second relit
  -- un inventaire et un compteur deja a jour. Ni la ration ni le quota ne peuvent etre doubles.
  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END,
         CASE WHEN jsonb_typeof(stats) = 'object' THEN stats ELSE '{}'::jsonb END,
         coalesce(pa, 0)
    INTO v_inv, v_stats, v_pa_avant
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;
  v_deja := CASE WHEN coalesce(v_stats->>'rationsCombatJour', '') = v_jour
                 THEN coalesce((v_stats->>'rationsCombatNb')::integer, 0) ELSE 0 END;

  -- LA POSSESSION EST VERIFIEE ICI, jamais crue sur parole. La premiere ration trouvee est
  -- consommee : elles sont interchangeables, aucun choix a offrir au joueur.
  SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
   WHERE i->>'produitMilitaire' = 'ration_combat' ORDER BY pos LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_ration'); END IF;

  -- LES DEUX REFUS CONSERVENT LA RATION : aucune ecriture n'a encore eu lieu a ce stade.
  IF v_pa_avant >= c_pa_max_pj THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_maximum', 'pa', v_pa_avant, 'plafond', c_pa_max_pj);
  END IF;
  IF v_deja >= c_max_par_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_quotidien',
      'consommees_aujourdhui', v_deja, 'maximum', c_max_par_jour);
  END IF;

  v_pa_apres := least(c_pa_max_pj, v_pa_avant + c_gain);

  -- USAGE UNIQUE : la ration quitte l'inventaire dans la MEME transaction que le gain et que
  -- l'incrementation du compteur du jour.
  SELECT coalesce(jsonb_agg(i ORDER BY pos), '[]'::jsonb) INTO v_inv
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos) WHERE pos <> v_pos;

  UPDATE public.personnages_donnees
     SET inventory = v_inv, pa = v_pa_apres,
         stats = v_stats || jsonb_build_object('rationsCombatJour', v_jour,
                                               'rationsCombatNb', v_deja + 1)
   WHERE name = v_moi;

  SELECT count(*)::integer INTO v_reste FROM jsonb_array_elements(v_inv) i
   WHERE i->>'produitMilitaire' = 'ration_combat';

  RETURN jsonb_build_object('ok', true, 'pa_avant', v_pa_avant, 'pa_apres', v_pa_apres,
    'gain_reel', v_pa_apres - v_pa_avant, 'rations_restantes', v_reste,
    'consommees_aujourdhui', v_deja + 1, 'maximum', c_max_par_jour);
END;
$function$

-- militaire_rations_retirer(integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_rations_retirer(p_nombre integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_plafond constant integer := 100;
  v_moi text; v_pays text; v_bat text; v_inv jsonb; v_occupe numeric;
  v_data jsonb; v_ref jsonb; v_dispo integer; v_n integer; i integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_n := greatest(0, coalesce(p_nombre, 0));
  IF v_n = 0 OR v_n > 50 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_building,''),
         CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_pays, v_bat, v_inv FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_bat <> 'caserne-militaire' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  SELECT coalesce(sum(greatest(1, coalesce((i2->>'qty')::numeric, (i2->>'encombrement')::numeric, 1))), 0)
    INTO v_occupe FROM jsonb_array_elements(v_inv) i2;
  IF v_occupe + v_n > c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'plafond', c_plafond);
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  v_ref := CASE WHEN jsonb_typeof(v_data->'refectoire')='object' THEN v_data->'refectoire' ELSE '{}'::jsonb END;
  v_dispo := greatest(0, coalesce((v_ref->>'rations')::integer, 0));
  IF v_dispo < v_n THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rations_insuffisantes', 'disponibles', v_dispo);
  END IF;

  UPDATE public.budgets_nationaux
     SET data = v_data || jsonb_build_object('refectoire', v_ref || jsonb_build_object('rations', v_dispo - v_n)),
         updated_at = now()
   WHERE id = v_pays;

  FOR i IN 1 .. v_n LOOP
    v_inv := v_inv || jsonb_build_array(jsonb_build_object(
      'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
      'type', 'vivres', 'sousType', 'militaire', 'produitMilitaire', 'ration_combat',
      'origineMilitaire', true, 'usageUnique', true,
      'name', 'Ration de combat', 'icon', 'ti-soup', 'legal', true,
      'imageUrl', 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/militaire-ration-combat.png',
      'desc', 'Ration de combat. +1 PA par ration, 2 rations par jour au maximum.'));
  END LOOP;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'retirees', v_n, 'restantes', v_dispo - v_n);
END;
$function$

-- militaire_recruteur_de_moi() -> record | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_recruteur_de_moi(OUT o_moi text, OUT o_pays text, OUT o_grade_recrute text, OUT o_compagnie text, OUT o_section text, OUT o_raison text)
 RETURNS record
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_poste jsonb;
BEGIN
  o_moi := public.mon_personnage();
  IF o_moi IS NULL THEN o_raison := 'acteur_non_authentifie'; RETURN; END IF;

  SELECT coalesce(country,'republic'), poste INTO o_pays, v_poste
    FROM public.personnages_donnees WHERE name = o_moi;
  IF o_pays IS NULL THEN o_raison := 'personnage_introuvable'; RETURN; END IF;
  IF jsonb_typeof(v_poste) <> 'object' THEN o_raison := 'pas_recruteur'; RETURN; END IF;

  IF v_poste->>'id' = 'commandant' THEN
    o_grade_recrute := 'capitaine';
  ELSIF v_poste->>'id' = 'capitaine' THEN
    o_grade_recrute := 'lieutenant'; o_compagnie := v_poste->>'compagnieId';
  ELSIF v_poste->>'id' = 'lieutenant' THEN
    o_grade_recrute := 'soldat';
    o_compagnie := v_poste->>'compagnieId'; o_section := v_poste->>'sectionId';
  ELSE
    o_raison := 'pas_recruteur'; RETURN;
  END IF;
END;
$function$

-- militaire_recuperer_soldats(text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_recuperer_soldats(p_compagnie_id text, p_section_id text, p_nb integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE g record; v_ville text; v_bat text; v_room text; v_dispo int;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;

  SELECT current_city, current_building, current_room INTO v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = g.o_moi;
  IF COALESCE(v_bat,'') = '' OR COALESCE(v_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue');
  END IF;

  SELECT count(*) INTO v_dispo
    FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND m.statut = 'actif' AND m.leader_pj IS NULL AND m.leader_pnj_id IS NULL
     AND m.ville = v_ville AND m.building_id = v_bat AND m.room_id = v_room;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'effectif_insuffisant_ici', 'disponibles', v_dispo);
  END IF;

  UPDATE public.pnj_membres
     SET leader_pj = g.o_moi, leader_pnj_id = NULL,
         ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL, maj_le = now()
   WHERE id IN (SELECT m.id FROM public.pnj_membres m
                  JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
                 WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
                   AND m.statut = 'actif' AND m.leader_pj IS NULL AND m.leader_pnj_id IS NULL
                   AND m.ville = v_ville AND m.building_id = v_bat AND m.room_id = v_room
                 ORDER BY sm.matricule LIMIT p_nb);
  PERFORM public.militaire_blob_projeter(p_compagnie_id);

  RETURN jsonb_build_object('ok', true, 'recuperes', p_nb, 'leader', g.o_moi);
END; $function$

-- militaire_reposer_section(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_reposer_section(p_compagnie_id text, p_section_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa_max         constant integer := 12;
  c_gain_terrain   constant integer := 8;
  c_bonus_tente    constant integer := 2;
  c_pnj_par_tente  constant integer := 12;
  g record; v_sec jsonb; v_sols jsonb; v_jour text;
  v_caserne integer := 0; v_tente integer := 0; v_terrain integer := 0;
  v_deja integer := 0; v_total integer := 0;
  v_ids_caserne text[]; v_ids_tente text[]; v_ids_terrain text[]; v_servis jsonb;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', g.o_raison);
  END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s
   WHERE s->>'id' = p_section_id;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  CREATE TEMP TABLE IF NOT EXISTS pg_temp_repos
    (id text, matricule text, sort text) ON COMMIT DROP;
  DELETE FROM pg_temp_repos;

  -- Le batiment retenu est celui du CHEF quand le soldat le suit, sinon le sien. Un PNJ qui suit
  -- un leader est reellement la ou est son leader : c'est le referentiel commun PJ/PNJ.
  INSERT INTO pg_temp_repos (id, matricule, sort)
  WITH base AS (
    SELECT m.id, sm.matricule, m.pa, m.leader_pj,
           COALESCE(sm.dernier_sommeil, '') AS marqueur,
           COALESCE(pd.current_building, m.building_id) AS batiment
      FROM public.pnj_soldats_metier sm
      JOIN public.pnj_membres m ON m.id = sm.pnj_id
      LEFT JOIN public.personnages_donnees pd ON pd.name = m.leader_pj
     WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
       AND m.statut = 'actif'
  ), eligible AS (
    SELECT b.*, (b.pa > 0 AND b.marqueur <> v_jour) AS peut,
           (COALESCE(b.batiment,'') = 'caserne-militaire') AS a_la_caserne
      FROM base b
  ), tentes AS (
    SELECT l.leader_pj,
           (SELECT count(*) FROM jsonb_array_elements(
                     CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
             WHERE i->>'produitMilitaire' = 'tente')::integer AS nb
      FROM (SELECT DISTINCT leader_pj FROM eligible
             WHERE peut AND NOT a_la_caserne AND leader_pj IS NOT NULL) l
      JOIN public.personnages_donnees pd ON pd.name = l.leader_pj
  ), rang AS (
    SELECT id, leader_pj,
           row_number() OVER (PARTITION BY leader_pj ORDER BY matricule) AS n
      FROM eligible WHERE peut AND NOT a_la_caserne AND leader_pj IS NOT NULL
  )
  SELECT e.id, e.matricule,
         CASE WHEN NOT e.peut     THEN 'aucun'
              WHEN e.a_la_caserne THEN 'caserne'
              WHEN r.n IS NOT NULL AND r.n <= COALESCE(t.nb, 0) * c_pnj_par_tente THEN 'tente'
              ELSE 'terrain' END
    FROM eligible e
    LEFT JOIN rang   r ON r.id = e.id
    LEFT JOIN tentes t ON t.leader_pj = e.leader_pj;

  SELECT count(*) FILTER (WHERE sort='caserne'), count(*) FILTER (WHERE sort='tente'),
         count(*) FILTER (WHERE sort='terrain'), count(*)
    INTO v_caserne, v_tente, v_terrain, v_total FROM pg_temp_repos;
  SELECT count(*) INTO v_deja
    FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND m.statut = 'actif' AND m.pa > 0 AND COALESCE(sm.dernier_sommeil,'') = v_jour;

  IF v_caserne + v_tente + v_terrain = 0 THEN
    RETURN jsonb_build_object('ok', true, 'caserne', 0, 'tente', 0, 'terrain', 0,
      'deja_reposes', v_deja, 'effectif', v_total, 'reposes', 0,
      'pnj_par_tente', c_pnj_par_tente);
  END IF;

  SELECT coalesce(array_agg(id) FILTER (WHERE sort='caserne'), '{}'::text[]),
         coalesce(array_agg(id) FILTER (WHERE sort='tente'),   '{}'::text[]),
         coalesce(array_agg(id) FILTER (WHERE sort='terrain'), '{}'::text[])
    INTO v_ids_caserne, v_ids_tente, v_ids_terrain FROM pg_temp_repos;

  -- LES PA, PAR LE SOCLE. La caserne remet au plein, le reste credite.
  IF array_length(v_ids_caserne,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_fixer(v_ids_caserne, c_pa_max); END IF;
  IF array_length(v_ids_tente,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_crediter(v_ids_tente, c_gain_terrain + c_bonus_tente); END IF;
  IF array_length(v_ids_terrain,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_crediter(v_ids_terrain, c_gain_terrain); END IF;

  -- LE MARQUEUR, PAR LE BLOB : c'est une donnee metier.
  SELECT coalesce(jsonb_agg(matricule), '[]'::jsonb) INTO v_servis
    FROM pg_temp_repos WHERE sort <> 'aucun';
  SELECT coalesce(jsonb_agg(
           CASE WHEN v_servis ? (sol->>'matricule')
                THEN sol || jsonb_build_object('dernier_sommeil', v_jour)
                ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  PERFORM public.militaire_blob_projeter(p_compagnie_id);

  RETURN jsonb_build_object('ok', true,
    'caserne', v_caserne, 'tente', v_tente, 'terrain', v_terrain,
    'deja_reposes', v_deja, 'effectif', v_total,
    'reposes', v_caserne + v_tente + v_terrain,
    'pnj_par_tente', c_pnj_par_tente);
END; $function$

-- militaire_requisition_civile(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_requisition_civile(p_compagnie_id text, p_section_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa       constant integer := 3;
  c_heures   constant integer := 48;
  c_effectif constant integer := 24;
  v_moi text; v_pays text; v_pa integer; v_mobilisee boolean;
  v_data jsonb; v_sec jsonb; v_liste jsonb; v_noms text[];
  v_deadline numeric; v_paye jsonb;
BEGIN
  -- Poste ATTESTE : exiger_poste leve 42501 si l'appelant n'est pas reellement min_def.
  v_moi := public.exiger_poste('min_def');
  IF v_moi IS NULL THEN v_moi := public.mon_personnage(); END IF;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(p.country, 'republic'), coalesce(p.pa, 0) INTO v_pays, v_pa
    FROM public.personnages_donnees p WHERE p.name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT coalesce((b.data->>'mobilisationNationaleActive')::boolean, false) INTO v_mobilisee
    FROM public.budgets_nationaux b WHERE b.id = v_pays;
  IF NOT coalesce(v_mobilisee, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mobilisation_inactive');
  END IF;

  SELECT c.data INTO v_data FROM public.compagnies_militaires c
   WHERE c.id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable');
  END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections', '[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable');
  END IF;
  IF coalesce(v_sec->>'lieutenantNom', '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_sans_lieutenant');
  END IF;
  IF jsonb_array_length(coalesce(v_sec->'civilsRequisitionnes', '[]'::jsonb)) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_requisitionnee');
  END IF;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa, 'pa_reel', v_pa);
  END IF;

  -- TIRAGE AU SORT, cote serveur : le client ne choisit plus qui est requisitionne. Memes
  -- exclusions que la liste d'origine (officiers, ministres, maire) + le ministre lui-meme.
  SELECT array_agg(q.name) INTO v_noms FROM (
    SELECT p.name FROM public.personnages_donnees p
     WHERE coalesce(p.domicile->>'country', p.country, 'republic') = v_pays
       AND coalesce(p.poste->>'id', '') NOT IN ('lieutenant','capitaine','commandant','min_def',
             'president','pm','min_int','min_fin','min_just','min_info','min_ae','maire')
       AND p.name <> v_moi
     ORDER BY random() LIMIT c_effectif) q;
  IF v_noms IS NULL OR array_length(v_noms, 1) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_civil_eligible');
  END IF;

  v_deadline := floor(extract(epoch FROM now()) * 1000) + c_heures * 3600000;
  SELECT jsonb_agg(jsonb_build_object('nom', n, 'statut', 'convoque', 'deadline', v_deadline))
    INTO v_liste FROM unnest(v_noms) n;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('civilsRequisitionnes', v_liste))
   WHERE id = p_compagnie_id;

  UPDATE public.personnages_donnees p
     SET requisition = jsonb_build_object('compagnieId', p_compagnie_id, 'sectionId', p_section_id,
                                          'deadline', v_deadline, 'statut', 'convoque')
   WHERE p.name = ANY(v_noms);

  v_paye := public.payer_ordre(v_moi, 'mobilisation_nationale', c_pa, 0);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_requisition_civile: paiement refuse (%)',
      coalesce(v_paye->>'raison', 'motif inconnu');
  END IF;

  RETURN jsonb_build_object('ok', true, 'convoques', to_jsonb(v_noms),
    'nombre', array_length(v_noms, 1), 'deadline', v_deadline, 'delai_heures', c_heures,
    'section', v_sec->>'numero', 'lieutenant', v_sec->>'lieutenantNom', 'pa', v_paye->'pa');
END;
$function$

-- militaire_retrait(text,text,integer,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_retrait(p_pays text, p_produit text, p_quantite integer, p_lieutenant text, p_section text, p_jour integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_plafond constant integer := 100;
  v_pj public.personnages%ROWTYPE;
  v_mvt jsonb; v_lot jsonb; v_inv jsonb; v_occupe numeric; v_poses integer := 0;
  v_label text; v_type text; v_soustype text; v_icon text; v_img text; v_desc text; v_trouve boolean;
BEGIN
  PERFORM public.exiger_acteur(p_lieutenant);
  IF COALESCE(p_quantite, 0) <= 0 OR p_quantite > 1000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;

  -- Forme de l'objet, miroir de RECETTES_MILITAIRES. La liste EST la liste blanche : un produit
  -- absent d'ici est refuse, donc il n'existe pas deux listes a tenir a jour.
  SELECT true, r.label, r.t, r.st, r.ic, r.im, r.de
    INTO v_trouve, v_label, v_type, v_soustype, v_icon, v_img, v_desc
    FROM (VALUES
      ('arme_de_poing', 'Pistolet militaire', 'arme', 'militaire', 'ti-crosshair',
       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-militaire.png',
       'Arme de poing réglementaire de l''armée de Républia.'),
      ('mitraillette', 'Mitraillette', 'arme', 'militaire', 'ti-crosshair',
       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-mitraillette-militaire.png',
       'Arme automatique réglementaire de l''armée de Républia.'),
      ('explosif_militaire', 'Explosifs militaires', 'explosif', 'militaire', 'ti-bomb',
       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/explosifs-militaires.png',
       'Explosifs réglementaires de l''armée de Républia.'),
      ('gilet_pare_balles', 'Gilet pare-balles', 'equipement', 'militaire', 'ti-shield-check', NULL,
       'Gilet pare-balles réglementaire. Protège contre les attaques pertinentes, notamment les tirs.'),
      ('radio', 'Radio de campagne', 'equipement', 'militaire', 'ti-radio', NULL,
       'Poste radio de campagne. Relais de commandement : permet de transmettre des ordres à distance.'),
      ('tente', 'Tente de campagne', 'equipement', 'militaire', 'ti-tent', NULL,
       'Tente de campagne. Abrite 13 personnes en bivouac. Aucun montage à ordonner.'),
      ('jumelles', 'Jumelles', 'equipement', 'militaire', 'ti-binoculars', NULL,
       'Jumelles d''observation. Renseignement toujours approximatif.'),
      ('tenue_camouflage', 'Tenue de camouflage', 'equipement', 'militaire', 'ti-eye-off', NULL,
       'Tenue de camouflage. Protège CELUI QUI LA PORTE.')
    ) AS r(p, label, t, st, ic, im, de) WHERE r.p = p_produit;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_invalide', 'produit', p_produit);
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_lieutenant FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  IF COALESCE(v_pj.poste ->> 'id', '') <> 'lieutenant' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef_de_section');
  END IF;

  v_inv := CASE WHEN jsonb_typeof(v_pj.inventory) = 'array' THEN v_pj.inventory ELSE '[]'::jsonb END;
  SELECT coalesce(sum(greatest(1,
           coalesce((i->>'qty')::numeric, (i->>'encombrement')::numeric, 1))), 0)
    INTO v_occupe FROM jsonb_array_elements(v_inv) i;
  IF v_occupe + p_quantite > c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein',
                              'occupe', v_occupe, 'plafond', c_plafond, 'demande', p_quantite);
  END IF;

  v_mvt := public.caserne_stock_mouvement(p_pays, p_produit, -p_quantite, NULL);
  IF COALESCE((v_mvt ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;

  FOR v_lot IN SELECT value FROM jsonb_array_elements(COALESCE(v_mvt -> 'lots', '[]'::jsonb)) LOOP
    INSERT INTO public.retraits_materiel_militaire
      (pays, materiel, lot, quantite, lieutenant, section, jour)
    VALUES (p_pays, p_produit, v_lot ->> 'lot', (v_lot ->> 'qte')::integer, p_lieutenant, p_section, p_jour);

    FOR i IN 1 .. greatest(0, coalesce((v_lot ->> 'qte')::integer, 0)) LOOP
      v_inv := v_inv || jsonb_build_array(jsonb_build_object(
        'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
        'type', v_type, 'sousType', v_soustype,
        'origineMilitaire', true, 'lot', coalesce(v_lot ->> 'lot', 'legacy'),
        'produitMilitaire', p_produit,
        'name', v_label, 'icon', v_icon, 'legal', true, 'imageUrl', v_img,
        'desc', v_desc || ' Lot ' || coalesce(v_lot ->> 'lot', 'legacy') || '.'));
      v_poses := v_poses + 1;
    END LOOP;
  END LOOP;

  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_lieutenant;
  RETURN v_mvt || jsonb_build_object('registre', true, 'objets_poses', v_poses,
                                     'inventaire_serveur', true);
END;
$function$

-- militaire_section_de_moi(text,text) -> record | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_section_de_moi(p_compagnie_id text, p_section_id text, OUT o_moi text, OUT o_data jsonb, OUT o_raison text)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_pays text; v_sec jsonb;
BEGIN
  o_moi := public.mon_personnage();
  IF o_moi IS NULL THEN o_raison := 'acteur_non_authentifie'; RETURN; END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = o_moi;
  SELECT data INTO o_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF o_data IS NULL THEN o_raison := 'compagnie_introuvable'; RETURN; END IF;
  IF o_data->>'pays' IS DISTINCT FROM v_pays THEN o_raison := 'hors_juridiction'; RETURN; END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(COALESCE(o_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id LIMIT 1;
  IF v_sec IS NULL THEN o_raison := 'section_introuvable'; RETURN; END IF;
  IF v_sec->>'lieutenantNom' IS DISTINCT FROM o_moi THEN
    o_raison := 'pas_lieutenant_de_cette_section'; RETURN;
  END IF;
  o_raison := NULL;
END; $function$

-- militaire_sections_remplacer(jsonb,text,jsonb) -> jsonb | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.militaire_sections_remplacer(p_data jsonb, p_section_id text, p_nouvelle jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT p_data || jsonb_build_object('sections', COALESCE((
    SELECT jsonb_agg(CASE WHEN s->>'id' = p_section_id THEN p_nouvelle ELSE s END ORDER BY ord)
      FROM jsonb_array_elements(COALESCE(p_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord)
  ), '[]'::jsonb));
$function$

-- militaire_service_fermer(text,text) -> void | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_service_fermer(p_nom text, p_grade text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.services_militaires SET fin_ts = now()
   WHERE personnage = p_nom AND grade = p_grade AND fin_ts IS NULL;
END; $function$

-- militaire_service_jours(text,text) -> numeric | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_service_jours(p_nom text, p_grade text)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT coalesce(sum(extract(epoch FROM (coalesce(fin_ts, now()) - debut_ts)) / 86400.0), 0)
    FROM public.services_militaires
   WHERE personnage = p_nom AND (p_grade IS NULL OR grade = p_grade);
$function$

-- militaire_service_ouvrir(text,text,text,text,text) -> void | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_service_ouvrir(p_nom text, p_pays text, p_grade text, p_compagnie text, p_section text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Idempotent : une periode deja ouverte pour ce grade n'est pas dupliquee (index unique
  -- partiel). Un double clic ou un rejeu ne cree donc pas deux services simultanes.
  INSERT INTO public.services_militaires (personnage, pays, grade, compagnie_id, section_id)
  SELECT p_nom, p_pays, p_grade, p_compagnie, p_section
   WHERE NOT EXISTS (SELECT 1 FROM public.services_militaires
                      WHERE personnage = p_nom AND grade = p_grade AND fin_ts IS NULL);
END; $function$

-- militaire_soldat_pa_fixer(text,text,text,integer) -> void | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_soldat_pa_fixer(p_compagnie_id text, p_section_id text, p_matricule text, p_pa integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.pnj_pa_fixer(ARRAY[p_compagnie_id || '-' || p_matricule], p_pa);
  PERFORM public.militaire_blob_projeter(p_compagnie_id);
END; $function$

-- militaire_soldat_retirer(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_soldat_retirer(p_compagnie_id text, p_section_id text, p_nom text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_pays_moi text; v_data jsonb; v_sec jsonb; v_sols jsonb;
  v_avant int; v_apres int; v_lieut text; v_par text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(coalesce(p_nom,'')),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_invalide'); END IF;

  SELECT coalesce(country,'republic') INTO v_pays_moi
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  -- MEME GARDE DE JURIDICTION que militaire_section_de_moi : le banc a montre qu'elle manquait
  -- ici, et un officier d'un empire ne doit pas pouvoir toucher aux effectifs d'un autre.
  IF v_data->>'pays' IS DISTINCT FROM v_pays_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
  v_lieut := v_sec->>'lieutenantNom';

  -- DEUX AUTORITES LEGITIMES, et deux seulement : le soldat lui-meme (demission) ou le Lieutenant
  -- de CETTE section (renvoi). Tout autre acteur est refuse.
  IF v_moi = p_nom THEN v_par := 'demission';
  ELSIF v_lieut IS NOT NULL AND v_lieut = v_moi THEN v_par := 'renvoi';
  ELSE RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_avant := jsonb_array_length(v_sols);
  SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb) INTO v_sols
    FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos)
   WHERE NOT (coalesce((sol->>'pj')::boolean, false) AND sol->>'nom' = p_nom);
  v_apres := jsonb_array_length(v_sols);
  IF v_apres = v_avant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_soldat_de_cette_section');
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;

  -- La periode de service se termine ici : c'est elle, et non le calepin, qui fait foi.
  PERFORM public.militaire_service_fermer(p_nom, 'soldat');

  RETURN jsonb_build_object('ok', true, 'motif', v_par, 'nom', p_nom,
    'effectif', v_apres, 'places_libres', 24 - v_apres);
END; $function$

-- militaire_soldat_supprimer(text,text,text) -> void | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_soldat_supprimer(p_compagnie_id text, p_section_id text, p_matricule text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_data jsonb; v_sec jsonb; v_sols jsonb; v_pnj text;
BEGIN
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN; END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN; END IF;

  -- LE CYCLE DE MORT D'ABORD, LE RETRAIT DU BLOB ENSUITE. Dans cet ordre seulement : apres le
  -- retrait, le declencheur miroir aurait deja supprime la ligne du socle et il n'y aurait plus
  -- ni possessions a poser au sol ni proprietaire a prevenir.
  v_pnj := p_compagnie_id || '-' || p_matricule;
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_pnj) THEN
    PERFORM public.pnj_mourir(v_pnj, 'degats');
  END IF;

  SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb) INTO v_sols
    FROM jsonb_array_elements(
      CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END)
      WITH ORDINALITY AS t(sol, pos)
   WHERE sol->>'matricule' IS DISTINCT FROM p_matricule;
  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
END; $function$

-- militaire_solde_percevoir() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_solde_percevoir()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_pays text; v_grade text; v_du integer; v_jour date; v_id text;
  v_mvt jsonb; v_verse integer; v_credit jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  v_grade := public.militaire_grade_effectif(v_moi);
  IF v_grade IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_militaire');
  END IF;

  -- Baremes GD. Les PNJ n'ont aucune solde : ils ne passent jamais par ici.
  v_du := CASE v_grade WHEN 'soldat' THEN 50 WHEN 'lieutenant' THEN 150
                       WHEN 'capitaine' THEN 250 WHEN 'commandant' THEN 400 END;
  IF v_du IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'grade_sans_solde'); END IF;

  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := v_moi || ':' || v_jour::text;

  -- ANTI-REJEU PAR LA CLE : deux clics simultanes ne peuvent pas creer deux lignes.
  BEGIN
    INSERT INTO public.soldes_militaires (id, personnage, pays, grade, jour, du, verse)
    VALUES (v_id, v_moi, v_pays, v_grade, v_jour, v_du, 0);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_percue_aujourdhui', 'jour', v_jour);
  END;

  -- Debit PLAFONNE : la caserne verse ce qu'elle peut, le reste devient une dette.
  v_mvt := public.caisse_institution_mouvement_plafonne(v_pays || '_caserne-militaire', v_du);
  v_verse := greatest(0, coalesce((v_mvt->>'verse')::integer, 0));

  IF v_verse > 0 THEN
    v_credit := public.assemblee_crediter_joueur(v_moi, v_verse);
  END IF;
  UPDATE public.soldes_militaires
     SET verse = v_verse, regle_le = CASE WHEN v_verse >= v_du THEN now() END
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'grade', v_grade, 'du', v_du, 'verse', v_verse,
    'dette', v_du - v_verse, 'jour', v_jour,
    'liquide', v_credit->'liquide', 'arg', v_credit->'arg');
END; $function$

-- militaire_subtiliser(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_subtiliser(p_pays text, p_joueur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pj public.personnages%ROWTYPE;
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  SELECT * INTO v_pj FROM public.personnages WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  RETURN public.caserne_stock_mouvement(p_pays, 'explosif_militaire', -1, NULL);
END;
$function$

-- militaire_subtiliser_tenter(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_subtiliser_tenter(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_seuil_detection constant integer := 20;
  c_seuil_reussite  constant integer := 66;
  c_isn_defaut      constant integer := 30;
  v_moi text; v_pj public.personnages_donnees%ROWTYPE;
  v_dup numeric; v_isn integer; v_rep integer; v_bonus_rep integer;
  v_bonus numeric; v_jet integer; v_score integer;
  v_stock jsonb; v_objet jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_pj FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF coalesce(v_pj.current_building,'') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- LE PA EST DEBITE AVANT LE JET, comme pour toute tentative : on paie l'essai, pas le resultat.
  IF coalesce(v_pj.pa, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', 2);
  END IF;

  -- DUP effective : meme regle que getStatEffective -- une caracteristique affaiblie est
  -- proportionnelle aux points de vie, jamais en dessous de 1.
  v_dup := coalesce((v_pj.stats->>'DUP')::numeric, 8);
  IF v_pj.stats_affaiblies ? 'DUP' THEN
    v_dup := greatest(1, round(v_dup * greatest(0, least(1, coalesce(v_pj.hp,0)::numeric / 100))));
  END IF;

  -- ISN de la zone. La caserne n'a pas d'indices propres : repli sur le defaut, exactement comme
  -- getIndiceVille cote client.
  SELECT coalesce((data->>'isn')::integer, c_isn_defaut) INTO v_isn
    FROM public.indices_villes WHERE id = p_pays || '_' || coalesce(v_pj.current_city,'');
  v_isn := coalesce(v_isn, c_isn_defaut);

  v_rep := greatest(0, least(100, coalesce(v_pj.reputation_criminelle, 0)));
  v_bonus_rep := CASE WHEN v_rep >= 70 THEN 15 WHEN v_rep >= 40 THEN 10 WHEN v_rep >= 20 THEN 5 ELSE 0 END;

  v_bonus := (v_dup - 10) * 2 - (v_isn - 45)::numeric / 3 + v_bonus_rep;
  v_jet := floor(random() * 100)::integer + 1 - 50;
  v_score := greatest(0, least(100, round(50 + v_bonus + v_jet)::integer));

  UPDATE public.personnages_donnees SET pa = greatest(0, coalesce(pa,0) - 2) WHERE name = v_moi;

  IF v_score < c_seuil_reussite THEN
    RETURN jsonb_build_object('ok', true, 'reussite', false,
      'detecte', v_score < c_seuil_detection, 'score', v_score);
  END IF;

  -- REUSSITE. Le stock est decremente AVANT que l'objet n'existe : jamais d'explosif cree de rien.
  v_stock := public.caserne_stock_mouvement(p_pays, 'explosif_militaire', -1, NULL);
  IF coalesce((v_stock->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'reussite', false, 'detecte', false,
      'score', v_score, 'raison', 'stock_insuffisant');
  END IF;

  -- ...et c'est le SERVEUR qui le pose dans l'inventaire, plus le navigateur.
  v_objet := jsonb_build_object(
    'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
    'type', 'arme', 'sousType', 'militaire', 'origineMilitaire', true,
    'lot', coalesce(v_stock->'lots'->0->>'lot', 'legacy'),
    'produitMilitaire', 'explosif_militaire', 'name', 'Explosif militaire',
    'icon', 'ti-bomb', 'legal', true, 'imageUrl', NULL,
    'desc', 'Explosif militaire. Lot ' || coalesce(v_stock->'lots'->0->>'lot', 'legacy') || '.');

  UPDATE public.personnages_donnees
     SET inventory = (CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END)
                     || jsonb_build_array(v_objet)
   WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'reussite', true, 'detecte', false,
    'score', v_score, 'objet', v_objet, 'lot', v_objet->>'lot');
END;
$function$

-- militaire_taux_combat(numeric,numeric,numeric,integer) -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.militaire_taux_combat(p_comp_off numeric, p_comp_cible numeric, p_stat_cible numeric, p_bonus_arme integer DEFAULT 0)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT greatest(10, least(85, round(
      50 + coalesce(p_comp_off, 0) / 3.0
         - coalesce(p_comp_cible, 0) / 5.0
         - (coalesce(p_stat_cible, 8) - 8)
         + coalesce(p_bonus_arme, 0)
    )::integer));
$function$

-- militaire_terminal_dormir(text,text[],text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_terminal_dormir(p_requete text, p_matricules text[], p_tentes text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa_max constant integer := 12;
  c_gain_terrain constant integer := 8;
  c_bonus_tente constant integer := 2;
  g record; v_deja record; v_jour text; r record; v_res jsonb; v_etat jsonb;
  v_tentes text[] := coalesce(p_tentes, '{}'::text[]);
  v_libres integer; v_caserne text[] := '{}'; v_sous_tente text[] := '{}';
  v_terrain text[] := '{}'; v_mats text[] := '{}'; v_refus jsonb := '[]'::jsonb;
  v_data jsonb; v_sec jsonb;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^mil-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF p_matricules IS NULL OR array_length(p_matricules, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_selection'); END IF;
  IF EXISTS (SELECT 1 FROM unnest(v_tentes) t WHERE t <> ALL(p_matricules)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tente_hors_selection'); END IF;

  SELECT * INTO v_deja FROM public.militaire_terminal_requetes WHERE requete = p_requete;
  IF FOUND THEN RETURN v_deja.resultat || jsonb_build_object('rejeu', true); END IF;

  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  v_etat := public.militaire_terminal_section();
  v_libres := coalesce((v_etat->>'places_tente_libres')::integer, 0);
  IF coalesce(array_length(v_tentes,1), 0) > v_libres THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'capacite_tente_depassee',
      'demande', coalesce(array_length(v_tentes,1),0), 'places_libres', v_libres,
      'tentes', v_etat->'tentes', 'par_tente', v_etat->'par_tente',
      'places_pj', v_etat->'places_pj'); END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(g.o_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = g.o_section;

  FOR r IN
    SELECT sm.pnj_id, sm.matricule, m.pa, coalesce(sm.dernier_sommeil,'') AS marqueur,
           coalesce(pd.current_building, m.building_id) AS batiment
      FROM public.pnj_soldats_metier sm
      JOIN public.pnj_membres m ON m.id = sm.pnj_id
      LEFT JOIN public.personnages_donnees pd ON pd.name = m.leader_pj
     WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
       AND m.statut = 'actif' AND coalesce(sm.en_reserve,false) = false
       AND sm.matricule = ANY(p_matricules)
     ORDER BY sm.matricule
  LOOP
    IF NOT public.militaire_terminal_liaison(g.o_moi, r.pnj_id) THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'hors_liaison');
      CONTINUE;
    END IF;
    IF r.pa <= 0 THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'epuise');
      CONTINUE;
    END IF;
    IF r.marqueur = v_jour THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'deja_repose');
      CONTINUE;
    END IF;

    v_mats := v_mats || r.matricule;
    IF coalesce(r.batiment,'') = 'caserne-militaire' THEN v_caserne := v_caserne || r.pnj_id;
    ELSIF r.matricule = ANY(v_tentes)                THEN v_sous_tente := v_sous_tente || r.pnj_id;
    ELSE                                                  v_terrain := v_terrain || r.pnj_id;
    END IF;
  END LOOP;

  IF array_length(v_caserne,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_fixer(v_caserne, c_pa_max); END IF;
  IF array_length(v_sous_tente,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_crediter(v_sous_tente, c_gain_terrain + c_bonus_tente); END IF;
  IF array_length(v_terrain,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_crediter(v_terrain, c_gain_terrain); END IF;

  IF array_length(v_mats,1) IS NOT NULL THEN
    SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = g.o_compagnie FOR UPDATE;
    UPDATE public.compagnies_militaires
       SET data = jsonb_set(v_data, '{sections}', (
             SELECT coalesce(jsonb_agg(
               CASE WHEN s->>'id' = g.o_section
                    THEN jsonb_set(s, '{soldats}', (
                           SELECT coalesce(jsonb_agg(
                             CASE WHEN (so->>'matricule') = ANY(v_mats)
                                  THEN so || jsonb_build_object('dernier_sommeil', v_jour)
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

  v_res := jsonb_build_object('ok', true, 'action', 'dormir',
    'caserne', coalesce(array_length(v_caserne,1),0),
    'tente', coalesce(array_length(v_sous_tente,1),0),
    'terrain', coalesce(array_length(v_terrain,1),0),
    'reposes', coalesce(array_length(v_mats,1),0),
    'details', v_refus);
  INSERT INTO public.militaire_terminal_requetes (requete, acteur, action, resultat)
  VALUES (p_requete, g.o_moi, 'dormir', v_res);
  RETURN v_res;
END; $function$

-- militaire_terminal_liaison(text,text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_terminal_liaison(p_moi text, p_pnj_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_radio_moi boolean; v_leader text; pe record; v_radio_groupe boolean;
BEGIN
  IF public.pnj_co_present(p_moi, p_pnj_id) THEN RETURN true; END IF;

  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
           jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                     THEN pd.inventory ELSE '[]'::jsonb END) i
           WHERE pd.name = p_moi AND i->>'produitMilitaire' = 'radio') INTO v_radio_moi;
  IF NOT coalesce(v_radio_moi, false) THEN RETURN false; END IF;

  SELECT leader_pj INTO v_leader FROM public.pnj_membres WHERE id = p_pnj_id;
  IF v_leader IS NOT NULL THEN
    SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                       THEN pd.inventory ELSE '[]'::jsonb END) i
             WHERE pd.name = v_leader AND i->>'produitMilitaire' = 'radio') INTO v_radio_groupe;
    RETURN coalesce(v_radio_groupe, false);
  END IF;

  SELECT * INTO pe FROM public.pnj_position_effective(p_pnj_id);
  IF pe.ville IS NULL THEN RETURN false; END IF;
  SELECT EXISTS (
    SELECT 1 FROM public.pnj_membres m2
      JOIN public.pnj_possessions p ON p.pnj_id = m2.id
     WHERE m2.statut = 'actif' AND m2.pays = pe.pays
       AND m2.ville = pe.ville
       AND m2.building_id IS NOT DISTINCT FROM pe.building_id
       AND m2.room_id IS NOT DISTINCT FROM pe.room_id
       AND p.objet->>'produitMilitaire' = 'radio') INTO v_radio_groupe;
  RETURN coalesce(v_radio_groupe, false);
END; $function$

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
END; $function$

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
END; $function$
