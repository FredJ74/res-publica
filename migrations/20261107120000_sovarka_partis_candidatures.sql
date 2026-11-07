-- Pouvoir en Sovarka, étape 2 (Fred, 07/11/2026, GAME-DESIGN-NOVOMIRSK.md) :
-- les partis de Sovarka sont les organisations de type « politique » du pays ;
-- tout candidat à la présidence ou à une mairie de Sovarka doit d'abord adhérer
-- à un parti. Les députés du Soviet Suprême ne sont pas élus : leurs sièges sont
-- répartis entre les partis (étape 5), donc pas de candidature de député en Sovarka.

-- Parti d'un personnage en Sovarka : identifiant de l'organisation politique dont il
-- est chef ou membre, NULL sinon. Lecture seule, réutilisée par les étapes suivantes.
CREATE OR REPLACE FUNCTION public.sovarka_parti_de(p_nom text)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT o.id
    FROM public.organisations o
   WHERE o.data::jsonb ->> 'type' = 'politique'
     AND coalesce(o.data::jsonb ->> 'country', o.country_origine) = 'soviet'
     AND (o.data::jsonb ->> 'chef' = p_nom
          OR EXISTS (SELECT 1
                       FROM jsonb_array_elements(CASE WHEN jsonb_typeof(o.data::jsonb -> 'membres') = 'array'
                                                      THEN o.data::jsonb -> 'membres' ELSE '[]'::jsonb END) m
                      WHERE m ->> 'nom' = p_nom))
   ORDER BY o.created_at
   LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.sovarka_parti_de(text) FROM PUBLIC, anon, authenticated;

DO $patch$
DECLARE
  v_fn text; v_var text; v_source text;
  v_ancre text := $a$    RETURN jsonb_build_object('ok', false, 'raison', 'non_domicilie');
  END IF;
$a$;
  v_garde text;
BEGIN
  FOR v_fn, v_var IN VALUES
    ('public.candidature_deposer(text,text,numeric,jsonb)', 'v_moi'),
    ('public.candidature_publier(text,text,numeric,text,text)', 'v_nom')
  LOOP
    SELECT pg_get_functiondef(v_fn::regprocedure) INTO v_source;
    IF v_source IS NULL OR strpos(v_source, v_ancre) = 0 OR strpos(v_source, 'parti_requis') > 0
    THEN RAISE EXCEPTION 'version_inattendue %', v_fn; END IF;
    v_garde := v_ancre || format($g$  -- Sovarka (Fred, 07/11/2026) : candidat membre d'un parti ; députés désignés par les partis.
  IF v_pays = 'soviet' THEN
    IF p_poste = 'depute' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'depute_designe_par_parti');
    END IF;
    IF p_poste IN ('president', 'maire') AND public.sovarka_parti_de(%s) IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'parti_requis');
    END IF;
  END IF;
$g$, v_var);
    v_source := replace(v_source, v_ancre, v_garde);
    EXECUTE v_source;
  END LOOP;
  IF (SELECT count(*) FROM pg_proc WHERE proname IN ('candidature_deposer','candidature_publier')
        AND pg_get_functiondef(oid) LIKE '%parti_requis%') <> 2
  THEN RAISE EXCEPTION 'garde_parti_absente'; END IF;
END $patch$;
