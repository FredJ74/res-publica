-- =============================================================================================
-- ARRESTATIONS EN FLAGRANT DÉLIT DÉCIDÉES PAR LE SERVEUR (Claude, 03/11/2026)
-- =============================================================================================
-- Suite du relevé du 03/11 (RELAIS.md). Les arrestations en flagrant délit étaient décidées par
-- l'écran : il tirait les jets (patrouille du couvre-feu, détachement militaire, corruption de
-- l'agent, fuite, résistance), choisissait la durée de la peine dans sa propre table, puis
-- demandait au serveur d'ouvrir la détention (detention_ouvrir_soi / detention_prolonger_soi).
-- Un joueur pouvait donc réduire sa peine, ou simplement ne jamais se faire arrêter.
--
-- Désormais :
--   . arrestation_flagrant_interne : le moteur commun. Barème lu au serveur (infractions /
--     infractions_categories, même règle que getPeineParActe), +2 jours de « Résistance à
--     l'arrestation » en cas d'aggravation, immunité militaire relue au serveur, motif d'avis
--     de recherche du même acte retiré dans la même transaction. Les motifs portent l'acte.
--   . Les actes dont le serveur tranchait déjà l'issue arrêtent eux-mêmes :
--       - corruption d'un fonctionnaire découverte (terrain_permis_corrompre) ;
--       - échec critique d'une distribution de tracts (calomnie_distribuer_consommer, 1 jour) ;
--       - vol de matériel militaire repéré (militaire_subtiliser_tenter, QHS 3 jours, retour à
--         la caserne).
--   . Pris sur le fait après un échec (neutralisation d'un député, empoisonnement raté) : le
--     serveur pose un flagrant délit en attente ; le joueur choisit dans la fenêtre d'arrestation
--     (se rendre, corrompre l'agent, fuir, résister) et arrestation_flagrant_choisir tire le jet
--     avec les formules d'origine. Sans flagrant délit en attente, aucun choix n'existe.
--   . couvre_feu_patrouille et militaire_detachement_arrestation : la patrouille (45 %) et le
--     détachement en mission « arrêter » (min(90, 30 + 2 × soldats)) tirés au serveur, à la
--     position relue en base.
--   . detention_clore_motif_eteint reconnaît la détention « pour seule désertion » à ses motifs
--     (le drapeau motifDesertionSeul n'était posé par personne : un déserteur ne pouvait jamais
--     être libéré par l'incorporation ni par l'extinction des poursuites).
--   . detention_ouvrir_soi et detention_prolonger_soi fermées à l'écran : plus aucun appelant.
--
-- À APPLIQUER APRÈS VERCEL READY : l'ancien écran appelle encore les deux portes fermées.
-- =============================================================================================

-- 1. Flagrant délit en attente du choix du joueur ---------------------------------------------
CREATE TABLE IF NOT EXISTS public.flagrants_delits_attente (
  personnage text PRIMARY KEY,
  acte       text NOT NULL,
  source     text,
  cree_le    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.flagrants_delits_attente ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.flagrants_delits_attente FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.flagrant_delit_poser_interne(p_nom text, p_acte text, p_source text)
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  INSERT INTO public.flagrants_delits_attente (personnage, acte, source, cree_le)
  VALUES (p_nom, p_acte, p_source, now())
  ON CONFLICT (personnage) DO UPDATE SET acte = EXCLUDED.acte, source = EXCLUDED.source, cree_le = now();
$$;

-- 2. Barème d'un acte (miroir de getPeineParActe, plateau-core.js) ----------------------------
CREATE OR REPLACE FUNCTION public.peine_acte_interne(p_acte text, p_pays text)
 RETURNS TABLE (libelle text, jours integer)
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE i record; c record;
BEGIN
  SELECT * INTO i FROM public.infractions WHERE id = p_acte;
  IF FOUND AND coalesce(p_pays, 'republic') = 'republic' AND i.bareme_propre THEN
    libelle := i.libelle; jours := i.jours_reference; RETURN NEXT; RETURN;
  END IF;
  SELECT * INTO c FROM public.infractions_categories
   WHERE id = coalesce(CASE WHEN FOUND THEN i.categorie END, p_acte);
  IF NOT FOUND THEN SELECT * INTO c FROM public.infractions_categories WHERE id = 'delit_mineur'; END IF;
  libelle := c.libelle; jours := c.jours_reference; RETURN NEXT;
END $$;

-- 3. Immunité militaire (miroir d'estImmuniteMilitaire, plateau-politique.js) -----------------
CREATE OR REPLACE FUNCTION public.immunite_militaire_interne(p_nom text)
 RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE p record; v_emp text; v_ici text;
BEGIN
  SELECT poste, domicile, country INTO p FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND OR coalesce(p.poste ->> 'id', '') NOT IN ('lieutenant', 'capitaine', 'commandant') THEN RETURN false; END IF;
  v_ici := coalesce(p.country, 'republic');
  v_emp := coalesce(CASE WHEN jsonb_typeof(p.domicile) = 'object' THEN p.domicile ->> 'country' END, v_ici);
  IF EXISTS (SELECT 1 FROM public.guerres g
              WHERE coalesce(g.data ->> 'statut', g.statut) = 'active'
                AND ((g.data ->> 'attaquant' = v_emp AND g.data ->> 'attaque' = v_ici)
                  OR (g.data ->> 'attaque' = v_emp AND g.data ->> 'attaquant' = v_ici))) THEN
    RETURN true;
  END IF;
  RETURN v_ici = v_emp AND coalesce((SELECT (b.data ->> 'mobilisationNationaleActive')::boolean
                                       FROM public.budgets_nationaux b WHERE b.id = v_emp), false);
END $$;

-- 4. Le moteur commun de l'arrestation en flagrant délit --------------------------------------
CREATE OR REPLACE FUNCTION public.arrestation_flagrant_interne(
  p_nom text, p_acte text, p_aggravation boolean, p_source text,
  p_libelle text DEFAULT NULL, p_jours integer DEFAULT NULL,
  p_qhs boolean DEFAULT false, p_retour_ville text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE p record; v_libelle text; v_jours integer; v_total integer; v_motifs jsonb; v_r jsonb;
  v_ts text := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe', 0));
  SELECT name, country, current_city, est_emprisonne, coalesce(day, 1) AS jour INTO p
    FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF public.immunite_militaire_interne(p_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'immunite_militaire');
  END IF;

  IF p_jours IS NOT NULL THEN
    v_libelle := coalesce(p_libelle, 'Flagrant délit'); v_jours := p_jours;
  ELSE
    SELECT b.libelle, b.jours INTO v_libelle, v_jours FROM public.peine_acte_interne(p_acte, p.country) b;
  END IF;
  IF v_jours IS NULL OR v_jours < 1 THEN RAISE EXCEPTION 'arrestation_flagrant_interne : barème absent pour %', p_acte; END IF;

  v_motifs := jsonb_build_array(jsonb_build_object('type', v_libelle, 'acte', p_acte, 'jour_fait', p.jour,
                'city', p.current_city, 'jours', v_jours, 'source', 'flagrant_delit', 'date_evenement', v_ts));
  v_total := v_jours;
  IF p_aggravation THEN
    v_motifs := v_motifs || jsonb_build_array(jsonb_build_object('type', 'Résistance à l’arrestation',
                  'acte', 'resistance_arrestation', 'jour_fait', p.jour, 'city', p.current_city,
                  'jours', 2, 'source', 'flagrant_delit', 'date_evenement', v_ts));
    v_total := v_total + 2;
  END IF;

  IF p.est_emprisonne IS NOT NULL AND jsonb_typeof(p.est_emprisonne) = 'object' THEN
    -- Déjà détenu : seule une sanction QHS s'ajoute à la peine en cours (règle d'origine).
    IF NOT p_qhs THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_detenu'); END IF;
    v_r := public.detention_prolonger_interne(p_nom, v_motifs, true);
  ELSE
    v_r := public.detention_ouvrir_interne(p_nom, v_libelle, v_total, p.current_city, p.country, v_motifs,
             'flagrant_delit', p_source,
             CASE WHEN p_retour_ville IS NOT NULL THEN jsonb_build_object('retour_ville', p_retour_ville) ELSE '{}'::jsonb END);
    IF coalesce((v_r ->> 'ok')::boolean, false) AND p_qhs THEN
      PERFORM public.detention_qhs_poser_interne(p_nom, v_r ->> 'detention_id', v_libelle);
    END IF;
  END IF;
  IF NOT coalesce((v_r ->> 'ok')::boolean, false) THEN RETURN v_r; END IF;

  -- Le motif jugé sort de l'avis de recherche (procederArrestation faisait retirerRecherche).
  PERFORM set_config('rp.recherche_interne', 'on', true);
  UPDATE public.personnages_donnees d
     SET recherche = coalesce((SELECT jsonb_agg(e ORDER BY o) FROM jsonb_array_elements(d.recherche) WITH ORDINALITY x(e, o)
                                WHERE NOT (e ->> 'acte' = p_acte AND (e ->> 'country' IS NULL OR e ->> 'country' = p.country))), '[]'::jsonb)
   WHERE d.name = p_nom AND jsonb_typeof(d.recherche) = 'array';

  RETURN v_r || jsonb_build_object('ok', true, 'acte', p_acte, 'raison_peine', v_libelle, 'jours', v_total, 'qhs', p_qhs);
END $$;

-- 5. Les actes qui arrêtent eux-mêmes (patchs en place de fragments vérifiés) -----------------
DO $patch$
DECLARE v_def text; v_ancre text; v_ajout text;
  PROCEDURE_UNIQUE CONSTANT text := 'ancre absente ou multiple';
BEGIN
  -- 5a. Corruption d'un fonctionnaire découverte.
  v_def := pg_get_functiondef('public.terrain_permis_corrompre(text,uuid)'::regprocedure);
  IF position('arrestation_flagrant_interne' in v_def) = 0 THEN
    v_ancre := E'    r := jsonb_build_object(''ok'',true,''decouvert'',true,''repere'',repere);\n';
    v_ajout := v_ancre || E'    r := r || jsonb_build_object(''arrestation'', public.arrestation_flagrant_interne(moi, ''corruption_fonctionnaire'', false, ''corruption_permis''));\n';
    IF (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre) <> 1 THEN RAISE EXCEPTION 'terrain_permis_corrompre : %', PROCEDURE_UNIQUE; END IF;
    EXECUTE replace(v_def, v_ancre, v_ajout);
  END IF;

  -- 5b. Échec critique d'une distribution de tracts : 1 jour.
  v_def := pg_get_functiondef('public.calomnie_distribuer_consommer(text,text,text,integer)'::regprocedure);
  IF position('arrestation_flagrant_interne' in v_def) = 0 THEN
    v_ancre := E'           pa = greatest(0, coalesce(pa, 0) - 1)\n     WHERE name = v_moi;\n  ELSE\n';
    v_ajout := E'           pa = greatest(0, coalesce(pa, 0) - 1)\n     WHERE name = v_moi;\n'
            || E'    r := r || jsonb_build_object(''arrestation'', public.arrestation_flagrant_interne(v_moi, ''tracts_calomnieux'', false, ''flagrant_delit'', ''Distribution de tracts calomnieux'', 1));\n  ELSE\n';
    IF (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre) <> 1 THEN RAISE EXCEPTION 'calomnie_distribuer_consommer : %', PROCEDURE_UNIQUE; END IF;
    EXECUTE replace(v_def, v_ancre, v_ajout);
  END IF;

  -- 5c. Vol de matériel militaire repéré : QHS 3 jours, retour à la caserne.
  v_def := pg_get_functiondef('public.militaire_subtiliser_tenter(text)'::regprocedure);
  IF position('arrestation_flagrant_interne' in v_def) = 0 THEN
    v_ancre := E'      ''detecte'', v_score < c_seuil_detection, ''score'', v_score);\n';
    v_ajout := E'      ''detecte'', v_score < c_seuil_detection, ''score'', v_score)\n'
            || E'      || CASE WHEN v_score < c_seuil_detection THEN jsonb_build_object(''arrestation'',\n'
            || E'           public.arrestation_flagrant_interne(v_moi, ''vol_materiel_militaire'', false, ''subtilisation'', ''Vol de matériel militaire'', 3, true, ''caserne''))\n'
            || E'         ELSE ''{}''::jsonb END;\n';
    IF (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre) <> 1 THEN RAISE EXCEPTION 'militaire_subtiliser_tenter : %', PROCEDURE_UNIQUE; END IF;
    EXECUTE replace(v_def, v_ancre, v_ajout);
  END IF;

  -- 5d. Neutralisation d'un député ratée : pris sur le fait.
  v_def := pg_get_functiondef('public.assemblee_neutraliser_depute(text,text,text,text)'::regprocedure);
  IF position('flagrant_delit_poser_interne' in v_def) = 0 THEN
    v_ancre := E'  RETURN public.assemblee_requete_clore(p_requete, v_debit || jsonb_build_object(\n';
    v_ajout := E'  IF NOT v_reussi THEN PERFORM public.flagrant_delit_poser_interne(p_nom, ''tentative_assassinat'', ''neutralisation_depute''); END IF;\n' || v_ancre;
    IF (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre) <> 1 THEN RAISE EXCEPTION 'assemblee_neutraliser_depute : %', PROCEDURE_UNIQUE; END IF;
    EXECUTE replace(v_def, v_ancre, v_ajout);
  END IF;

  -- 5e. Empoisonnement totalement raté : pris sur le fait.
  v_def := pg_get_functiondef('public.crime_empoisonner(text)'::regprocedure);
  IF position('flagrant_delit_poser_interne' in v_def) = 0 THEN
    v_ancre := E'  RETURN jsonb_build_object(''ok'', true, ''palier'', v_palier,';
    v_ajout := E'  IF v_palier = ''echec_total'' THEN PERFORM public.flagrant_delit_poser_interne(v_moi, ''tentative_empoisonnement'', ''empoisonnement''); END IF;\n' || v_ancre;
    IF (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre) <> 1 THEN RAISE EXCEPTION 'crime_empoisonner : %', PROCEDURE_UNIQUE; END IF;
    EXECUTE replace(v_def, v_ancre, v_ajout);
  END IF;
END $patch$;

-- 6. Le choix du joueur pris sur le fait ------------------------------------------------------
-- Formules d'origine (tenterCorruptionArrestation, tenterFuite, tenterResistance) :
--   corruption : 500 FR, min(85, 45 + floor(DUP/10) × 5) ; réussite DIS −10 et dernier motif de
--                recherche effacé ; échec DIS −15 et arrestation aggravée ;
--   fuite      : min(70, 30 + floor(DIS/10) + floor(VOL/2)) ; réussite DIS −20 ; échec aggravée ;
--   résistance : min(30, 2 × VOL) ; réussite DIS −30, PV −15, avis de recherche « rébellion »
--                (délit grave) ; échec arrestation aggravée et PV −20 (jamais sous 1).
CREATE OR REPLACE FUNCTION public.arrestation_flagrant_choisir(p_choix text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; f record; p record; v_dis numeric; v_vol numeric; v_dup numeric;
  v_taux integer; v_jet integer; v_reussi boolean; v_arr jsonb; v_deb jsonb; v_rech jsonb;
  v_out jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_choix NOT IN ('reddition', 'corruption', 'fuite', 'resistance') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'choix_invalide');
  END IF;
  SELECT * INTO f FROM public.flagrants_delits_attente WHERE personnage = v_moi FOR UPDATE;
  IF NOT FOUND OR f.cree_le < now() - interval '15 minutes' THEN
    DELETE FROM public.flagrants_delits_attente WHERE personnage = v_moi;
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_flagrant');
  END IF;
  SELECT stats, resources, hp, day, country INTO p FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  v_dis := coalesce(CASE WHEN jsonb_typeof(p.resources -> 'dis') = 'number' THEN (p.resources ->> 'dis')::numeric END, 50);
  v_vol := coalesce(CASE WHEN jsonb_typeof(p.stats -> 'VOL') = 'number' THEN (p.stats ->> 'VOL')::numeric END, 8);
  v_dup := coalesce(CASE WHEN jsonb_typeof(p.stats -> 'DUP') = 'number' THEN (p.stats ->> 'DUP')::numeric END, 8);

  IF p_choix = 'corruption' THEN
    v_deb := public.debiter_fonds_ordinaires(v_moi, 500);
    IF NOT coalesce((v_deb ->> 'ok')::boolean, false) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'cout', 500);  -- le flagrant délit reste en attente
    END IF;
  END IF;
  DELETE FROM public.flagrants_delits_attente WHERE personnage = v_moi;

  v_jet := 1 + floor(random() * 100)::integer;
  v_taux := CASE p_choix
    WHEN 'reddition'  THEN 0
    WHEN 'corruption' THEN least(85, 45 + floor(v_dup / 10)::integer * 5)
    WHEN 'fuite'      THEN least(70, 30 + floor(v_dis / 10)::integer + floor(v_vol / 2)::integer)
    ELSE least(30, (v_vol * 2)::integer) END;
  v_reussi := p_choix <> 'reddition' AND v_jet <= v_taux;

  -- Effets d'origine sur DIS et PV, avant l'éventuelle arrestation.
  UPDATE public.personnages_donnees
     SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{dis}',
           to_jsonb(greatest(0, v_dis - CASE
             WHEN p_choix = 'corruption' THEN CASE WHEN v_reussi THEN 10 ELSE 15 END
             WHEN p_choix = 'fuite' AND v_reussi THEN 20
             WHEN p_choix = 'resistance' AND v_reussi THEN 30
             ELSE 0 END))),
         hp = CASE WHEN p_choix = 'resistance' THEN greatest(1, coalesce(hp, 100) - CASE WHEN v_reussi THEN 15 ELSE 20 END) ELSE hp END
   WHERE name = v_moi;

  v_out := jsonb_build_object('ok', true, 'choix', p_choix, 'acte', f.acte, 'jet', v_jet, 'taux', v_taux, 'reussi', v_reussi);
  IF v_reussi THEN
    IF p_choix = 'corruption' THEN
      PERFORM set_config('rp.recherche_interne', 'on', true);
      UPDATE public.personnages_donnees
         SET recherche = recherche - (jsonb_array_length(recherche) - 1)
       WHERE name = v_moi AND jsonb_typeof(recherche) = 'array' AND jsonb_array_length(recherche) > 0;
    ELSIF p_choix = 'resistance' THEN
      v_rech := public.recherche_inscrire(jsonb_build_object('acte', 'rebellion', 'type', 'delit_grave',
                  'jour', coalesce(p.day, 1), 'country', p.country));
    END IF;
  ELSE
    v_arr := public.arrestation_flagrant_interne(v_moi, f.acte, p_choix <> 'reddition', 'flagrant_' || p_choix);
    v_out := v_out || jsonb_build_object('arrestation', v_arr);
  END IF;
  RETURN v_out || (SELECT jsonb_build_object('dis', resources -> 'dis', 'hp', hp, 'recherche', recherche,
                                             'liquide', liquide, 'arg', arg)
                     FROM public.personnages_donnees WHERE name = v_moi);
END $$;

-- 7. Patrouille du couvre-feu (verifierCouvreFeu) ---------------------------------------------
CREATE OR REPLACE FUNCTION public.couvre_feu_patrouille()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; p record; v_cf jsonb; v_heure integer := extract(hour FROM now() AT TIME ZONE 'Europe/Paris');
  v_arr jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, poste, requisition, est_emprisonne INTO p FROM public.personnages_donnees WHERE name = v_moi;
  IF p.est_emprisonne IS NOT NULL THEN RETURN jsonb_build_object('ok', true, 'interpelle', false); END IF;
  SELECT b.data -> 'couvreFeu' INTO v_cf FROM public.budgets_nationaux b WHERE b.id = p.country;
  IF jsonb_typeof(v_cf) <> 'object' OR NOT coalesce((v_cf ->> 'actif')::boolean, false)
     OR ((v_cf ->> 'dateFin') IS NOT NULL AND (extract(epoch FROM now()) * 1000) > (v_cf ->> 'dateFin')::numeric)
     OR NOT (v_heure >= 20 OR v_heure < 6)
     OR coalesce(p.poste ->> 'id', '') IN ('lieutenant', 'capitaine', 'commandant', 'min_def')
     OR coalesce(p.requisition ->> 'statut', '') IN ('convoque', 'affecte')
     OR random() >= 0.45 THEN
    RETURN jsonb_build_object('ok', true, 'interpelle', false);
  END IF;
  v_arr := public.arrestation_flagrant_interne(v_moi, 'violation_couvre_feu', false, 'patrouille_couvre_feu');
  RETURN jsonb_build_object('ok', true, 'interpelle', coalesce((v_arr ->> 'ok')::boolean, false), 'arrestation', v_arr);
END $$;

-- 8. Détachement militaire en mission « arrêter » (verifierMissionMilitaireEntree) ------------
CREATE OR REPLACE FUNCTION public.militaire_detachement_arrestation()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; p record; v_n integer; v_chance integer; v_jet integer; v_arr jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, poste, est_emprisonne INTO p
    FROM public.personnages_donnees WHERE name = v_moi;
  IF p.est_emprisonne IS NOT NULL OR p.current_building IS NULL
     OR coalesce(p.poste ->> 'id', '') IN ('lieutenant', 'capitaine', 'commandant', 'min_def') THEN
    RETURN jsonb_build_object('ok', true, 'interpelle', false);
  END IF;
  SELECT count(*)::integer INTO v_n
    FROM public.pnj_membres m
    JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
    JOIN public.compagnies_militaires c ON c.id = sm.compagnie_id
    CROSS JOIN LATERAL public.pnj_position_effective(m.id) pe
   WHERE m.famille = 'soldat' AND m.statut = 'actif' AND sm.en_reserve = false AND m.pays = p.country
     AND pe.ville = p.current_city AND pe.building_id = p.current_building AND pe.room_id = p.current_room
     AND EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(c.data -> 'sections') = 'array'
                                                         THEN c.data -> 'sections' ELSE '[]'::jsonb END) s
                  WHERE s ->> 'id' = sm.section_id AND s ->> 'mission' = 'arreter');
  IF v_n = 0 THEN RETURN jsonb_build_object('ok', true, 'interpelle', false); END IF;
  v_chance := least(90, 30 + v_n * 2);
  v_jet := 1 + floor(random() * 100)::integer;
  IF v_jet > v_chance THEN RETURN jsonb_build_object('ok', true, 'interpelle', false, 'soldats', v_n); END IF;
  v_arr := public.arrestation_flagrant_interne(v_moi, 'intrusion_zone_militaire', false, 'detachement_militaire');
  RETURN jsonb_build_object('ok', true, 'interpelle', coalesce((v_arr ->> 'ok')::boolean, false),
                            'soldats', v_n, 'arrestation', v_arr);
