-- Banques locales = guichets de la Banque Nationale (Claude, 01/11/2026).
-- Décision de Fred, 01/11/2026, après l'audit des bâtiments de PSM et Montrouge : la Banque locale de
-- Port-Sainte-Marie et la Banque cheminote de Montrouge (gabarit `banque-locale`) offrent les mêmes
-- procédures que la Banque Nationale (compte, placements, prêt, virements ponctuels et automatiques) ;
-- seule la Banque privée Helvetia garde un fonctionnement unique.
--
-- Trois gardes de présence acceptaient seulement `banque-nationale`. Patch en place (doctrine
-- « patcher, jamais retaper ») : la garde accepte les deux guichets. Le prêt reste inscrit sur
-- `banque-nationale` (même valeur qu'aujourd'hui pour tout prêt contracté au guichet), quel que soit
-- le guichet : c'est un prêt de la Banque Nationale. Indépendante de l'écran (l'ancien écran ne
-- propose ces ordres qu'à la Banque Nationale) ; aucune donnée de joueur touchée.
BEGIN;

DO $mig$
DECLARE r record; v_def text; v_new text; n int := 0;
BEGIN
  FOR r IN SELECT p.oid FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
           WHERE s.nspname='public' AND p.proname IN ('banque_virement','banque_virement_automatique_creer') LOOP
    v_def := pg_get_functiondef(r.oid);
    v_new := replace(v_def,
      $ancien$IF v_bat IS DISTINCT FROM 'banque-nationale' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;$ancien$,
      $nouveau$IF v_bat IS NULL OR v_bat NOT IN ('banque-nationale','banque-locale') THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;$nouveau$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch virement non applique (oid %)', r.oid; END IF;
    EXECUTE v_new; n := n + 1;
  END LOOP;
  IF n <> 2 THEN RAISE EXCEPTION 'virements : % fonction(s) patchee(s), 2 attendues', n; END IF;

  v_def := pg_get_functiondef('public.pret_national_contracter_versionne(numeric,integer,text,text,uuid)'::regprocedure);
  v_new := replace(v_def,
    $ancien$OR p.current_building IS DISTINCT FROM 'banque-nationale' OR p_building_id IS DISTINCT FROM p.current_building$ancien$,
    $nouveau$OR p.current_building IS NULL OR p.current_building NOT IN ('banque-nationale','banque-locale') OR p_building_id IS DISTINCT FROM p.current_building$nouveau$);
  v_new := replace(v_new,
    $ancien$r:=public.pret_national_creer_interne(moi,p_montant,p_duree_jours,p_type_pret,p.current_building,p_requete::text);$ancien$,
    $nouveau$r:=public.pret_national_creer_interne(moi,p_montant,p_duree_jours,p_type_pret,'banque-nationale',p_requete::text);$nouveau$);
  IF (length(v_new) - length(replace(v_new,'''banque-locale''',''))) / length('''banque-locale''') <> 1
     OR position('p_type_pret,''banque-nationale'',p_requete::text)' IN v_new) = 0 THEN
    RAISE EXCEPTION 'patch pret non applique';
  END IF;
  EXECUTE v_new;
END $mig$;

DO $verification$
DECLARE r record;
BEGIN
  FOR r IN SELECT p.proname, pg_get_functiondef(p.oid) d FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
           WHERE s.nspname='public' AND p.proname IN ('banque_virement','banque_virement_automatique_creer','pret_national_contracter_versionne') LOOP
    IF position('''banque-locale''' IN r.d) = 0 THEN RAISE EXCEPTION 'guichet local absent de %', r.proname; END IF;
  END LOOP;
END $verification$;

COMMIT;
