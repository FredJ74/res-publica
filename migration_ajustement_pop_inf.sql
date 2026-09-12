-- =====================================================================
-- AJUSTEMENT ATOMIQUE DE LA POP / INF D'UN AUTRE PERSONNAGE (12 septembre 2026)
-- =====================================================================
-- sbAjusterPopJoueur et sbAjusterPopularite (supabase.js) lisaient resources puis reecrivaient le
-- blob ENTIER ({inf, pop, dis}) depuis une valeur perimee : la cible d'une rumeur ou d'un lobbying
-- perdait les gains d'INF ou de DIS obtenus entre la lecture et l'ecriture. Meme remede que pour
-- les tracts : un seul UPDATE, sous le verrou de ligne, qui ne touche que les cles demandees.
-- p_inf NULL = l'influence n'est pas modifiee.
-- =====================================================================
CREATE OR REPLACE FUNCTION public.personnage_ajuster_pop_inf(p_cible text, p_pop integer, p_inf integer DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_res jsonb;
BEGIN
  IF COALESCE(btrim(p_cible), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;
  IF COALESCE(abs(p_pop), 0) > 100 OR COALESCE(abs(p_inf), 0) > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_invalide');
  END IF;
  UPDATE public.personnages
     SET resources = (
           CASE WHEN p_inf IS NULL THEN r.base
                ELSE jsonb_set(r.base, '{inf}', to_jsonb(GREATEST(0, LEAST(100,
                  COALESCE(CASE WHEN jsonb_typeof(r.base -> 'inf') = 'number' THEN (r.base ->> 'inf')::numeric END, 0) + p_inf))))
           END)
    FROM (SELECT jsonb_set(
            CASE WHEN jsonb_typeof(pp.resources) = 'object' THEN pp.resources ELSE '{}'::jsonb END,
            '{pop}', to_jsonb(GREATEST(0, LEAST(100,
              COALESCE(CASE WHEN jsonb_typeof(pp.resources -> 'pop') = 'number' THEN (pp.resources ->> 'pop')::numeric END, 50)
              + COALESCE(p_pop, 0))))) AS base
            FROM public.personnages pp WHERE pp.name = p_cible) r
   WHERE public.personnages.name = p_cible
   RETURNING public.personnages.resources INTO v_res;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;
  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf');
END;
$$;
REVOKE ALL ON FUNCTION public.personnage_ajuster_pop_inf(text, integer, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.personnage_ajuster_pop_inf(text, integer, integer) TO anon, authenticated, service_role;
