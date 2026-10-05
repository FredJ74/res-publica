-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927142144
-- Nom original      : militaire_ration_source_unique_socle
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 14:21:44 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ccf07367aaaa4b79a6dcad8918492f8e
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
-- LOT 4c (fin) — LA RATION PROPRE DU SOLDAT VIENT DU SOCLE (27 septembre 2026)
--
-- Avant, la fonction cherchait la ration a DEUX endroits : le paquetage du blob, puis les
-- possessions du socle. L'axe possessions ayant bascule, il n'y a plus qu'un endroit -- et deux
-- sources tenues pour equivalentes finissent toujours par divergier.
-- Tout le reste est inchange : sa ration d'abord puis celle du chef, validation globale, refus
-- global, plafond de 2 par jour, 12 PNJ par tente, +1 PA plafonne a 12. Les PA et les compteurs
-- anti-rejeu restent ecrits dans le blob : l'axe PA n'est pas concerne par ce lot.
CREATE OR REPLACE FUNCTION public.militaire_ordre_collectif(
  p_compagnie_id text, p_section_id text, p_action text, p_leader text DEFAULT NULL::text,
  p_matricules text[] DEFAULT NULL::text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
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
  v_sources jsonb := '{}'::jsonb;
  v_besoin_chef integer := 0; v_propres integer := 0;
  v_nouv jsonb := '[]'::jsonb; v_mat text; v_pnj text; v_id_poss bigint;
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

  -- ===== PASSE 1 : DECIDER, SANS RIEN ECRIRE =====
  FOR sol IN SELECT value FROM jsonb_array_elements(v_sols) LOOP
    v_mat := sol->>'matricule';
    v_eligible := NOT coalesce((sol->>'pj')::boolean,false)
              AND sol->>'leaderCourant' = v_leader
              AND coalesce((sol->>'pa')::numeric, 0) < c_pa_max_pnj
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

    IF p_action = 'ration' THEN
      -- SA RATION D'ABORD. Une seule source depuis la bascule de l'axe : ses possessions.
      v_pnj := p_compagnie_id || '-' || v_mat;
      IF EXISTS (SELECT 1 FROM public.pnj_possessions p
                  WHERE p.pnj_id = v_pnj
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

  -- ===== PASSE 2 : APPLIQUER =====
  FOR sol IN SELECT value FROM jsonb_array_elements(v_sols) LOOP
    v_mat := sol->>'matricule';
    v_src := v_sources->>v_mat;
    IF v_src IS NULL THEN
      v_nouv := v_nouv || jsonb_build_array(sol);
      CONTINUE;
    END IF;

    sol := sol || jsonb_build_object('pa',
             least(c_pa_max_pnj, coalesce((sol->>'pa')::numeric, 0) + c_gain));
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
END; $$;

REVOKE ALL ON FUNCTION public.militaire_ordre_collectif(text,text,text,text,text[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_ordre_collectif(text,text,text,text,text[])
  TO authenticated, service_role;