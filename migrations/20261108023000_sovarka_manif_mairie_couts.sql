-- Suite de 20261108013000 (08/11/2026) :
--  * la manifestation de soutien part de la mairie : le chef de parti l'organise depuis « Mon parti »
--    (salle des partis), avec au moins 10 manifestants de son groupe présents dans la même mairie
--    (l'écran de Sovarka n'a pas d'ordre de rue) ;
--  * coûts déclarés des ordres d'écran ajoutés au palais et à la caserne de Novomirsk.
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT x.fn, x.pa, x.cost FROM (VALUES ('sovarka_lois_examen', 0, 0), ('sovarka_seance', 0, 0), ('sovarka_sondages', 0, 0),
  ('sovarka_conscription', 0, 0), ('sovarka_conscrit_presenter', 1, 0)) AS x(fn, pa, cost)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = x.fn);

DO $patch$
DECLARE r record; v_def text; v_n int;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ($a$      ELSIF p.current_building IS NOT NULL OR p.current_city IS NULL THEN v := jsonb_build_object('ok', false, 'raison', 'dans_la_rue');$a$,
     $b$      ELSIF p.current_building IS DISTINCT FROM (CASE WHEN p.current_city = 'capitale' THEN 'mairie-capitale' ELSE 'mairie' END) THEN
        v := jsonb_build_object('ok', false, 'raison', 'a_la_mairie');$b$),
    ($a$AND x.country = 'soviet' AND x.current_city = p.current_city AND x.current_building IS NULL;$a$,
     $b$AND x.country = 'soviet' AND x.current_city = p.current_city AND x.current_building IS NOT DISTINCT FROM p.current_building;$b$)
  ) AS t(avant, apres) LOOP
    v_def := pg_get_functiondef('public.sovarka_pouvoir_commande(uuid,text,jsonb)'::regprocedure);
    v_n := (length(v_def) - length(replace(v_def, r.avant, ''))) / length(r.avant);
    IF v_n <> 1 THEN RAISE EXCEPTION 'fragment non unique (%)', v_n; END IF;
    EXECUTE replace(v_def, r.avant, r.apres);
  END LOOP;
END $patch$;
