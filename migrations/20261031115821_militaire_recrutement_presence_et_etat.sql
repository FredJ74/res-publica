-- #219 : conserver le camp institutionnel, vérifier le lieu physique réel.
-- Moteur de recrutement et de rounds existant, aucun nouveau dégât/barème.
DO $recrutement$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_recruter(bigint,text,text,text,text)'::regprocedure);
 IF position('-- recrutement_presence_et_etat_v1' IN s)>0 THEN RETURN;END IF;
 a:='     AND pd.country = v_pays';
 b:='     AND sm.pays = v_pays'
 ||chr(10)||'     AND pd.country = (SELECT b.pays FROM public.batailles b WHERE b.id=p_bataille_id)'
 ||chr(10)||'     AND coalesce(pd.hp,100)>0 AND (pd.est_emprisonne IS NULL OR pd.est_emprisonne=''null''::jsonb)'
 ||chr(10)||'     AND coalesce(pd.hospitalisation->>''dateFinParis'','''')<=(statement_timestamp() AT TIME ZONE ''Europe/Paris'')::date::text'
 ||chr(10)||'     AND NOT CASE WHEN coalesce(pd.hospitalisation->>''jourFin'','''')~''^[0-9]+$'' THEN (pd.hospitalisation->>''jourFin'')::numeric>coalesce(pd.day,1) ELSE false END'
 ||chr(10)||'     AND NOT EXISTS(SELECT 1 FROM public.police_interceptions i WHERE i.personnage=pd.name AND i.expires_at>now())'
 ||chr(10)||'     AND NOT EXISTS(SELECT 1 FROM public.batailles_engagements e JOIN public.batailles autre ON autre.id=e.bataille_id WHERE e.personnage=pd.name AND e.sorti_round IS NULL AND autre.statut=''en_cours'' AND autre.id<>p_bataille_id)';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'recrutement_pj_definition_non_examinee';END IF;
 s:=replace(s,a,b);
 a:='     AND m.pays = v_pays';
 b:=a||chr(10)||'     AND pe.pays = (SELECT b.pays FROM public.batailles b WHERE b.id=p_bataille_id)'
 ||chr(10)||'     AND NOT EXISTS(SELECT 1 FROM public.batailles_engagements e JOIN public.batailles autre ON autre.id=e.bataille_id WHERE e.compagnie_id=sm.compagnie_id AND e.section_id=sm.section_id AND e.matricule=sm.matricule AND e.sorti_round IS NULL AND autre.statut=''en_cours'' AND autre.id<>p_bataille_id)';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'recrutement_pnj_definition_non_examinee';END IF;
 s:=replace(s,a,b);
 s:=overlay(s placing E'BEGIN\n -- recrutement_presence_et_etat_v1\n PERFORM pg_advisory_xact_lock(hashtextextended(''groupe_pj:graphe'',0));' FROM position('BEGIN' IN s) FOR 5);
 EXECUTE s;
END $recrutement$;