END $$;

-- 9. Libération d'un détenu pour seule désertion ----------------------------------------------
DO $patch$
DECLARE v_def text := pg_get_functiondef('public.detention_clore_motif_eteint(text)'::regprocedure);
  v_ancre text := E'  IF coalesce((v_peine->>''motifDesertionSeul'')::boolean, false) IS NOT TRUE THEN\n';
  v_ajout text := E'  -- deserteur_seul_par_motifs_v1 : la détention ne tient qu''à la désertion si tous ses motifs en relèvent.\n'
               || E'  IF coalesce((v_peine->>''motifDesertionSeul'')::boolean, false) IS NOT TRUE\n'
               || E'     AND NOT EXISTS (SELECT 1 FROM public.detentions t\n'
               || E'                      WHERE t.id = (SELECT a.id FROM public.detention_active(v_moi) a)\n'
               || E'                        AND jsonb_typeof(t.motifs) = ''array'' AND jsonb_array_length(t.motifs) > 0\n'
               || E'                        AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(t.motifs) m\n'
               || E'                                         WHERE coalesce(m->>''acte'', m->>''type'') IS DISTINCT FROM ''desertion'')) THEN\n';
BEGIN
  IF position('deserteur_seul_par_motifs_v1' in v_def) > 0 THEN RETURN; END IF;
  IF (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre) <> 1 THEN
    RAISE EXCEPTION 'detention_clore_motif_eteint : ancre absente ou multiple';
  END IF;
  EXECUTE replace(v_def, v_ancre, v_ajout);
