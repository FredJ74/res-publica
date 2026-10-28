-- Projection de capacité, sans nouvelle autorité : les mêmes gardes que les verbes.
DO $capacite$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.pnj_membres_ici(text,text,text,text,text)'::regprocedure);
 a:='''porte'', pe.porte, ''mien'', true)';
 b:='''porte'', pe.porte, ''mien'', true,'||chr(10)
  ||'             ''mouvement_individuel'', public.pnj_axe_position_refus(ARRAY[m.id]) IS NULL'
  ||chr(10)||'               AND public.pnj_mouvement_individuel_refus(ARRAY[m.id]) IS NULL,'
  ||chr(10)||'             ''peut_administrer'', public.pnj_peut_administrer(v_moi,m.id))';
 IF position(b IN s)>0 THEN RETURN; END IF;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN
  RAISE EXCEPTION 'presence_pnj_capacite_definition_non_examinee'; END IF;
 EXECUTE replace(s,a,b);
END $capacite$;
