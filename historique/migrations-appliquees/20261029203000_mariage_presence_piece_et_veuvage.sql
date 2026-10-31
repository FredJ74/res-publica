-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029184631.
-- Archivage documentaire seulement ; ne pas rejouer.
-- Correctif complémentaire à la PR #241 (29/10/2026).
-- Même ville avec current_building/current_room NULL n'est PAS la même pièce :
-- deux PJ situés dans des rues différentes ne peuvent pas officialiser leur mariage.
-- Le veuvage doit examiner la succession du conjoint décédé, pas celle du survivant.
DO $mig$
DECLARE v_def text; v_old text :=
  '  IF p.current_city IS DISTINCT FROM c.current_city OR p.current_building IS DISTINCT FROM c.current_building';
BEGIN
  v_def := pg_get_functiondef('public.mariage_officialiser(uuid,text)'::regprocedure);
  IF strpos(v_def,'IF p.current_building IS NULL OR c.current_building IS NULL') > 0 THEN RETURN; END IF;
  IF (length(v_def)-length(replace(v_def,v_old,'')))/length(v_old) <> 1
    THEN RAISE EXCEPTION 'migration_presence_contrat_non_unique'; END IF;
  EXECUTE replace(v_def,v_old,
    '  IF p.current_building IS NULL OR c.current_building IS NULL OR p.current_room IS NULL OR c.current_room IS NULL THEN'||E'\n'||
    '    RETURN jsonb_build_object(''ok'',false,''raison'',''conjoint_absent''); END IF;'||E'\n'||v_old);
END $mig$;

DO $mig$
DECLARE v_def text; v_old text := 'SELECT 1 FROM public.successions WHERE defunt = moi';
BEGIN
  v_def := pg_get_functiondef('public.mariage_dissoudre(text)'::regprocedure);
  IF strpos(v_def,'WHERE defunt = CASE WHEN m.conjoint1 = moi')>0 THEN RETURN; END IF;
  IF (length(v_def)-length(replace(v_def,v_old,'')))/length(v_old) <> 1
    THEN RAISE EXCEPTION 'migration_veuvage_contrat_non_unique'; END IF;
  EXECUTE replace(v_def,v_old,
    'SELECT 1 FROM public.successions WHERE defunt = CASE WHEN m.conjoint1 = moi THEN m.conjoint2 ELSE m.conjoint1 END');
END $mig$;
