-- Portraits des deux équipes de renseignement de Sovarka (planches de Fred, 13/11/2026, 23 h 24) :
-- chaque agent dans les quatre tenues de couverture (Sovarka, El Estado, Républia, Al Khalija).
-- Fichiers : images/Sovarka/agents/agent-<equipe>-<role>-<pays>.webp. La Républia garde ses portraits.
CREATE OR REPLACE FUNCTION public.agent_portrait_chemin(p_equipe text, p_role text, p_pays text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_equipe IN ('soviet-min_def', 'soviet-min_int')
                   AND p_role IN ('coordinateur', 'conseiller', 'garde', 'traducteur')
                   AND coalesce(p_pays, 'soviet') IN ('soviet', 'narco', 'republic', 'khalija')
              THEN 'images/Sovarka/agents/agent-' || p_equipe || '-' || p_role || '-' || coalesce(p_pays, 'soviet') || '.webp'
              ELSE public.agent_portrait_chemin(p_role, p_pays) END;
$$;

DO $m$
DECLARE f text; n text;
BEGIN
  FOREACH n IN ARRAY ARRAY['public.agents_couverture_ici()', 'public.agents_couverture_de_mon_groupe()', 'public.cellule_renseignement_mes_cellules()'] LOOP
    f := pg_get_functiondef(n::regprocedure);
    CONTINUE WHEN position('agent_portrait_chemin(ag.equipe' IN f) > 0;
    IF position('agent_portrait_chemin(ag.role, ag.pays_couverture)' IN f) = 0 THEN RAISE EXCEPTION 'portrait introuvable dans %', n; END IF;
    EXECUTE replace(f, 'agent_portrait_chemin(ag.role, ag.pays_couverture)', 'agent_portrait_chemin(ag.equipe, ag.role, ag.pays_couverture)');
  END LOOP;
  f := pg_get_functiondef('public.renseignement_agents_disponibles()'::regprocedure);
  IF position('agent_portrait_chemin(i.equipe' IN f) = 0 THEN
    IF position('agent_portrait_chemin(i.role, v_pays)' IN f) = 0 THEN RAISE EXCEPTION 'portrait introuvable (disponibles)'; END IF;
    EXECUTE replace(f, 'agent_portrait_chemin(i.role, v_pays)', 'agent_portrait_chemin(i.equipe, i.role, v_pays)');
  END IF;
  IF public.agent_portrait_chemin('soviet-min_int', 'garde', 'republic') <> 'images/Sovarka/agents/agent-soviet-min_int-garde-republic.webp'
     OR public.agent_portrait_chemin('republic-min_def', 'garde', 'republic') <> public.agent_portrait_chemin('garde', 'republic') THEN
    RAISE EXCEPTION 'chemins de portraits incorrects'; END IF;
END $m$;
