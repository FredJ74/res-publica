-- Mission du 27/11/2026 (soir, Claude), étape 1 — « Interroger un détenu » au goulag, au QHS et au Renseignement.
-- Décision de Fred du 27/11/2026 : les trois lieux suivent l'interrogatoire du goulag (GAME-DESIGN-GOULAG-SOVARKA-ORDRES-
-- INTERNES.md, 17/11) : 1 PA pour l'interrogateur, −7 PA au détenu (plancher 1), refus si le détenu a 1 PA ou moins,
-- jet 50 % + 5 par point de Volonté d'écart (borné 5–95 %). Deux traces à chaque interrogatoire :
--   • contre le détenu, en cas de succès : un fait réel encore inconnu (historique_crimes ou actions_tracables non
--     découvertes), jamais déjà révélé. Goulag et QHS : il part au juge qui a condamné. Renseignement (voleur
--     d'archives retenu par le barème, sans juge) : il part aux juges du pays, et le ministre qui a interrogé reçoit
--     le même contenu au courrier, sans bouton. Les juges destinataires voient l'indice au Bureau des magistrats
--     (« Indices d'interrogatoire ») et peuvent s'en saisir (affaire ouverte à leur nom) ou le classer ;
--   • contre l'interrogateur, réussi ou non : « mauvais traitement » consigné dans actions_tracables (enquête du
--     commissaire, plainte_instruire_interne) et dans son historique_crimes (circuit des plaintes et des procès).
-- Mêmes personnes qu'avant : visiteur habilité au goulag, commissaire au QHS, ministre de la Défense (et de la
-- Sécurité du Peuple en Sovarka) au Renseignement. Les deux ordres creux « interroger » et « interroger_renseignement »
-- de ordres_generiques sont retirés. Le goulag reste verrouillé : sovarka_goulag_ordres_refus_interne n'est pas touchée.
--
-- Contrôles en lecture après application :
--   SELECT count(*) FROM public.ordres_generiques WHERE fn IN ('interroger', 'interroger_renseignement');      -- 0
--   SELECT fn, pa, cost FROM public.ordres_couts WHERE fn IN ('interroger', 'interroger_renseignement');      -- 1 PA, 0
--   SELECT position('interrogatoire_traces_v1' in pg_get_functiondef(p)) > 0 FROM unnest(ARRAY[
--     'public.sovarka_goulag_interroger(text,uuid)'::regprocedure, 'public.renseignement_interroger(text)'::regprocedure,
--     'public.qhs_interroger(text,uuid)'::regprocedure]) p;                                                    -- vrai ×3
BEGIN;

CREATE TABLE IF NOT EXISTS public.interrogatoires_indices (
  id bigserial PRIMARY KEY,
  lieu text NOT NULL CHECK (lieu IN ('goulag', 'qhs', 'renseignement')),
  pays text NOT NULL,
  detenu text NOT NULL,
  interrogateur text NOT NULL,
  juge text,                       -- NULL : tous les juges du pays (Renseignement)
  trace_cle text NOT NULL,
  faits jsonb NOT NULL,
  texte text NOT NULL,
  statut text NOT NULL DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'saisi', 'classe')),
  traite_par text,
  affaire_id text,
  cree_le timestamptz NOT NULL DEFAULT now(),
  traite_le timestamptz,
  UNIQUE (detenu, trace_cle)
);
ALTER TABLE public.interrogatoires_indices ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.interrogatoires_indices FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.interrogatoires_indices_id_seq FROM PUBLIC, anon, authenticated;

