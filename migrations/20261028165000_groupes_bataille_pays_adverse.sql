-- #219 : défaut reproductible dans la porte de combat existante (aucun moteur neuf).
-- La requête parcourt pnj_membres m ; l'alias c n'existe pas dans cette requête.
-- Conserver le prédicat de guerre, corriger seulement la référence au pays adverse.
DO $pays$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_engager()'::regprocedure);
 IF position('-- groupes_bataille_pays_adverse_v1' IN s)>0 THEN RETURN; END IF;
 a:='c.data->>''pays'''; b:='m.pays';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>2
  OR position('FROM public.pnj_membres m' IN s)=0 THEN
  RAISE EXCEPTION 'bataille_pays_adverse_definition_non_examinee'; END IF;
 s:=replace(s,a,b);
 s:=overlay(s placing '-- groupes_bataille_pays_adverse_v1'||chr(10)
  from position('BEGIN' IN s) for 0);
 EXECUTE s;
END $pays$;
