-- CRIMINALITÉ — LOT 8 : DÉLITS D'INFORMATION (GAME-DESIGN-CRIMINALITE.md § 13 ; Fred, 19/11/2026, nuit).
-- • Rumeur (rumeur_lancer, même signature, 1 PA gratuit) branchée sur la résolution commune crim_resoudre_interne :
--   réussite 60 + 1 par tranche de 3 de DIS au-dessus de 50 + 2 par point de CHA au-dessus de 8, bornes 10-90, dissuasion #135
--   comptée UNE fois (dans la résolution commune ; l'ancien appel à crime_detecter_interne, qui la recomptait, est retiré).
--   Effets sur la cible inchangés. Détection APRÈS une réussite seulement : 15 − 1 par tranche de 10 de DIS, minimum 5 %
--   (détecté = identifié, peine d'office par crim_identifier_interne). Échec critique = 10 % des échecs : auteur identifié
--   (crim_identifier_interne, barème crim_peine_jours_interne), la cible apprend son nom, la rumeur se retourne contre lui
--   (annonce publique) et il perd de la POP. Échec ordinaire : retour de bâton existant (0 à 2 POP et DIS), sans suite pénale.
--   La rumeur ne se lance pas « de la main à la main » : ni cachette ni masque n'y changent rien (mode visage découvert forcé,
--   sans identification automatique ; anonyme par défaut). Plainte contre X possible (affaire au nom du PJ visé).
-- • Tracts calomnieux (calomnie_distribuer_interne) : formule inchangée (45 + CHA + INF/4 − 2 × (VOL du PNJ − 10), 0-85),
--   jet par la résolution commune (dissuasion #135 une fois ; échec critique 10 % des échecs ; ni détection ni combat) ;
--   flagrant délit ou mandat inchangés, mais la durée vient du barème (crim_peine_jours_interne('imprimer_tracts_calomnieux')),
--   plus de « 1 jour » en dur. Une distribution réussie laisse une trace 'tract_calomnieux' (bouche-à-oreille).
-- • Bouche-à-oreille (rumeur_ecoute_jauges_interne, « Écouter les rumeurs ») : 10 % de chances d'apprendre l'origine d'une rumeur
--   récente ou qui distribue des tracts contre qui (traces 'fausse_rumeur' / 'tract_calomnieux' de la ville, non expirées) ;
--   ces deux traces ne sortent plus par le tirage ordinaire.
BEGIN;

-- ── Paramètres (valeurs de Républia ; les autres empires reprennent Républia) ──────────────────────────────────────
INSERT INTO public.crim_parametres (cle, valeur) VALUES
  ('rumeur_taux_base', 60), ('rumeur_taux_min', 10), ('rumeur_taux_max', 90),
  ('rumeur_echec_critique_part', 10), ('rumeur_detection_base', 15), ('rumeur_detection_min', 5),
  ('rumeur_critique_pop', 5), ('tracts_echec_critique_part', 10), ('bouche_oreille_part', 10)
ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;

-- ── Taux de la rumeur (formule du § 13, lisible par les bancs) ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_rumeur_taux_interne(p_dis numeric, p_cha numeric)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT (public.crim_param_interne('rumeur_taux_base', 60)
          + floor(greatest(0, coalesce(p_dis, 50) - 50) / 3)
          + 2 * greatest(0, floor(coalesce(p_cha, 8)) - 8))::integer;
$$;

-- ── Lancer une rumeur ──────────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.rumeur_lancer(p_type text, p_cible text, p_texte text, p_cible_trace text, p_pa integer, p_cost integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_moi text; v_paie jsonb; v_reussi boolean; v_perte integer := 0; v_membres text[] := ARRAY[]::text[];
  v_ville text; v_retour integer; v_dis numeric; r jsonb; v_crit boolean := false; v_trace text; v_chef text;
  v_date text := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'); v_label text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_type NOT IN ('pj', 'organisation', 'local', 'gouvernement', 'pays') OR coalesce(btrim(p_cible), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF coalesce(btrim(p_texte), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'texte_requis'); END IF;
  IF p_type = 'pj' AND (p_cible = v_moi OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  v_paie := public.payer_ordre(v_moi, 'lancer_rumeur_cible', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_trace := left(coalesce(nullif(btrim(p_cible_trace), ''), p_cible), 200);
  v_dis := public.crim_stat_interne(v_moi, 'dis', 50);
  -- Résolution commune : visage découvert forcé (la rumeur ne doit rien à la cachette ni au masque) sans identification
  -- automatique ; cible = le PJ visé (plainte contre X, message d'échec critique), NULL pour les autres cibles.
  r := public.crim_resoudre_interne('fausse_rumeur', v_moi, CASE WHEN p_type = 'pj' THEN p_cible END, jsonb_build_object(
    'taux', public.crim_rumeur_taux_interne(v_dis, public.crim_stat_interne(v_moi, 'CHA', 8)),
    'min', public.crim_param_interne('rumeur_taux_min', 10), 'max', public.crim_param_interne('rumeur_taux_max', 90),
    'mode', 'decouvert', 'decouvert_identifie', false, 'combat', false, 'brouillard', false, 'remarque_echec', 0,
    'critique_echec_part', public.crim_param_interne('rumeur_echec_critique_part', 10), 'critique_identifie', true, 'critique_moral', false,
    'detection', true, 'detection_base', public.crim_param_interne('rumeur_detection_base', 15) - floor(v_dis / 10),
    'detection_min', public.crim_param_interne('rumeur_detection_min', 5),
    'acte_peine_reussite', 'fausse_rumeur', 'acte_peine_echec', 'fausse_rumeur', 'type_recherche', 'delit_mineur',
    'titre_echec', 'Calomnies', 'msg_reussite', '', 'msg_echec', '{Auteur} a tenté de répandre des calomnies sur votre compte.',
    'motif_plainte', 'Rumeur calomnieuse',
    'cible_info', CASE WHEN p_type = 'pj' THEN '{}'::jsonb ELSE jsonb_build_object('pj', false, 'nom', v_trace) END,
    'jets', CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END));
  v_reussi := (r ->> 'reussi')::boolean;
  v_crit := coalesce((r ->> 'echec_critique')::boolean, false);

  IF v_reussi THEN
    -- Effets sur la cible : inchangés.
    IF p_type = 'pj' THEN
      v_perte := floor(random() * 16)::integer + 5;
      PERFORM public.rumeur_pop_retirer_interne(p_cible, v_perte);
    ELSIF p_type = 'organisation' THEN
      v_perte := floor(random() * 10)::integer + 1;
      UPDATE public.organisations o
         SET data = jsonb_set(o.data::jsonb, '{influence}', to_jsonb(greatest(0, least(100,
               coalesce(CASE WHEN jsonb_typeof(o.data::jsonb -> 'influence') = 'number'
                             THEN (o.data::jsonb ->> 'influence')::numeric END, 50) - v_perte))))::text
       WHERE o.id = p_cible AND o.data IS JSON OBJECT;
    ELSIF p_type = 'gouvernement' THEN
      v_perte := floor(random() * 5)::integer + 1;
      SELECT coalesce(array_agg(name), ARRAY[]::text[]) INTO v_membres FROM public.personnages_donnees
       WHERE country = p_cible AND poste ->> 'id' IN ('pm', 'min_int', 'min_fin', 'min_just', 'min_def', 'min_info', 'min_ae');
      PERFORM public.rumeur_pop_retirer_interne(n, v_perte) FROM unnest(v_membres) n;
    ELSIF p_type = 'pays' THEN
      v_perte := floor(random() * 5)::integer + 1;
      IF p_cible = 'republic' THEN
        FOREACH v_ville IN ARRAY ARRAY['capitale', 'ville_a', 'ville_b'] LOOP
          UPDATE public.indices_villes
             SET data = jsonb_set(data, '{social}', to_jsonb(greatest(0, least(100,
                          coalesce(CASE WHEN jsonb_typeof(data -> 'social') = 'number' THEN (data ->> 'social')::numeric END, 50) - v_perte))))
           WHERE id = 'republic_' || v_ville;
        END LOOP;
      END IF;
    END IF;
    PERFORM public.annonce_publique_interne('global', '🗯 ' || left(p_texte, 600));
    IF p_type = 'organisation' THEN
      BEGIN
        PERFORM public.mail_systeme_poser_interne('Information officielle', o.chef,
          'Une rumeur vise votre organisation',
          'Une rumeur circule au sujet de votre organisation. Consultez les annonces publiques pour en prendre connaissance.')
          FROM (SELECT nullif(btrim(data::jsonb ->> 'chef'), '') AS chef FROM public.organisations
                 WHERE id = p_cible AND data IS JSON OBJECT) o
         WHERE o.chef IS NOT NULL;
      EXCEPTION WHEN others THEN
        RAISE WARNING 'alerte_rumeur_organisation_indisponible: %', SQLSTATE;
      END;
    END IF;
    PERFORM public.crime_trace_rumeur_interne(v_moi, 'fausse_rumeur', v_trace);
  ELSIF v_crit THEN
    -- Échec critique : identifié (fait par la résolution commune), la rumeur se retourne contre lui, perte de POP.
    v_perte := public.crim_param_interne('rumeur_critique_pop', 5)::integer;
    PERFORM public.rumeur_pop_retirer_interne(v_moi, v_perte);
    v_label := CASE WHEN p_type = 'organisation' THEN 'l''organisation ' || coalesce((SELECT data::jsonb ->> 'nom' FROM public.organisations
                      WHERE id = p_cible AND data IS JSON OBJECT), p_cible) ELSE v_trace END;
    PERFORM public.annonce_publique_interne('global', '🗯 ' || v_moi || ' a tenté de répandre des calomnies sur ' || v_label || '.');
    -- La cible apprend son nom : le PJ visé par le message commun ; le chef d'une organisation, les membres d'un gouvernement ici.
    IF p_type = 'organisation' THEN
      SELECT nullif(btrim(data::jsonb ->> 'chef'), '') INTO v_chef FROM public.organisations WHERE id = p_cible AND data IS JSON OBJECT;
      IF v_chef IS NOT NULL AND v_chef <> v_moi THEN
        PERFORM public.mail_systeme_poser_interne('Événement', v_chef, 'Calomnies',
          v_moi || ' a tenté de répandre des calomnies sur votre organisation.', v_date);
      END IF;
    ELSIF p_type = 'gouvernement' THEN
      PERFORM public.mail_systeme_poser_interne('Événement', name, 'Calomnies',
                v_moi || ' a tenté de répandre des calomnies sur votre gouvernement.', v_date)
         FROM public.personnages_donnees
        WHERE country = p_cible AND name <> v_moi AND poste ->> 'id' IN ('pm', 'min_int', 'min_fin', 'min_just', 'min_def', 'min_info', 'min_ae');
    END IF;
  ELSE
    -- Échec ordinaire : retour de bâton existant, sans suite pénale.
    v_retour := floor(random() * 11)::integer;
    v_perte := CASE WHEN v_retour < 5 THEN 0 WHEN v_retour < 10 THEN 1 ELSE 2 END;
    IF v_perte > 0 THEN
      PERFORM public.rumeur_pop_retirer_interne(v_moi, v_perte);
      PERFORM public.crime_dis_ajuster_interne(v_moi, -v_perte);
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'echec_critique', v_crit, 'perte', v_perte,
    'membres', coalesce(array_length(v_membres, 1), 0), 'taux', (r ->> 'taux')::integer, 'affaire', (r ->> 'affaire')::bigint,
    'detecte', coalesce((r ->> 'detecte')::boolean, false), 'identifie', coalesce((r ->> 'identifie')::boolean, false),
    'repere', coalesce((r ->> 'identifie')::boolean, false), 'peine_jours', (r ->> 'peine_jours')::integer)
    || (SELECT jsonb_build_object('pa', pa, 'pop', (resources ->> 'pop')::numeric, 'dis', resources -> 'dis', 'recherche', recherche)
          FROM public.personnages_donnees WHERE name = v_moi);
END $function$;

-- ── Tracts calomnieux : jet par la résolution commune ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.calomnie_distribuer_interne(p_requete text, p_joueur text, p_cible text, p_pnj_nom text, p_vol_pnj integer, p_instant timestamp with time zone)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE
  v_rej    jsonb;
  v_p      record;
  v_v      record;
  v_inv    jsonb;
  v_nom    text;
  v_cle    text;
  v_jour   date;
  v_pays   text;
  v_taux   integer;
  v_jet    integer;
  v_effet  jsonb;
  v_mandat jsonb;
  v_res    text;
  r        jsonb; /* crim_tracts_resolution_v1 */
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'tract_calomnieux');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_cible), '') = '' OR p_cible = p_joueur THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_invalide'));
  END IF;

  SELECT country, current_city, stats, resources, inventory, pa INTO v_p
    FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  SELECT country, domicile INTO v_v FROM public.personnages WHERE name = p_cible;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_introuvable'));
  END IF;
  v_pays := COALESCE(NULLIF(btrim(COALESCE(v_v.domicile ->> 'country', '')), ''), v_v.country);
  IF COALESCE(btrim(v_pays), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'juridiction_indeterminee'));
  END IF;

  v_inv := CASE WHEN jsonb_typeof(v_p.inventory) = 'array' THEN v_p.inventory ELSE '[]'::jsonb END;
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_inv) i
     WHERE i ->> 'type' = 'tract_calomnieux' AND i ->> 'cible' = p_cible
       AND jsonb_typeof(i -> 'quantite') = 'number' AND (i ->> 'quantite')::numeric >= 1
  ) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'tract_absent'));
  END IF;

  IF COALESCE(v_p.pa, 0) < 1 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;

  v_nom := public.tracts_electoraux_nom_pnj(p_pnj_nom);
  IF v_nom = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pnj_invalide'));
  END IF;
  v_cle := COALESCE(v_p.country, '') || ':' || COALESCE(v_p.current_city, '') || ':' || v_nom;
  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;

  PERFORM pg_advisory_xact_lock(hashtext('calomnie|' || v_cle || '|' || p_cible || '|' || v_jour::text));
  IF EXISTS (SELECT 1 FROM public.calomnies_actes
              WHERE pnj_cle = v_cle AND cible = p_cible AND jour_paris = v_jour AND resultat = 'reussite') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_convaincu'));
  END IF;

  v_taux := public.tracts_electoraux_taux(
    public.assemblee_stat_base(v_p.stats, 'CHA'),
    CASE WHEN jsonb_typeof(v_p.resources -> 'inf') = 'number' THEN (v_p.resources ->> 'inf')::numeric ELSE 0 END,
    LEAST(30, GREATEST(0, COALESCE(p_vol_pnj, 10))));

  -- Résolution commune (Criminalité lot 8) : dissuasion #135 une fois, échec critique 10 % des échecs, ni détection ni combat ;
  -- le flagrant délit ou le mandat restent décidés ici (identification propre aux tracts, barème crim_peine_jours_interne).
  r := public.crim_resoudre_interne('tracts_calomnieux', p_joueur, NULL, jsonb_build_object(
    'taux', v_taux, 'min', 0, 'max', 85, 'mode', 'decouvert', 'decouvert_identifie', false, 'combat', false, 'detection', false,
    'brouillard', false, 'remarque_echec', 0, 'critique_identifie', false, 'critique_moral', false,
    'critique_echec_part', public.crim_param_interne('tracts_echec_critique_part', 10),
    'acte_peine_reussite', 'imprimer_tracts_calomnieux', 'acte_peine_echec', 'imprimer_tracts_calomnieux',
    'cible_info', jsonb_build_object('pj', false, 'nom', p_cible), 'pnj', p_pnj_nom,
    'jets', CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END));
  v_taux := (r ->> 'taux')::integer;
  v_jet := least(100, floor((r ->> 'jet')::numeric)::integer + 1);
  v_res := CASE WHEN (r ->> 'reussi')::boolean THEN 'reussite'
                WHEN coalesce((r ->> 'echec_critique')::boolean, false) THEN 'echec_critique' ELSE 'echec' END;

  INSERT INTO public.calomnies_actes (auteur, cible, pnj_cle, pnj_nom, jour_paris, resultat,
                                      pays_faits, ville_faits, pays_competent, jet, taux)
  VALUES (p_joueur, p_cible, v_cle, p_pnj_nom, v_jour, v_res,
          v_p.country, v_p.current_city, v_pays, v_jet, v_taux);

  IF v_res = 'reussite' THEN
    v_effet := public.calomnie_appliquer_effet(p_cible, -5, -2);
    PERFORM public.crime_trace_rumeur_interne(p_joueur, 'tract_calomnieux', p_cible);   -- bouche-à-oreille
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', true, 'critique', false, 'consomme', 1, 'pa', 1,
      'jet', v_jet, 'taux', v_taux, 'pop', v_effet -> 'pop', 'inf', v_effet -> 'inf',
      'juridiction', v_pays, 'affaire', (r ->> 'affaire')::bigint, 'dissuasion', (r ->> 'dissuasion')::integer));
  END IF;

  IF v_res = 'echec' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'critique', false, 'consomme', 1, 'pa', 1,
      'jet', v_jet, 'taux', v_taux, 'juridiction', v_pays, 'affaire', (r ->> 'affaire')::bigint, 'dissuasion', (r ->> 'dissuasion')::integer));
  END IF;

  UPDATE public.crim_affaires SET identifie = true, maj_le = now() WHERE id = (r ->> 'affaire')::bigint;
  IF v_pays IS NOT DISTINCT FROM v_p.country THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'critique', true, 'consomme', 1, 'pa', 1,
      'jet', v_jet, 'taux', v_taux, 'juridiction', v_pays, 'poursuite', 'flagrant_delit', 'affaire', (r ->> 'affaire')::bigint));
  END IF;
  v_mandat := public.calomnie_inscrire_mandat(p_joueur, p_cible, v_pays, v_p.current_city, p_instant);
  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'reussi', false, 'critique', true, 'consomme', 1, 'pa', 1,
    'jet', v_jet, 'taux', v_taux, 'juridiction', v_pays, 'poursuite', 'mandat', 'affaire', (r ->> 'affaire')::bigint,
    'mandat', COALESCE(v_mandat -> 'mandat', 'null'::jsonb)));
