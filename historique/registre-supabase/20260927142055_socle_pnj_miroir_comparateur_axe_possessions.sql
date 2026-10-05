-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927142055
-- Nom original      : socle_pnj_miroir_comparateur_axe_possessions
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 14:20:55 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : cf1134e873ce26d4bc1c116ed139b04e
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
-- LOT 4c (suite) — LE MIROIR ET LE COMPARATEUR APPRENNENT L'AXE (27 septembre 2026)
--
-- Ordre d'application volontaire : le miroir devient conditionnel AVANT que l'axe soit bascule.
-- Tant que l'axe dit « blob », le comportement est strictement celui d'aujourd'hui.

CREATE OR REPLACE FUNCTION public.pnj_miroir_compagnie(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c record; v_pays text; v_vus text[] := '{}'; v_sup integer := 0; v_maj integer := 0;
        s jsonb; sol jsonb; v_id text; v_sec text; v_res_per text;
BEGIN
  SELECT * INTO c FROM public.compagnies_militaires WHERE id = p_compagnie;
  IF c.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  v_pays := c.data->>'pays';
  v_res_per := p_compagnie || ':reserve';

  FOR s IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) LOOP
    v_sec := s->>'id';
    FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) LOOP
      CONTINUE WHEN COALESCE((sol->>'pj')::boolean, false) IS TRUE;
      v_id := p_compagnie || '-' || (sol->>'matricule');
      v_vus := v_vus || v_id;
      INSERT INTO public.pnj_membres (id, famille, nom, pays,
          proprietaire_institution, proprietaire_perimetre,
          leader_pj, ville, building_id, room_id, pa, statut)
      VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'militaire', v_sec,
          sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
          COALESCE((sol->>'pa')::integer, 12), 'actif')
      ON CONFLICT (id) DO UPDATE SET
          leader_pj = EXCLUDED.leader_pj, ville = EXCLUDED.ville,
          building_id = EXCLUDED.building_id, room_id = EXCLUDED.room_id,
          pa = EXCLUDED.pa, statut = EXCLUDED.statut,
          proprietaire_institution = EXCLUDED.proprietaire_institution,
          proprietaire_perimetre = EXCLUDED.proprietaire_perimetre,
          maj_le = now();
      INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, compagnie_id, section_id,
          en_reserve, arme, formation, mutin,
          dernier_ration, nb_ration, dernier_bivouac, dernier_sommeil)
      VALUES (v_id, sol->>'matricule', p_compagnie, v_sec, false, sol->>'arme',
              COALESCE(sol->'formation','{}'::jsonb), sol->>'mutin',
              sol->>'dernier_ration', (sol->>'nb_ration')::integer,
              sol->>'dernier_bivouac', sol->>'dernier_sommeil')
      ON CONFLICT (pnj_id) DO UPDATE SET
          compagnie_id = EXCLUDED.compagnie_id,
          section_id = EXCLUDED.section_id, en_reserve = EXCLUDED.en_reserve,
          arme = EXCLUDED.arme, formation = EXCLUDED.formation, mutin = EXCLUDED.mutin,
          dernier_ration = EXCLUDED.dernier_ration, nb_ration = EXCLUDED.nb_ration,
          dernier_bivouac = EXCLUDED.dernier_bivouac, dernier_sommeil = EXCLUDED.dernier_sommeil;
      v_maj := v_maj + 1;
      -- CONDITIONNEL : ne recopie les possessions que si l'axe vit encore dans le blob.
      PERFORM public.pnj_miroir_possessions_si_axe_blob(v_id,
        CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END);
    END LOOP;
  END LOOP;

  FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) LOOP
    v_id := p_compagnie || '-' || (sol->>'matricule');
    v_vus := v_vus || v_id;
    INSERT INTO public.pnj_membres (id, famille, nom, pays,
        proprietaire_institution, proprietaire_perimetre,
        leader_pj, ville, building_id, room_id, pa, statut)
    VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'militaire', v_res_per,
        sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
        COALESCE((sol->>'pa')::integer, 12), 'actif')
    ON CONFLICT (id) DO UPDATE SET
        leader_pj = EXCLUDED.leader_pj, ville = EXCLUDED.ville,
        building_id = EXCLUDED.building_id, room_id = EXCLUDED.room_id,
        pa = EXCLUDED.pa, statut = EXCLUDED.statut,
        proprietaire_institution = EXCLUDED.proprietaire_institution,
        proprietaire_perimetre = EXCLUDED.proprietaire_perimetre,
        maj_le = now();
    INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, compagnie_id, section_id,
        en_reserve, arme, formation, mutin,
        dernier_ration, nb_ration, dernier_bivouac, dernier_sommeil)
    VALUES (v_id, sol->>'matricule', p_compagnie, NULL, true, sol->>'arme',
            COALESCE(sol->'formation','{}'::jsonb), sol->>'mutin',
            sol->>'dernier_ration', (sol->>'nb_ration')::integer,
            sol->>'dernier_bivouac', sol->>'dernier_sommeil')
    ON CONFLICT (pnj_id) DO UPDATE SET
        compagnie_id = EXCLUDED.compagnie_id,
        section_id = NULL, en_reserve = true,
        arme = EXCLUDED.arme, formation = EXCLUDED.formation, mutin = EXCLUDED.mutin,
        dernier_ration = EXCLUDED.dernier_ration, nb_ration = EXCLUDED.nb_ration,
        dernier_bivouac = EXCLUDED.dernier_bivouac, dernier_sommeil = EXCLUDED.dernier_sommeil;
    v_maj := v_maj + 1;
    PERFORM public.pnj_miroir_possessions_si_axe_blob(v_id,
      CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END);
  END LOOP;

  DELETE FROM public.pnj_membres
   WHERE id LIKE p_compagnie || '-%' AND NOT (id = ANY(v_vus));
  GET DIAGNOSTICS v_sup = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'synchronises', v_maj, 'supprimes', v_sup);
