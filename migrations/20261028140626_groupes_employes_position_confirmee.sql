-- Projection commune existante : rendre la position effective avec l'employé.
-- Indispensable à l'affichage après dépose, sans reconstruire une position locale.
DO $projection$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.employe_mes_employes()'::regprocedure);
 a:='''porte'', (m.leader_pj = v_moi),';
 b:=a||chr(10)||'             ''position'', (SELECT to_jsonb(p) FROM public.pnj_position_effective(m.id) p),';
 IF position(b IN s)>0 THEN RETURN; END IF;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN
  RAISE EXCEPTION 'projection_employes_definition_non_examinee'; END IF;
 EXECUTE replace(s,a,b);
END $projection$;