END;
$function$;

-- ── Raccords : durées des tracts par le barème (plus de « 1 jour » en dur) ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- Résolution commune : « critique_moral = false » (lot 4) coupait aussi l'identification de l'échec critique, car le test du
-- moral enveloppait tout le bloc. Le moral n'enveloppe plus que la perte de moral (le cambriolage, seul autre acte à passer
-- critique_moral false, passe aussi critique_identifie false : inchangé).
SELECT pg_temp.rp_raccorder('public.crim_resoudre_interne(text,text,text,jsonb)'::regprocedure,
  $a$IF v_crit_e AND coalesce((p ->> 'critique_moral')::boolean, true) /* crim_critique_moral_v1 */ THEN
    UPDATE public.personnages_donnees SET moral = greatest(0, coalesce(moral, 50) - public.crim_param_interne('echec_critique_moral', 15)::integer)
     WHERE name = p_auteur;$a$,
  $b$IF v_crit_e THEN IF coalesce((p ->> 'critique_moral')::boolean, true) /* crim_critique_moral_v1 */ /* crim_critique_moral_v2 */ THEN
    UPDATE public.personnages_donnees SET moral = greatest(0, coalesce(moral, 50) - public.crim_param_interne('echec_critique_moral', 15)::integer)
     WHERE name = p_auteur;
    END IF;$b$,
  'crim_critique_moral_v2');