END $patch$;

-- 10. Droits ----------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.flagrant_delit_poser_interne(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.peine_acte_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.immunite_militaire_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.arrestation_flagrant_interne(text, text, boolean, text, text, integer, boolean, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.arrestation_flagrant_choisir(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.couvre_feu_patrouille() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_detachement_arrestation() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.arrestation_flagrant_choisir(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.couvre_feu_patrouille() TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_detachement_arrestation() TO authenticated;
-- Plus aucun appelant à l'écran : l'ouverture et la prolongation « sur soi » se ferment.
REVOKE EXECUTE ON FUNCTION public.detention_ouvrir_soi(text, integer, text, jsonb, boolean, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.detention_prolonger_soi(jsonb, boolean) FROM PUBLIC, anon, authenticated;

-- 11. Contrôles -------------------------------------------------------------------------------
DO $$
BEGIN
  IF has_function_privilege('authenticated', 'public.detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb)', 'execute')
     OR has_function_privilege('authenticated', 'public.detention_prolonger_soi(jsonb,boolean)', 'execute') THEN
    RAISE EXCEPTION 'portes de détention sur soi encore ouvertes';
  END IF;
  IF has_function_privilege('authenticated', 'public.arrestation_flagrant_interne(text,text,boolean,text,text,integer,boolean,text)', 'execute') THEN
    RAISE EXCEPTION 'moteur d''arrestation joignable par l''écran';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.arrestation_flagrant_choisir(text)', 'execute') THEN
    RAISE EXCEPTION 'arrestation_flagrant_choisir doit être ouverte à authenticated';
  END IF;
  IF (SELECT jours FROM public.peine_acte_interne('violation_couvre_feu', 'republic')) <> 1
     OR (SELECT jours FROM public.peine_acte_interne('intrusion_zone_militaire', 'republic')) <> 2
     OR (SELECT jours FROM public.peine_acte_interne('corrompre_juge', 'republic')) <> 4 THEN
    RAISE EXCEPTION 'barème serveur différent de getPeineParActe';
  END IF;
END $$;
