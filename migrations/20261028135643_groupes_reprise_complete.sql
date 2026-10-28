-- Renforce la prise commune préparée #216 : aucune liste tronquée silencieusement.
-- Après #217 (autorité administrative) et le complément de séparation atomique.
DO $prise$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.pnj_prendre(text[])'::regprocedure);
 a:='  FOR r IN SELECT id FROM public.pnj_membres';
 b:=$ajout$  -- groupes_prise_integrale_v1
  PERFORM name FROM public.personnages_donnees WHERE name=v_moi FOR UPDATE;
  PERFORM id FROM public.pnj_membres WHERE id=ANY(p_ids) ORDER BY id FOR UPDATE;
  IF coalesce(cardinality(p_ids),0)=0 OR EXISTS(SELECT 1 FROM unnest(p_ids) x WHERE x IS NULL OR x='')
    OR (SELECT count(DISTINCT x) FROM unnest(p_ids) x)<>cardinality(p_ids)
    OR (SELECT count(*) FROM public.pnj_membres WHERE id=ANY(p_ids) AND statut='actif')<>cardinality(p_ids) THEN
   RETURN jsonb_build_object('ok',false,'raison','identifiants_invalides'); END IF;
$ajout$||a;
 IF position('-- groupes_prise_integrale_v1' IN s)>0 THEN RETURN; END IF;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>2
  OR position('reprise_pnj_depose_refusee' IN s)=0
  OR position('IF NOT public.pnj_peut_administrer(v_moi, r.id) THEN' IN s)=0 THEN
  RAISE EXCEPTION 'prise_commune_definition_non_examinee'; END IF;
 -- Seule la première boucle reçoit la garde ; la seconde suit la séparation commune.
 s:=overlay(s placing b from position(a IN s) for length(a));
 EXECUTE s;
END $prise$;