SELECT pg_temp.rp_raccorder('public.calomnie_distribuer_consommer(text,text,text,integer)'::regprocedure,
  $a$public.arrestation_flagrant_interne(v_moi, 'tracts_calomnieux', false, 'flagrant_delit', 'Distribution de tracts calomnieux', 1)$a$,
  $b$public.arrestation_flagrant_interne(v_moi, 'imprimer_tracts_calomnieux', false, 'flagrant_delit', 'Distribution de tracts calomnieux',
      public.crim_peine_jours_interne('imprimer_tracts_calomnieux', (SELECT country FROM public.personnages_donnees WHERE name = v_moi))) /* crim_tracts_bareme_v1 */$b$,
  'crim_tracts_bareme_v1');

SELECT pg_temp.rp_raccorder('public.calomnie_inscrire_mandat(text,text,text,text,timestamp with time zone)'::regprocedure,
  $a$'jours', 1,$a$,
  $b$'jours', public.crim_peine_jours_interne('imprimer_tracts_calomnieux', p_pays) /* crim_tracts_mandat_bareme_v1 */,$b$,
  'crim_tracts_mandat_bareme_v1');

-- ── Bouche-à-oreille (« Écouter les rumeurs ») ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.rumeur_ecoute_jauges_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE a public.personnages_donnees;taux integer;cout_pa integer;source text;trace record;fait jsonb;gain integer:=0;
 j jsonb:=CASE WHEN session_user='postgres' THEN nullif(current_setting('rp.crim_jets',true),'')::jsonb END; /* crim_bouche_oreille_v1 */
