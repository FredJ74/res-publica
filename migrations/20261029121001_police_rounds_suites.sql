-- #219 : scission technique (limite MCP 12 500 caractères).
-- Appliquer ces deux fichiers consécutifs dans la même transaction.
DO $gel$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.groupe_confrontation_refus_interne(text)'::regprocedure);
 IF position('-- confrontation_groupes_figes_v1' IN s)>0 THEN RETURN;END IF;
 a:='  SELECT ''combat_en_cours'',1 FROM public.groupe_participants_interne(p_nom) g';
 b:='  -- confrontation_groupes_figes_v1'||chr(10)
 ||'  SELECT ''interception_en_cours'',0 FROM public.groupe_participants_interne(p_nom) g'
 ||' JOIN public.police_interceptions i ON i.expires_at>now() AND (i.combattants_victimes ? g.cle OR i.combattants_forces ? g.cle)'
 ||chr(10)||'  UNION ALL'||chr(10)||a;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'rounds_gel_groupes_non_examine';END IF;
 EXECUTE replace(s,a,b);
END $gel$;
