-- #219/#230 : pas de résurrection ni perte de dégâts au passage du miroir.
-- Une seule transaction DO ; comparaison des corps vivants toujours préalable.
DO $socle$
DECLARE s text;a text;b text;f text;service record;liste jsonb;agents text;
BEGIN
 s:=pg_get_functiondef('public.pnj_groupes_projeter_institutions_interne(text[])'::regprocedure);
 IF position('-- projections_etats_pnj_v2' IN s)=0 THEN
  -- Reprendre UNE FOIS les PA historiques. Après bascule, seul le socle fait
  -- autorité. Un rejeu ne réimporte jamais une ancienne copie d'effectifs.
  FOR service IN SELECT * FROM public.batiments_etat WHERE building_id IN ('commissariat','commissariat-local','port-sainte-marie','port-novomirsk','port-puerto-dorado','port-al-mina') ORDER BY id FOR UPDATE LOOP
   agents:=CASE WHEN service.building_id IN ('commissariat','commissariat-local') THEN 'policiers' ELSE 'douaniers' END;
   liste:=public.batiment_etat_lire(service.data)->CASE WHEN agents='policiers' THEN 'effectifsPolice' ELSE 'effectifsDouane' END->agents;
   IF liste IS NULL THEN CONTINUE;END IF;
   IF jsonb_typeof(liste)<>'array' THEN RAISE EXCEPTION 'effectifs_historiques_invalides: %',service.id;END IF;
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(liste) x WHERE x ? 'pa' AND
    NOT CASE WHEN coalesce(x->>'pa','')~'^[0-9]+$' THEN (x->>'pa')::numeric BETWEEN 0 AND public.pnj_pa_max() ELSE false END) THEN
    RAISE EXCEPTION 'pa_historiques_a_auditer: %',service.id;END IF;
   UPDATE public.pnj_membres m SET pa=(x->>'pa')::integer
   FROM jsonb_array_elements(liste) x WHERE x ? 'pa' AND m.statut='actif'
   AND m.id=CASE WHEN agents='policiers' THEN public.police_pnj_id(service.country,service.city,x->>'matricule') ELSE public.douane_pnj_id(service.country,service.city,x->>'matricule') END;
  END LOOP;
  a:='CASE WHEN m.id IS NULL OR m.statut<>''actif'' THEN d.objet';b:='CASE WHEN m.id IS NULL THEN d.objet';
  IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'projection_etat_definition_non_examinee';END IF;
  s:=replace(s,a,b);
  a:='jsonb_build_object(''buildingId'',pe.building_id';
  b:='jsonb_build_object(''pa'',CASE WHEN m.statut=''actif'' THEN m.pa ELSE 0 END,''statut'',m.statut,''buildingId'',pe.building_id';
  IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'projection_pa_definition_non_examinee';END IF;
  s:=replace(s,a,b);
  a:='LEFT JOIN LATERAL public.pnj_position_effective(m.id) pe ON true;';
  b:='LEFT JOIN LATERAL public.pnj_position_effective(m.id) pe ON true WHERE m.id IS NULL OR m.statut<>''mort'';';
  IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'projection_morts_definition_non_examinee';END IF;
  s:=replace(s,a,b);s:=replace(s,'BEGIN',E'BEGIN\n -- projections_etats_pnj_v2');EXECUTE s;
 END IF;
 FOREACH f IN ARRAY ARRAY['pnj_miroir_police','pnj_miroir_douane'] LOOP
  s:=pg_get_functiondef(('public.'||f||'(text,text,text)')::regprocedure);
  IF position('-- miroir_etats_canoniques_v2' IN s)>0 THEN CONTINUE;END IF;
  a:='statut = ''actif'',';
  b:='statut = CASE WHEN pnj_membres.statut IN (''mort'',''detenu'') THEN pnj_membres.statut ELSE ''actif'' END,';
  IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'miroir_statut_definition_non_examinee: %',f;END IF;
  s:=replace(s,a,b);s:=replace(s,'BEGIN',E'BEGIN\n -- miroir_etats_canoniques_v2');EXECUTE s;
 END LOOP;
 -- Le combat policier préexistant doit écrire le socle avant de réécrire son
 -- ancien affichage. Ni deuxième coup ni nouvelle dépense de PA.
 s:=pg_get_functiondef('public.police_combat_resoudre(text,text,text,text,integer)'::regprocedure);
 IF position('-- combat_police_pa_socle_v2' IN s)>0 THEN RETURN;END IF;
 a:=' SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom FOR UPDATE;';
 b:=' PERFORM pg_advisory_xact_lock(hashtextextended(''groupe_pj:graphe'',0));'||chr(10)||a;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'combat_verrou_definition_non_examinee';END IF;
 s:=replace(s,a,b);
 a:=' -- Réécriture par matricule ; les policiers absents ne sont jamais touchés.';
 b:=' -- combat_police_pa_socle_v2'||chr(10)
 ||' FOR v_agent IN SELECT value FROM jsonb_array_elements(v_actifs) LOOP'
 ||' IF NOT v_agent ? ''pnj_prive_id'' THEN'
 ||' UPDATE public.pnj_membres SET pa=greatest(0,(v_agent->>''pa'')::integer),maj_le=now()'
 ||' WHERE id=public.police_pnj_id(v_pj.country,v_pj.current_city,v_agent->>''matricule'') AND famille=''policier'' AND statut=''actif'';END IF;END LOOP;'
 ||chr(10)||a;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'combat_persistance_definition_non_examinee';END IF;
 EXECUTE replace(s,a,b);
END $socle$;