BEGIN
 IF p_acteur IS DISTINCT FROM public.mon_personnage()THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 SELECT * INTO a FROM public.personnages_donnees WHERE name=p_acteur;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable');END IF;
 IF NOT EXISTS(SELECT 1 FROM public.villes WHERE pays=a.country AND ville=a.current_city)THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 -- Déclarations effectives de data.js : hôtels des capitales, Assemblées,
 -- bar des Pêcheurs et Capitaine Sauvage. Aucun nouveau lieu n'est activé.
 IF a.current_city='capitale'AND a.current_building='hotel-republica'AND a.current_room='restaurant'THEN taux:=95;cout_pa:=0;
 ELSIF a.current_city='capitale'AND a.current_building='hotel-republica'AND a.current_room='bar'THEN taux:=90;cout_pa:=0;source:='Marco';
 ELSIF a.current_city='capitale'AND a.current_building='assemblee'AND a.current_room='couloirs'THEN taux:=70;cout_pa:=1;
 ELSIF a.country='republic'AND a.current_city='ville_a'AND a.current_building='bar-des-pecheurs'AND a.current_room='salle_bar'THEN taux:=85;cout_pa:=0;source:='Marin Dulac';
 ELSIF a.country='republic'AND a.current_city='ville_a'AND a.current_building='capitaine-sauvage'AND a.current_room='salle_principale'THEN taux:=95;cout_pa:=0;
 ELSIF a.country='soviet'AND a.current_city='ville_a'AND a.current_building='hotel-mineur'AND a.current_room='hall_mineur'THEN taux:=90;cout_pa:=0;source:='Aldar Zhamsuev';
 ELSE RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 -- Bouche-à-oreille (Criminalité § 13) : 10 % de chances d'apprendre l'origine d'une rumeur récente ou qui distribue des tracts
 -- contre qui (trace de la ville, non expirée). Ces deux traces ne sortent que par ce jet.
 IF coalesce((j->>'bouche')::numeric,random()*100)<public.crim_param_interne('bouche_oreille_part',10)THEN
  SELECT t.id,t.type_action,t.auteur,t.cible INTO trace FROM public.actions_tracables t
   WHERE t.country=a.country AND t.city=a.current_city AND t.auteur<>a.name AND t.type_action IN('fausse_rumeur','tract_calomnieux')
     AND t.jour_expiration>=public.jour_de_jeu_pays(a.country)ORDER BY t.jour DESC,random()LIMIT 1;
  IF FOUND THEN fait:=jsonb_build_object('type_action',trace.type_action,'auteur',trace.auteur,'cible',trace.cible,'bouche_oreille',true);gain:=1;END IF;
 END IF;
 IF fait IS NULL AND coalesce((j->>'ecoute')::numeric,random()*100)<taux THEN
  -- Même population de tirage, y compris les types sans formulation : ne pas
  -- augmenter subrepticement la chance de gain en filtrant ces types avant le jet.
  SELECT t.id,t.type_action,t.auteur,t.cible INTO trace FROM public.actions_tracables t
   WHERE t.country=a.country AND t.city=a.current_city AND t.auteur<>a.name AND t.type_action NOT IN('fausse_rumeur','tract_calomnieux')
     AND t.jour_expiration>=public.jour_de_jeu_pays(a.country)ORDER BY random()LIMIT 1;
  IF FOUND AND trace.type_action=ANY(ARRAY['consommation_estadine','consommation_drogue','achat_drogue','don','don_objet','vol','assassinat','corruption','escort','achat_arme_illegal','acheter_bombe_illegale','incendier','utiliser_explosifs','empoisonnement','hooliganisme','torture_qhs','diner_affaires_accepte','diner_affaires_refuse','boire_verre_accepte','boire_verre_refuse','nuit_escort','plainte_sans_suite','plainte_enquete','plainte_confirmee','cellules_fragilisees','presence_suspecte','plainte_egaree'/* justice_sovarka_rumeur_v1 */,'appel_escort'/* escort_rumeur_v1 *//* escort_scandale_v1 */])THEN
   fait:=jsonb_build_object('type_action',trace.type_action,'auteur',trace.auteur,'cible',trace.cible);gain:=1;
   IF trace.type_action='appel_escort'AND coalesce(a.pa,0)>=coalesce(cout_pa,0)THEN PERFORM public.escort_scandale_ecoute_interne(trace.id);END IF;
  END IF;
 END IF;
 source:=coalesce(source,(ARRAY['Le Commissaire','Un député','Un journaliste','Un commerçant','Un inconnu'])[floor(random()*5)::integer+1]);
 RETURN jsonb_build_object('ok',true,'pa_cout',cout_pa,'gain_inf',gain,'rumeur',fait,'source_rumeur',source);
END;$function$;

COMMIT;
