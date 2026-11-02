-- BLOCUS SYNDICAL : LE COMMISSAIRE INTERVIENT DEPUIS SA PROPRE INTERFACE (décision de Fred,
-- 02/11/2026, GAME-DESIGN-BLOCUS.md, décision 8). Plus d'obligation d'être dans son bureau : le
-- poste de commissaire de la ville suffit. Règle aussi le cas du commissariat lui-même bloqué.
DO $blocus$
DECLARE f text; ancien text;
BEGIN
  f := pg_get_functiondef('public.blocus_syndical_intervenir(text,text,text)'::regprocedure);
  ancien := E'  IF p.current_city IS DISTINCT FROM p_ville\n'
    || E'     OR p.current_building NOT IN (''commissariat'', ''commissariat-local'')\n'
    || E'     OR p.current_room IS DISTINCT FROM ''bureau_commissaire'' THEN\n'
    || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''depuis_bureau_commissaire''); END IF;\n';
  IF position('depuis_bureau_commissaire' IN f) = 0 THEN RETURN; END IF;
  IF (length(f) - length(replace(f, ancien, ''))) / length(ancien) <> 1 THEN
    RAISE EXCEPTION 'blocus_intervenir_definition_non_examinee'; END IF;
  EXECUTE replace(f, ancien, '');
END $blocus$;
