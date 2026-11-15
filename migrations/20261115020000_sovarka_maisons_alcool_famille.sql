-- SOVARKA : MAISONS D'HOSPITALITÉ — la vodka demandée accepte tout alcool, l'alcool demandé accepte la vodka
-- (demande de Fred, 15/11/2026 : « rattacher aux œufs du kolkhoze et à l'alcool »).
-- Relevé en production (15/11) : les services « œufs » et « vodka » de Stepan et Dolgor sont bien tirés depuis
-- 20261110123000 (sovarka_maison_service_interne les accepte) ; les œufs du kolkhoze arrivent sous la clé `oeufs`,
-- celle du service. Le trou était au moment de rendre le service : sovarka_maison_agir cherchait la clé exacte,
-- donc « 1 bouteille de vodka » refusait l'alcool de l'entrepôt d'État (clé `alcool`, la seule bouteille présente
-- dans les inventaires au 15/11) et « 1 alcool » des maisonnettes de Krasnov refusait vodka, slivovitz et samogon.
-- Désormais ces deux services acceptent la même famille de bouteilles que « trinquer ». Patch en place, ancrage vérifié.
BEGIN;

CREATE OR REPLACE FUNCTION public.sovarka_maison_service_cles_interne(p_cle text)
RETURNS text[] LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_cle IN ('vodka', 'alcool') THEN ARRAY['vodka', 'slivovitz', 'samogon', 'alcool'] ELSE ARRAY[p_cle] END;
$$;
REVOKE ALL ON FUNCTION public.sovarka_maison_service_cles_interne(text) FROM PUBLIC, anon, authenticated;

DO $alcool$
DECLARE d text; avant text; apres text;
BEGIN
  d := pg_get_functiondef('public.sovarka_maison_agir(text, text)'::regprocedure);
  IF position('sovarka_maison_service_cles_interne' IN d) = 0 THEN
    avant := 'ARRAY[s->>''cle'']';
    apres := 'public.sovarka_maison_service_cles_interne(s->>''cle'')';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'sovarka_maison_agir : ancrage service introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
  IF position('sovarka_maison_service_cles_interne' IN pg_get_functiondef('public.sovarka_maison_agir(text, text)'::regprocedure)) = 0
  THEN RAISE EXCEPTION 'sovarka_maison_agir : patch absent'; END IF;
END $alcool$;

COMMIT;