END; $$;

-- ---------------------------------------------------------------------------------------
-- LE COMPARATEUR CESSE DE COMPARER UN AXE QUI A BASCULE
-- ---------------------------------------------------------------------------------------
-- Une fois l'axe au socle, le tableau `accessoires` du blob est un vestige : le comparer
-- produirait des divergences FAUSSES des le premier equipement. On l'annonce explicitement
-- plutot que de laisser croire que la comparaison couvre tout.
CREATE OR REPLACE FUNCTION public.pnj_comparer_soldats(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_div jsonb; v_nb_blob integer; v_nb_socle integer;
        v_pos_blob integer; v_pos_socle integer; v_pos_div jsonb;
        v_liquide numeric; v_liquide_non_nuls integer; v_axe_poss text;
BEGIN
  SELECT COALESCE(autorite, 'blob') INTO v_axe_poss
    FROM public.pnj_axes_autorite WHERE famille = 'soldat' AND axe = 'possessions';

  WITH blob AS (
    SELECT sol->>'matricule' AS matricule, sol->>'leaderCourant' AS leader,
           sol->>'ville' AS ville, sol->>'buildingId' AS bat, sol->>'roomId' AS room,
           (sol->>'pa')::integer AS pa, sol->>'arme' AS arme,
           COALESCE(sol->'formation','{}'::jsonb) AS formation,
           false AS en_reserve, s->>'id' AS section_id, sol->>'mutin' AS mutin,
           s->>'id' AS perimetre,
           sol->>'dernier_ration' AS dernier_ration, (sol->>'nb_ration')::integer AS nb_ration,
           sol->>'dernier_bivouac' AS dernier_bivouac, sol->>'dernier_sommeil' AS dernier_sommeil
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) sol
     WHERE c.id = p_compagnie AND COALESCE((sol->>'pj')::boolean, false) = false
    UNION ALL
    SELECT r->>'matricule', r->>'leaderCourant', r->>'ville', r->>'buildingId', r->>'roomId',
           (r->>'pa')::integer, r->>'arme', COALESCE(r->'formation','{}'::jsonb), true, NULL,
           r->>'mutin', p_compagnie || ':reserve',
           r->>'dernier_ration', (r->>'nb_ration')::integer,
           r->>'dernier_bivouac', r->>'dernier_sommeil'
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) r
     WHERE c.id = p_compagnie
  ), socle AS (
    SELECT sm.matricule, m.leader_pj AS leader, m.ville, m.building_id AS bat,
           m.room_id AS room, m.pa, sm.arme, sm.formation, sm.en_reserve, sm.section_id,
           sm.mutin, m.statut, m.proprietaire_pj,
           m.proprietaire_institution AS institution, m.proprietaire_perimetre AS perimetre,
           m.leader_pnj_id, m.rue_noeud_id, sm.compagnie_id,
           sm.dernier_ration, sm.nb_ration, sm.dernier_bivouac, sm.dernier_sommeil
      FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE m.id LIKE p_compagnie || '-%'
  ), compare AS (
    SELECT COALESCE(b.matricule, s.matricule) AS matricule,
      CASE
        WHEN s.matricule IS NULL THEN 'absent_du_socle'
        WHEN b.matricule IS NULL THEN 'surnumeraire_dans_le_socle'
        WHEN b.leader      IS DISTINCT FROM s.leader      THEN 'leader'
        WHEN b.ville       IS DISTINCT FROM s.ville       THEN 'ville'
        WHEN b.bat         IS DISTINCT FROM s.bat         THEN 'batiment'
        WHEN b.room        IS DISTINCT FROM s.room        THEN 'piece'
        WHEN b.pa          IS DISTINCT FROM s.pa          THEN 'pa'
        WHEN b.arme        IS DISTINCT FROM s.arme        THEN 'arme'
        WHEN b.formation   IS DISTINCT FROM s.formation   THEN 'entrainement'
        WHEN b.en_reserve  IS DISTINCT FROM s.en_reserve  THEN 'reserve'
        WHEN b.section_id  IS DISTINCT FROM s.section_id  THEN 'section'
        WHEN s.compagnie_id IS DISTINCT FROM p_compagnie  THEN 'compagnie'
        WHEN b.mutin       IS DISTINCT FROM s.mutin       THEN 'mutin'
        WHEN b.dernier_ration  IS DISTINCT FROM s.dernier_ration  THEN 'dernier_ration'
        WHEN b.nb_ration       IS DISTINCT FROM s.nb_ration       THEN 'nb_ration'
        WHEN b.dernier_bivouac IS DISTINCT FROM s.dernier_bivouac THEN 'dernier_bivouac'
        WHEN b.dernier_sommeil IS DISTINCT FROM s.dernier_sommeil THEN 'dernier_sommeil'
        WHEN s.proprietaire_pj IS NOT NULL                THEN 'propriete_personnelle_inattendue'
        WHEN s.institution IS DISTINCT FROM 'militaire'   THEN 'institution'
        WHEN b.perimetre   IS DISTINCT FROM s.perimetre   THEN 'perimetre'
        WHEN s.leader_pnj_id IS NOT NULL                  THEN 'leader_pnj_interdit_phase_miroir'
        WHEN s.rue_noeud_id  IS NOT NULL                  THEN 'rue_noeud_interdit_phase_miroir'
        WHEN s.statut IS DISTINCT FROM 'actif'            THEN 'statut'
        ELSE NULL END AS divergence
      FROM blob b FULL OUTER JOIN socle s ON s.matricule = b.matricule
  )
  SELECT (SELECT count(*) FROM blob), (SELECT count(*) FROM socle),
         COALESCE(jsonb_agg(jsonb_build_object('matricule', matricule, 'divergence', divergence)
                            ORDER BY matricule) FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_nb_blob, v_nb_socle, v_div FROM compare;

  IF v_axe_poss = 'blob' THEN
    WITH pb AS (
      SELECT sol->>'matricule' AS matricule, a AS objet,
             row_number() OVER (PARTITION BY sol->>'matricule', a::text) AS occ
        FROM public.compagnies_militaires c,
             jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) s,
             jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) sol,
             jsonb_array_elements(CASE WHEN jsonb_typeof(sol->'accessoires')='array'
                                       THEN sol->'accessoires' ELSE '[]'::jsonb END) a
       WHERE c.id = p_compagnie AND COALESCE((sol->>'pj')::boolean, false) = false
      UNION ALL
      SELECT r->>'matricule', a,
             row_number() OVER (PARTITION BY r->>'matricule', a::text)
        FROM public.compagnies_militaires c,
             jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) r,
             jsonb_array_elements(CASE WHEN jsonb_typeof(r->'accessoires')='array'
                                       THEN r->'accessoires' ELSE '[]'::jsonb END) a
       WHERE c.id = p_compagnie
    ), ps AS (
      SELECT sm.matricule, p.objet,
             row_number() OVER (PARTITION BY sm.matricule, p.objet::text) AS occ
        FROM public.pnj_possessions p
        JOIN public.pnj_soldats_metier sm ON sm.pnj_id = p.pnj_id
        JOIN public.pnj_membres m ON m.id = p.pnj_id
       WHERE m.id LIKE p_compagnie || '-%' AND p.origine = 'blob_accessoires'
    ), pcmp AS (
      SELECT COALESCE(b.matricule, s.matricule) AS matricule,
             COALESCE(b.objet, s.objet) AS objet,
             CASE WHEN s.matricule IS NULL THEN 'possession_absente_du_socle'
                  WHEN b.matricule IS NULL THEN 'possession_surnumeraire_dans_le_socle'
                  ELSE NULL END AS divergence
        FROM pb b FULL OUTER JOIN ps s
          ON s.matricule = b.matricule AND s.objet::text = b.objet::text AND s.occ = b.occ
    )
    SELECT (SELECT count(*) FROM pb), (SELECT count(*) FROM ps),
           COALESCE(jsonb_agg(jsonb_build_object('matricule', matricule,
                      'objet', COALESCE(objet->>'name', objet->>'nom', '?'),
                      'divergence', divergence) ORDER BY matricule)
                    FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
      INTO v_pos_blob, v_pos_socle, v_pos_div FROM pcmp;
  ELSE
    -- Axe bascule : il n'y a plus deux cotes a comparer. On compte ce que le socle porte.
    SELECT count(*), count(*), '[]'::jsonb INTO v_pos_blob, v_pos_socle, v_pos_div
      FROM public.pnj_possessions p JOIN public.pnj_membres m ON m.id = p.pnj_id
     WHERE m.id LIKE p_compagnie || '-%';
  END IF;

  SELECT COALESCE(sum(m.liquide), 0), count(*) FILTER (WHERE m.liquide <> 0)
    INTO v_liquide, v_liquide_non_nuls
    FROM public.pnj_membres m WHERE m.id LIKE p_compagnie || '-%';

  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_div) = 0 AND v_nb_blob = v_nb_socle
          AND jsonb_array_length(v_pos_div) = 0 AND v_pos_blob = v_pos_socle,
    'nb_blob', v_nb_blob, 'nb_socle', v_nb_socle,
    'correspondances', v_nb_blob - jsonb_array_length(v_div),
    'nb_divergences', jsonb_array_length(v_div),
    'manquants', (SELECT count(*) FROM jsonb_array_elements(v_div) d
                   WHERE d->>'divergence' = 'absent_du_socle'),
    'surnumeraires', (SELECT count(*) FROM jsonb_array_elements(v_div) d
                   WHERE d->>'divergence' = 'surnumeraire_dans_le_socle'),
    'details', v_div,
    'axe_possessions', v_axe_poss,
    'possessions_blob', v_pos_blob, 'possessions_socle', v_pos_socle,
    'possessions_divergences', jsonb_array_length(v_pos_div),
    'possessions_details', v_pos_div,
    'observation_liquide_total', v_liquide,
    'observation_liquide_non_nuls', v_liquide_non_nuls);
END; $$;

REVOKE ALL ON FUNCTION public.pnj_miroir_compagnie(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_comparer_soldats(text) FROM PUBLIC, anon, authenticated;