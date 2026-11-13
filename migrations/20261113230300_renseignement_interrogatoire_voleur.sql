-- Voleur d'archives arrêté à Novomirsk : la salle d'interrogatoire (Fred, 13/11/2026, 22 h 10 – 22 h 11 ;
-- GAME-DESIGN-NOVOMIRSK.md). Partie 4/4.
--  - Pris en flagrant délit dans la salle des écoutes de la Direction du Renseignement, le voleur est
--    détenu d'abord en salle d'interrogatoire (même peine, même détention, seul le lieu change).
--  - Garde-fous : au maximum la durée de sa peine (la libération normale l'en sort), temps compté dans
--    la peine ; UN seul interrogatoire, après lequel il part aussitôt en cellule ; courrier et forum
--    comme en cellule (rien de bloqué en plus).
--  - « Interroger un détenu » vise désormais un détenu présent : ministre de la Défense, et en Sovarka
--    aussi ministre de la Sécurité du Peuple. Même coût (2 PA), même jet (75 %), même effet (+5 INF).
--    Ce qui se dit pendant l'interrogatoire se joue entre les joueurs (Constitution : on ne code pas
--    les interactions humaines entre PJ).

CREATE OR REPLACE FUNCTION public.renseignement_interrogatoire_placer_interne(p_nom text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  UPDATE public.personnages_donnees
     SET est_emprisonne = est_emprisonne || jsonb_build_object('interrogatoire', jsonb_build_object(
           'batiment', 'siege-renseignement', 'piece', 'salle_interrogatoire_renseignement')),
         current_building = 'siege-renseignement', current_room = 'salle_interrogatoire_renseignement',
         current_street = NULL, updated_at = clock_timestamp()
   WHERE name = p_nom AND jsonb_typeof(est_emprisonne) = 'object';
$$;

-- Ministre habilité à interroger, présent dans la salle ; rend NULL si tout va bien.
CREATE OR REPLACE FUNCTION public.renseignement_interrogateur_refus_interne(p_nom text, p_poste text, p_pays text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF p_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT (p_poste = 'min_def' OR (p_pays = 'soviet' AND p_poste = 'min_int')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_nom AND country = p_pays
                   AND current_building = 'siege-renseignement' AND current_room = 'salle_interrogatoire_renseignement') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.renseignement_detenus_interrogatoire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_nom text; v_poste text; v_pays text; v jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays FROM public.acteur_poste_courant() a;
  v := public.renseignement_interrogateur_refus_interne(v_nom, v_poste, v_pays);
  IF v IS NOT NULL THEN RETURN v; END IF;
  RETURN jsonb_build_object('ok', true, 'detenus', coalesce((SELECT jsonb_agg(jsonb_build_object(
      'nom', d.name, 'raison', d.est_emprisonne->>'raison', 'jour_fin', d.est_emprisonne->'jourFin') ORDER BY d.name)
    FROM public.personnages_donnees d
   WHERE d.country = v_pays AND d.current_building = 'siege-renseignement'
     AND d.current_room = 'salle_interrogatoire_renseignement'
     AND jsonb_typeof(d.est_emprisonne) = 'object' AND d.est_emprisonne ? 'interrogatoire'), '[]'::jsonb));
END $$;

CREATE OR REPLACE FUNCTION public.renseignement_interroger(p_detenu text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_nom text; v_poste text; v_pays text; v jsonb; d record; v_paie jsonb; v_jet integer; v_inf jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays FROM public.acteur_poste_courant() a;
  v := public.renseignement_interrogateur_refus_interne(v_nom, v_poste, v_pays);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT name, country, current_city, est_emprisonne INTO d FROM public.personnages_donnees
   WHERE name = btrim(p_detenu) FOR UPDATE;
  IF d.name IS NULL OR jsonb_typeof(d.est_emprisonne) IS DISTINCT FROM 'object' OR NOT (d.est_emprisonne ? 'interrogatoire')
     OR d.country IS DISTINCT FROM v_pays OR d.name = v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_interrogatoire'); END IF;
  v_paie := public.payer_ordre(v_nom, 'interroger_renseignement', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet <= 75 THEN
    UPDATE public.personnages_donnees
       SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{inf}',
             to_jsonb(least(100, greatest(0, coalesce((resources->>'inf')::numeric, 0) + 5))))
     WHERE name = v_nom RETURNING resources->'inf' INTO v_inf;
  END IF;
  -- Un seul interrogatoire : départ immédiat en cellule, la peine continue.
  UPDATE public.personnages_donnees
     SET est_emprisonne = est_emprisonne - 'interrogatoire',
         current_building = CASE WHEN current_city = 'capitale' THEN 'commissariat' ELSE 'commissariat-local' END,
         current_room = CASE WHEN current_city = 'capitale' THEN 'prison' ELSE 'geoles' END,
         current_street = NULL, updated_at = clock_timestamp()
   WHERE name = d.name;
  PERFORM public.mail_systeme_poser_interne('Direction du Renseignement', d.name, 'Fin de l''interrogatoire',
    'Vous avez été interrogé par ' || v_nom || ' en salle d''interrogatoire, puis conduit en cellule pour la suite de votre peine.');
  RETURN jsonb_build_object('ok', true, 'detenu', d.name, 'reussi', v_jet <= 75, 'jet', v_jet, 'inf', v_inf, 'pa', v_paie->'pa');
END $$;

REVOKE ALL ON FUNCTION public.renseignement_interrogatoire_placer_interne(text),
  public.renseignement_interrogateur_refus_interne(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.renseignement_detenus_interrogatoire(), public.renseignement_interroger(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.renseignement_detenus_interrogatoire(), public.renseignement_interroger(text) TO authenticated;

-- Le vol raté à Novomirsk conduit en salle d'interrogatoire (patch en place).
DO $m$
DECLARE f text := pg_get_functiondef('public.sovarka_ecoute_archives_voler(text)'::regprocedure);
  ancien text := E'''Surpris en train de fouiller les archives d''''écoute, après une bagarre avec l''''opérateur''));';
  ajout text := E'\n    IF c = ''novomirsk'' AND coalesce((v->''arrestation''->>''ok'')::boolean, false) THEN /* interrogatoire_novomirsk */\n'
             || E'      PERFORM public.renseignement_interrogatoire_placer_interne(a);\n'
             || E'      v := v || jsonb_build_object(''interrogatoire'', true);\n    END IF;';
BEGIN
  IF position('interrogatoire_novomirsk' IN f) > 0 THEN RETURN; END IF;
  IF position(ancien IN f) = 0 THEN RAISE EXCEPTION 'vol d''archives : fragment introuvable'; END IF;
  EXECUTE replace(f, ancien, ancien || ajout);
END $m$;

DO $preuve$
BEGIN
  IF position('interrogatoire_novomirsk' IN pg_get_functiondef('public.sovarka_ecoute_archives_voler(text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'vol non raccordé à l''interrogatoire'; END IF;
END $preuve$;