-- Rejeu d'une même confirmation (QHS) : une clé de requête, un seul interrogatoire.
CREATE TABLE IF NOT EXISTS public.interrogatoires_journal (
  requete uuid PRIMARY KEY,
  lieu text NOT NULL,
  interrogateur text NOT NULL,
  detenu text NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.interrogatoires_journal ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.interrogatoires_journal FROM PUBLIC, anon, authenticated;

DELETE FROM public.ordres_generiques WHERE fn IN ('interroger', 'interroger_renseignement');
UPDATE public.ordres_couts SET pa = 1, cost = 0 WHERE fn IN ('interroger', 'interroger_renseignement');

-- Un fait réel du détenu, encore inconnu : ni découvert par la justice, ni déjà révélé par un interrogatoire.
CREATE OR REPLACE FUNCTION public.interrogatoire_trace_tirer_interne(p_detenu text)
RETURNS TABLE(cle text, faits jsonb)
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH d AS (SELECT name, historique_crimes FROM public.personnages_donnees WHERE name = p_detenu),
  traces AS (
    SELECT 'historique_crimes:' || md5(d.name || '|' || coalesce(t.value->>'id','') || '|'
             || coalesce(t.value->>'acte','') || '|' || coalesce(t.value->>'cible','') || '|'
             || coalesce(t.value->>'jour','') || '|' || coalesce(t.value->>'ts','')) AS cle,
           jsonb_build_object('acte', t.value->>'acte', 'victime', t.value->>'cible', 'jour', t.value->'jour') AS faits
      FROM d CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(d.historique_crimes) = 'array'
             THEN d.historique_crimes ELSE '[]'::jsonb END) t(value)
     WHERE coalesce(t.value->>'acte','') <> ''
    UNION ALL
    SELECT 'actions_tracables:' || a.id,
           jsonb_build_object('acte', a.type_action, 'victime', a.cible, 'jour', a.jour, 'ville', a.city)
      FROM public.actions_tracables a
     WHERE a.auteur = p_detenu AND coalesce(a.type_action,'') <> '' AND NOT coalesce(a.decouvert, false)
  )
  SELECT tr.cle, tr.faits FROM traces tr
   WHERE NOT EXISTS (SELECT 1 FROM public.interrogatoires_indices x WHERE x.detenu = p_detenu AND x.trace_cle = tr.cle)
     AND NOT EXISTS (SELECT 1 FROM public.sovarka_goulag_traces_revelees x WHERE x.nom = p_detenu AND x.trace_cle = tr.cle)
   ORDER BY random() LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.interrogatoire_trace_tirer_interne(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.interrogatoire_fait_texte_interne(p_faits jsonb)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT '« ' || coalesce(nullif(p_faits->>'acte',''), '?') || ' »'
      || coalesce(', visant ' || nullif(p_faits->>'victime',''), '')
      || coalesce(', jour ' || nullif(p_faits->>'jour',''), '')
      || coalesce(', lieu ' || nullif(p_faits->>'ville',''), '')
$$;
REVOKE ALL ON FUNCTION public.interrogatoire_fait_texte_interne(jsonb) FROM PUBLIC, anon, authenticated;

-- L'indice posé pour le juge destinataire (ou pour tous les juges du pays si p_juge est NULL).
CREATE OR REPLACE FUNCTION public.interrogatoire_indice_poser_interne(p_lieu text, p_pays text, p_detenu text,
  p_interrogateur text, p_juge text, p_cle text, p_faits jsonb)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_id bigint;
BEGIN
  INSERT INTO public.interrogatoires_indices (lieu, pays, detenu, interrogateur, juge, trace_cle, faits, texte)
  VALUES (p_lieu, p_pays, p_detenu, p_interrogateur, p_juge, p_cle, p_faits, public.interrogatoire_fait_texte_interne(p_faits))
  ON CONFLICT (detenu, trace_cle) DO NOTHING RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.interrogatoire_indice_poser_interne(text, text, text, text, text, text, jsonb) FROM PUBLIC, anon, authenticated;

-- La trace contre l'interrogateur, réussi ou non : un mauvais traitement exploitable par l'enquête et les plaintes.
CREATE OR REPLACE FUNCTION public.interrogatoire_mauvais_traitement_interne(p_lieu text, p_interrogateur text,
  p_detenu text, p_pays text, p_ville text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_jour integer := coalesce(public.jour_de_jeu_pays(p_pays), 1);
BEGIN
  INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration, decouvert)
  VALUES ('trace-mauvais-traitement-' || replace(gen_random_uuid()::text, '-', ''), p_interrogateur, p_detenu,
          'mauvais_traitement', p_pays, coalesce(p_ville, 'capitale'), v_jour, v_jour + 8, false);
  PERFORM public.crime_tracer_interne(p_interrogateur, 'mauvais_traitement', p_detenu);
  PERFORM public.mail_systeme_poser_interne(CASE p_lieu WHEN 'goulag' THEN 'Camp de rééducation de Sovarka'
      WHEN 'qhs' THEN 'Quartier Haute Sécurité' ELSE 'Direction du Renseignement' END, p_detenu,
    'Vous avez été interrogé', 'Vous avez été interrogé par ' || p_interrogateur || CASE p_lieu
      WHEN 'goulag' THEN ' au camp de rééducation.' WHEN 'qhs' THEN ' en salle d''interrogatoire du Quartier Haute Sécurité.'
      ELSE ' en salle d''interrogatoire de la Direction du Renseignement.' END);
END $$;
REVOKE ALL ON FUNCTION public.interrogatoire_mauvais_traitement_interne(text, text, text, text, text) FROM PUBLIC, anon, authenticated;

-- Le jet commun : 50 % + 5 par point de Volonté d'écart, borné 5–95 %.
CREATE OR REPLACE FUNCTION public.interrogatoire_probabilite_interne(p_interrogateur text, p_detenu text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT least(95, greatest(5, round(50 + 5 * (
      public.assemblee_stat_base((SELECT CASE WHEN jsonb_typeof(stats) = 'object' THEN stats ELSE '{}'::jsonb END
                                    FROM public.personnages_donnees WHERE name = p_interrogateur), 'VOL')
    - public.assemblee_stat_base((SELECT CASE WHEN jsonb_typeof(stats) = 'object' THEN stats ELSE '{}'::jsonb END
                                    FROM public.personnages_donnees WHERE name = p_detenu), 'VOL')))::integer))
$$;
REVOKE ALL ON FUNCTION public.interrogatoire_probabilite_interne(text, text) FROM PUBLIC, anon, authenticated;

-- ============================================================== GOULAG (verrou inchangé)
CREATE OR REPLACE FUNCTION public.sovarka_goulag_interroger(p_detenu text, p_requete uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- interrogatoire_traces_v1 : indice aussi posé au Bureau des magistrats pour le juge qui a condamné, et mauvais
-- traitement consigné contre l'interrogateur (Fred, 27/11/2026). Le reste est inchangé (17/11/2026).
DECLARE v_nom text := public.mon_personnage(); v_refus jsonb; v_det text; v_deja jsonb;
        d public.personnages_donnees%ROWTYPE; r public.sovarka_goulag_registre%ROWTYPE;
        v_vol_i numeric; v_vol_d numeric; v_proba integer; v_jet integer; v_reussi boolean;
        v_trace_cle text; v_trace_faits jsonb; v_mail jsonb; v_pa integer; v_res jsonb; v_ville text;
        v_paie jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF p_requete IS NULL OR coalesce(btrim(p_detenu),'') = '' THEN
    RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF NOT public.sovarka_goulag_habilite_present_interne(v_nom,'bureau_chef') THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_habilite_bureau'); END IF;
  IF btrim(p_detenu) = v_nom THEN RETURN jsonb_build_object('ok',false,'raison','cible_invalide'); END IF;
  SELECT * INTO d FROM public.personnages_donnees WHERE name = btrim(p_detenu) FOR UPDATE;
  IF NOT FOUND OR d.country IS DISTINCT FROM 'soviet' THEN
    RETURN jsonb_build_object('ok',false,'raison','detenu_introuvable'); END IF;
  SELECT CASE WHEN interrogateur = v_nom AND detenu = d.name THEN resultat END INTO v_deja
    FROM public.sovarka_goulag_interrogatoires WHERE requete = p_requete;
  IF FOUND THEN
    IF v_deja IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_deja_utilisee'); END IF;
    RETURN v_deja || jsonb_build_object('rejeu',true);
  END IF;
  v_det := public.sovarka_goulag_detention_registree_interne(d.name);
  SELECT * INTO r FROM public.sovarka_goulag_registre WHERE detention_id = v_det FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','detenu_introuvable'); END IF;
  IF coalesce(d.pa,0) <= 1 THEN
    RETURN jsonb_build_object('ok',false,'raison','detenu_epuise'); END IF;
  v_paie := public.payer_ordre_interne(v_nom, 'sovarka_goulag_interroger', 1, 0);
  IF coalesce((v_paie->>'ok')::boolean,false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_pa := greatest(1, coalesce(d.pa,0) - 7);
  UPDATE public.personnages_donnees SET pa = v_pa, updated_at = clock_timestamp() WHERE name = d.name;
  SELECT public.assemblee_stat_base(CASE WHEN jsonb_typeof(stats) = 'object' THEN stats ELSE '{}'::jsonb END,'VOL')
    INTO v_vol_i FROM public.personnages_donnees WHERE name = v_nom;
  v_vol_d := public.assemblee_stat_base(CASE WHEN jsonb_typeof(d.stats) = 'object' THEN d.stats ELSE '{}'::jsonb END,'VOL');
  v_proba := least(95, greatest(5, round(50 + 5 * (v_vol_i - v_vol_d))::integer));
  v_jet := floor(random() * 100)::integer + 1;
  v_reussi := v_jet <= v_proba;
  IF v_reussi THEN
    SELECT t.cle, t.faits INTO v_trace_cle, v_trace_faits FROM public.interrogatoire_trace_tirer_interne(d.name) t;
  END IF;
  UPDATE public.sovarka_goulag_registre SET interrogatoires = interrogatoires + 1
   WHERE detention_id = r.detention_id;
  v_res := jsonb_build_object('ok',true,'detenu',d.name,'probabilite',v_proba,'jet',v_jet,
    'reussi',v_reussi,'revelation',v_trace_cle IS NOT NULL,
    'transmis_au_juge',false,'pa_detenu',v_pa,'pa',(v_paie->>'pa')::integer);
  INSERT INTO public.sovarka_goulag_interrogatoires(requete,interrogateur,detenu,detention_id,
    vol_interrogateur,vol_detenu,probabilite,jet,reussi,trace_cle,juge,pa_avant,pa_apres,resultat)
  VALUES (p_requete,v_nom,d.name,r.detention_id,v_vol_i,v_vol_d,v_proba,v_jet,v_reussi,
    v_trace_cle,r.juge,d.pa,v_pa,v_res);
  PERFORM public.interrogatoire_mauvais_traitement_interne('goulag', v_nom, d.name, 'soviet', d.current_city);
  IF v_trace_cle IS NOT NULL THEN
    INSERT INTO public.sovarka_goulag_traces_revelees(nom,trace_cle,interrogatoire,juge)
    VALUES (d.name,v_trace_cle,p_requete,r.juge);
    IF r.juge IS NOT NULL THEN
      PERFORM public.interrogatoire_indice_poser_interne('goulag', 'soviet', d.name, v_nom, r.juge, v_trace_cle, v_trace_faits);
      v_ville := v_trace_faits->>'ville';
      v_mail := public.mail_systeme_poser_interne('Camp de rééducation de Sovarka', r.juge,
        'Interrogatoire au goulag : ' || d.name,
        'Le détenu ' || d.name || ', condamné au goulag par votre jugement'
        || coalesce(' ' || r.jugement_id, '') || ', a été interrogé par ' || v_nom
        || '. Il a révélé un fait : « ' || coalesce(v_trace_faits->>'acte','?') || ' »'
        || coalesce(', visant ' || nullif(v_trace_faits->>'victime',''), '')
        || coalesce(', jour ' || nullif(v_trace_faits->>'jour',''), '')
        || coalesce(', lieu ' || nullif(v_ville,''), '')
        || '. Ce courrier vous est strictement personnel. Vous pouvez vous en saisir au Bureau des magistrats'
        || ' (« Indices d''interrogatoire »).');
      IF coalesce((v_mail->>'ok')::boolean,false) THEN
        v_res := v_res || jsonb_build_object('transmis_au_juge',true);
        UPDATE public.sovarka_goulag_interrogatoires SET mail_id = v_mail->>'id', resultat = v_res
         WHERE requete = p_requete;
      END IF;
    END IF;
  END IF;
  RETURN v_res;
END $function$;

-- ============================================================== QHS (commissaire, salle d'interrogatoire)
CREATE OR REPLACE FUNCTION public.qhs_interrogateur_refus_interne(p_nom text, p_poste text, p_pays text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF p_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_poste IS DISTINCT FROM 'commissaire' THEN RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_nom AND country = p_pays
                   AND current_building = 'qhs-prison' AND current_room = 'salle_interrogatoire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.qhs_interrogateur_refus_interne(text, text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.qhs_detenus_interrogatoire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_nom text; v_poste text; v_pays text; v jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays FROM public.acteur_poste_courant() a;
  v := public.qhs_interrogateur_refus_interne(v_nom, v_poste, v_pays);
  IF v IS NOT NULL THEN RETURN v; END IF;
  RETURN jsonb_build_object('ok', true, 'detenus', coalesce((SELECT jsonb_agg(jsonb_build_object(
      'nom', p.name, 'raison', x.raison, 'jour_fin', x.jour_fin) ORDER BY p.name)
    FROM public.detentions x JOIN public.personnages_donnees p ON p.name = x.nom
   WHERE x.country = v_pays AND x.qhs AND x.jour_fin_effective IS NULL AND x.date_fin_effective IS NULL
     AND (SELECT a.id FROM public.detention_active(x.nom) a) = x.id AND p.name <> v_nom), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.qhs_detenus_interrogatoire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.qhs_detenus_interrogatoire() TO authenticated;

CREATE OR REPLACE FUNCTION public.qhs_interroger(p_detenu text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
-- interrogatoire_traces_v1 : modèle du goulag (Fred, 27/11/2026).
DECLARE v_nom text; v_poste text; v_pays text; v jsonb; d public.personnages_donnees%ROWTYPE; v_det text;
  v_deja public.interrogatoires_journal%ROWTYPE; v_paie jsonb; v_pa integer; v_proba integer; v_jet integer;
  v_reussi boolean; v_cle text; v_faits jsonb; v_juge text; v_jugement text; v_res jsonb; v_mail jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays FROM public.acteur_poste_courant() a;
  v := public.qhs_interrogateur_refus_interne(v_nom, v_poste, v_pays);
  IF v IS NOT NULL THEN RETURN v; END IF;
  IF p_requete IS NULL OR coalesce(btrim(p_detenu), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  SELECT * INTO d FROM public.personnages_donnees WHERE name = btrim(p_detenu) FOR UPDATE;
  SELECT * INTO v_deja FROM public.interrogatoires_journal WHERE requete = p_requete;
  IF FOUND THEN
    IF v_deja.interrogateur = v_nom AND v_deja.detenu = d.name THEN RETURN v_deja.resultat || jsonb_build_object('rejeu', true); END IF;
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_deja_utilisee');
  END IF;
  IF d.name IS NULL OR d.name = v_nom THEN RETURN jsonb_build_object('ok', false, 'raison', 'detenu_introuvable'); END IF;
  SELECT a.id INTO v_det FROM public.detention_active(d.name) a;
  IF v_det IS NULL OR NOT EXISTS (SELECT 1 FROM public.detentions x WHERE x.id = v_det AND x.qhs AND x.country = v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'detenu_introuvable'); END IF;
  IF coalesce(d.pa, 0) <= 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'detenu_epuise'); END IF;
  v_paie := public.payer_ordre(v_nom, 'interroger', 1, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_pa := greatest(1, coalesce(d.pa, 0) - 7);
  UPDATE public.personnages_donnees SET pa = v_pa, updated_at = clock_timestamp() WHERE name = d.name;
  v_proba := public.interrogatoire_probabilite_interne(v_nom, d.name);
  v_jet := floor(random() * 100)::integer + 1;
  v_reussi := v_jet <= v_proba;
  IF v_reussi THEN SELECT t.cle, t.faits INTO v_cle, v_faits FROM public.interrogatoire_trace_tirer_interne(d.name) t; END IF;
  -- Le juge qui a condamné : le dernier jugement rendu contre ce détenu dans ce pays.
  SELECT j.juge, j.id INTO v_juge, v_jugement FROM public.jugements j
   WHERE j.accuse = d.name AND j.country = v_pays ORDER BY j.created_at DESC LIMIT 1;
  PERFORM public.interrogatoire_mauvais_traitement_interne('qhs', v_nom, d.name, v_pays, d.current_city);
  v_res := jsonb_build_object('ok', true, 'detenu', d.name, 'probabilite', v_proba, 'jet', v_jet, 'reussi', v_reussi,
    'revelation', v_cle IS NOT NULL, 'transmis_au_juge', false, 'pa_detenu', v_pa, 'pa', (v_paie->>'pa')::integer);
  IF v_cle IS NOT NULL AND v_juge IS NOT NULL THEN
    PERFORM public.interrogatoire_indice_poser_interne('qhs', v_pays, d.name, v_nom, v_juge, v_cle, v_faits);
    v_mail := public.mail_systeme_poser_interne('Quartier Haute Sécurité', v_juge, 'Interrogatoire au QHS : ' || d.name,
      'Le détenu ' || d.name || ', condamné par votre jugement' || coalesce(' ' || v_jugement, '') || ', a été interrogé par '
      || v_nom || '. Il a révélé un fait : ' || public.interrogatoire_fait_texte_interne(v_faits)
      || '. Ce courrier vous est strictement personnel. Vous pouvez vous en saisir au Bureau des magistrats'
      || ' (« Indices d''interrogatoire »).');
    v_res := v_res || jsonb_build_object('transmis_au_juge', coalesce((v_mail->>'ok')::boolean, false));
  END IF;
  INSERT INTO public.interrogatoires_journal (requete, lieu, interrogateur, detenu, resultat)
  VALUES (p_requete, 'qhs', v_nom, d.name, v_res);
  RETURN v_res;
END $$;
REVOKE ALL ON FUNCTION public.qhs_interroger(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.qhs_interroger(text, uuid) TO authenticated;

-- ============================================================== RENSEIGNEMENT (voleur d'archives, sans juge)
CREATE OR REPLACE FUNCTION public.renseignement_interroger(p_detenu text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- interrogatoire_traces_v1 : modèle du goulag (Fred, 27/11/2026) ; plus de +5 d'influence. Le fait révélé part aux
-- juges du pays (Bureau des magistrats) et, au courrier seulement, au ministre qui a interrogé.
DECLARE v_nom text; v_poste text; v_pays text; v jsonb; d record; v_paie jsonb; v_jet integer; v_proba integer;
  v_reussi boolean; v_pa integer; v_cle text; v_faits jsonb; v_texte text; v_juge text; v_nb integer := 0;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays FROM public.acteur_poste_courant() a;
  v := public.renseignement_interrogateur_refus_interne(v_nom, v_poste, v_pays);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT name, country, current_city, est_emprisonne, pa INTO d FROM public.personnages_donnees
   WHERE name = btrim(p_detenu) FOR UPDATE;
  IF d.name IS NULL OR jsonb_typeof(d.est_emprisonne) IS DISTINCT FROM 'object' OR NOT (d.est_emprisonne ? 'interrogatoire')
     OR d.country IS DISTINCT FROM v_pays OR d.name = v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_interrogatoire'); END IF;
  IF coalesce(d.pa, 0) <= 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'detenu_epuise'); END IF;
  v_paie := public.payer_ordre(v_nom, 'interroger_renseignement', 1, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_pa := greatest(1, coalesce(d.pa, 0) - 7);
  v_proba := public.interrogatoire_probabilite_interne(v_nom, d.name);
  v_jet := floor(random() * 100)::integer + 1;
  v_reussi := v_jet <= v_proba;
  IF v_reussi THEN SELECT t.cle, t.faits INTO v_cle, v_faits FROM public.interrogatoire_trace_tirer_interne(d.name) t; END IF;
  UPDATE public.personnages_donnees
     SET pa = v_pa, est_emprisonne = est_emprisonne - 'interrogatoire',
         current_building = CASE WHEN current_city = 'capitale' THEN 'commissariat' ELSE 'commissariat-local' END,
         current_room = CASE WHEN current_city = 'capitale' THEN 'prison' ELSE 'geoles' END,
         current_street = NULL, updated_at = clock_timestamp()
   WHERE name = d.name;
  PERFORM public.interrogatoire_mauvais_traitement_interne('renseignement', v_nom, d.name, v_pays, d.current_city);
  IF v_cle IS NOT NULL THEN
    PERFORM public.interrogatoire_indice_poser_interne('renseignement', v_pays, d.name, v_nom, NULL, v_cle, v_faits);
    v_texte := 'Le détenu ' || d.name || ' a été interrogé par ' || v_nom || ' à la Direction du Renseignement. Il a révélé un fait : '
      || public.interrogatoire_fait_texte_interne(v_faits) || '.';
    FOR v_juge IN SELECT p.name FROM public.personnages_donnees p
                   WHERE p.poste->>'id' = 'juge' AND coalesce(public.poste_pays_de(p.name), p.country) = v_pays AND p.name <> v_nom LOOP
      PERFORM public.mail_systeme_poser_interne('Direction du Renseignement', v_juge, 'Interrogatoire au Renseignement : ' || d.name,
        v_texte || ' Vous pouvez vous en saisir au Bureau des magistrats (« Indices d''interrogatoire »).');
      v_nb := v_nb + 1;
    END LOOP;
    PERFORM public.mail_systeme_poser_interne('Direction du Renseignement', v_nom, 'Interrogatoire au Renseignement : ' || d.name,
      v_texte || ' Ce fait a été transmis aux juges.');
  END IF;
  PERFORM public.mail_systeme_poser_interne('Direction du Renseignement', d.name, 'Fin de l''interrogatoire',
    'Vous avez été conduit en cellule pour la suite de votre peine.');
  RETURN jsonb_build_object('ok', true, 'detenu', d.name, 'probabilite', v_proba, 'jet', v_jet, 'reussi', v_reussi,
    'revelation', v_cle IS NOT NULL, 'juges', v_nb, 'pa_detenu', v_pa, 'pa', v_paie->'pa');
END $function$;

-- ============================================================== JUGES : se saisir d'un indice ou le classer
CREATE OR REPLACE FUNCTION public.interrogatoire_indices_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_j record;
BEGIN
  SELECT * INTO v_j FROM public.juge_moi();
  IF v_j.nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_juge'); END IF;
  RETURN jsonb_build_object('ok', true, 'indices', coalesce((SELECT jsonb_agg(jsonb_build_object(
      'id', i.id, 'lieu', i.lieu, 'detenu', i.detenu, 'interrogateur', i.interrogateur, 'texte', i.texte,
      'statut', i.statut, 'traite_par', i.traite_par, 'affaire', i.affaire_id, 'le', i.cree_le,
      'personnel', i.juge IS NOT NULL) ORDER BY (i.statut = 'en_attente') DESC, i.cree_le DESC)
    FROM (SELECT * FROM public.interrogatoires_indices x
           WHERE x.pays = v_j.pays AND (x.juge = v_j.nom OR x.juge IS NULL)
             AND (x.statut = 'en_attente' OR x.cree_le > now() - interval '14 days')
           ORDER BY x.cree_le DESC LIMIT 40) i), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.interrogatoire_indices_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.interrogatoire_indices_lire() TO authenticated;

CREATE OR REPLACE FUNCTION public.interrogatoire_indice_traiter(p_id bigint, p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_j record; i public.interrogatoires_indices%ROWTYPE; v_aff text; v_jour integer; v_ville text;
BEGIN
  SELECT * INTO v_j FROM public.juge_moi();
  IF v_j.nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_juge'); END IF;
  IF p_decision NOT IN ('saisir', 'classer') THEN RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide'); END IF;
  SELECT * INTO i FROM public.interrogatoires_indices WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR i.pays IS DISTINCT FROM v_j.pays OR (i.juge IS NOT NULL AND i.juge IS DISTINCT FROM v_j.nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'indice_introuvable'); END IF;
  IF i.statut <> 'en_attente' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'indice_deja_traite', 'par', i.traite_par); END IF;
  IF p_decision = 'classer' THEN
    UPDATE public.interrogatoires_indices SET statut = 'classe', traite_par = v_j.nom, traite_le = now() WHERE id = p_id;
    RETURN jsonb_build_object('ok', true, 'statut', 'classe');
  END IF;
  v_ville := coalesce(v_j.ville, 'capitale');
  v_jour := coalesce(public.jour_de_jeu_pays(i.pays), 1);
  v_aff := 'plainte-interrogatoire-' || i.id;
  INSERT INTO public.plaintes_en_cours (id, country, city, data)
  VALUES (v_aff, i.pays, v_ville, jsonb_build_object(
    'id', v_aff, 'auteur', CASE i.lieu WHEN 'goulag' THEN 'Interrogatoire au goulag' WHEN 'qhs' THEN 'Interrogatoire au QHS'
                                  ELSE 'Interrogatoire au Renseignement' END,
    'cible', i.detenu, 'motif', 'Fait révélé en interrogatoire : ' || i.texte, 'categorie_alleguee', NULL,
    'jour', v_jour, 'city', v_ville, 'country', i.pays, 'status', 'saisie', 'origine', 'interrogatoire',
    'indice_interrogatoire', i.id, 'saisine_par', v_j.nom, 'saisine_qualite', 'juge',
    'saisine_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))::text);
  PERFORM public.dossier_acte_consigner(v_aff, i.pays, v_ville, 'juge_saisi', v_j.nom, 'juge', NULL, NULL,
    jsonb_build_object('origine', 'interrogatoire', 'lieu', i.lieu, 'indice', i.id, 'fait', i.faits));
  IF i.trace_cle LIKE 'actions_tracables:%' THEN
    UPDATE public.actions_tracables SET decouvert = true WHERE id = substr(i.trace_cle, length('actions_tracables:') + 1);
  END IF;
  UPDATE public.interrogatoires_indices SET statut = 'saisi', traite_par = v_j.nom, traite_le = now(), affaire_id = v_aff
   WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'statut', 'saisi', 'affaire', v_aff);
END $$;
REVOKE ALL ON FUNCTION public.interrogatoire_indice_traiter(bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.interrogatoire_indice_traiter(bigint, text) TO authenticated;

COMMIT;
