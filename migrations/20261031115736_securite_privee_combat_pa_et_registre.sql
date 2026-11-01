-- Scission technique sous 12 500 caractères, pas une nouvelle mécanique.
-- Dépend de 20261031115734 et 20261031115735. Aucun test sur joueur réel.
DO $patch$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.police_fuite_resoudre(text)'::regprocedure);
 a:='IF NOT FOUND THEN RETURN jsonb_build_object(''ok'',false,''raison'',''effectifs_absents''); END IF;';
 b:='-- Une force privée présente reste admissible sans policier.';
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'fuite_commissariat_conflit';
 ELSE s:=replace(s,a,b); END IF;
 a:='v_agents:=v_b.data::jsonb->''effectifsPolice''->''policiers'';'
    ||chr(10)||' IF jsonb_typeof(v_agents) IS DISTINCT FROM ''array'' THEN RETURN jsonb_build_object(''ok'',false,''raison'',''effectifs_invalides''); END IF;';
 b:='v_agents:=CASE WHEN jsonb_typeof(v_b.data::jsonb->''effectifsPolice''->''policiers'')=''array'' THEN v_b.data::jsonb->''effectifsPolice''->''policiers'' ELSE ''[]''::jsonb END;'
    ||chr(10)||' PERFORM m.id FROM public.pnj_membres m WHERE (''prive:''||m.id) IN (SELECT jsonb_array_elements_text(CASE WHEN jsonb_typeof(v_i.intervenants)=''array'' THEN v_i.intervenants ELSE ''[]''::jsonb END)) ORDER BY m.id FOR UPDATE;'
    ||chr(10)||' v_agents:=v_agents || public.securite_agents_prives_presents_interne(v_i.country,v_i.city,v_i.building,v_i.room,v_i.street,v_nom);'
   ||chr(10)||' IF jsonb_typeof(v_i.intervenants)=''array'' THEN'
   ||chr(10)||'   SELECT coalesce(jsonb_agg(x),''[]''::jsonb) INTO v_agents FROM jsonb_array_elements(v_agents) x'
   ||chr(10)||'   WHERE x->>''matricule'' IN (SELECT jsonb_array_elements_text(v_i.intervenants));'
   ||chr(10)||' END IF;';
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'fuite_effectifs_conflit';
 ELSE s:=replace(s,a,b); END IF;
 EXECUTE s;
END $patch$;

DO $patch$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.police_combat_resoudre(text,text,text,text,integer)'::regprocedure);
 a:='IF NOT FOUND THEN RETURN jsonb_build_object(''ok'',false,''raison'',''effectifs_absents''); END IF;';
 b:='-- Reprendre la même confrontation avec les agents présents.';
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'combat_commissariat_conflit';
 ELSE s:=replace(s,a,b); END IF;
 a:='v_agents := v_police->''policiers'';'
    ||chr(10)||' IF jsonb_typeof(v_agents) IS DISTINCT FROM ''array'' THEN'
    ||chr(10)||'   RETURN jsonb_build_object(''ok'',false,''raison'',''effectifs_invalides'');'
    ||chr(10)||' END IF;';
 b:='v_agents := CASE WHEN jsonb_typeof(v_police->''policiers'')=''array'' THEN v_police->''policiers'' ELSE ''[]''::jsonb END;'
    ||chr(10)||' PERFORM m.id FROM public.pnj_membres m WHERE (''prive:''||m.id) IN (SELECT jsonb_array_elements_text(CASE WHEN jsonb_typeof(v_interception.intervenants)=''array'' THEN v_interception.intervenants ELSE ''[]''::jsonb END)) ORDER BY m.id FOR UPDATE;'
    ||chr(10)||' v_agents := v_agents || public.securite_agents_prives_presents_interne(v_pj.country,v_pj.current_city,p_batiment,p_piece,p_rue,v_nom);'
   ||chr(10)||' IF jsonb_typeof(v_interception.intervenants)=''array'' THEN'
   ||chr(10)||'   SELECT coalesce(jsonb_agg(x),''[]''::jsonb) INTO v_agents FROM jsonb_array_elements(v_agents) x'
   ||chr(10)||'   WHERE x->>''matricule'' IN (SELECT jsonb_array_elements_text(v_interception.intervenants));'
   ||chr(10)||' END IF;';
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'combat_effectifs_conflit';
 ELSE s:=replace(s,a,b); END IF;
 -- Les PNJ privés combattent avec les mêmes PA, mais leur état reste dans pnj_membres.
 a:=' -- Réécriture par matricule ; les policiers absents ne sont jamais touchés.';
 b:=' -- Persister aussi les PA des agents privés actifs après le round.'
   ||chr(10)||' FOR v_idx IN 0..jsonb_array_length(v_actifs)-1 LOOP'
   ||chr(10)||'   v_agent := v_actifs->v_idx;'
   ||chr(10)||'   IF v_agent ? ''pnj_prive_id'' THEN'
   ||chr(10)||'     UPDATE public.pnj_membres SET pa=greatest(0,(v_agent->>''pa'')::integer),maj_le=now()'
   ||chr(10)||'     WHERE id=v_agent->>''pnj_prive_id'' AND statut=''actif'';'
   ||chr(10)||'   END IF;'
   ||chr(10)||' END LOOP;'
   ||chr(10)||' -- Réécriture par matricule ; les policiers absents ne sont jamais touchés.';
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'combat_pnj_pa_conflit';
 ELSE s:=replace(s,a,b); END IF;
 -- La liste filtrée des combattants ne remplace jamais le registre du commissariat.
 a:=' -- Réécriture par matricule ; les policiers absents ne sont jamais touchés.'
   ||chr(10)||' FOR v_agent IN SELECT value FROM jsonb_array_elements(v_agents) LOOP';
 b:=' -- Réécriture par matricule ; les policiers absents ne sont jamais touchés.'
   ||chr(10)||' FOR v_agent IN SELECT value FROM jsonb_array_elements(coalesce(v_police->''policiers'',''[]''::jsonb)) LOOP';
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'combat_registre_complet_conflit';
 ELSE s:=replace(s,a,b); END IF;
 a:=' UPDATE public.batiments_etat SET data=v_etat,updated_at=now()'
  ||chr(10)||' WHERE id=v_bat.id;';
 b:=' IF v_bat.id IS NOT NULL THEN'
  ||chr(10)||' UPDATE public.batiments_etat SET data=v_etat,updated_at=now()'
  ||chr(10)||' WHERE id=v_bat.id; END IF;';
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'combat_persistance_police_conflit';
 ELSE s:=replace(s,a,b); END IF;
 EXECUTE s;
END $patch$;
