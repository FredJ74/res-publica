-- #219 : deuxième partie indispensable de 20261031115833.
-- La fin active la garde d’installation seulement une fois tous les effets prêts.
DO $effets$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_appliquer(bigint,jsonb,integer)'::regprocedure);
 IF position('-- bataille_effets_socle_v1' IN s)>0 THEN RETURN;END IF;
 a:='  act jsonb; v_pa integer;';b:='  v_pnj text; v_statut text; -- bataille_effets_socle_v1'||chr(10)||a;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_effets_declaration_non_examinee';END IF;s:=replace(s,a,b);
 a:='    v_degre := act->>''degre''; v_protege := false;';
 b:=a||E'\n    SELECT pnj_id INTO v_pnj FROM public.batailles_engagements WHERE id=(act->>''cib_eng'')::bigint AND bataille_id=p_bataille_id;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_effets_cible_non_examinee';END IF;s:=replace(s,a,b);
 a:=$a$      v_gilet := public.militaire_gilet_absorber(
        (act->>'cib_pj')::boolean, act->>'cib_nom',
        act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');$a$;
 b:='      IF v_pnj IS NOT NULL THEN v_gilet:=public.combat_gilet_pnj_absorber_interne(v_pnj); ELSE'||chr(10)||a||' END IF;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_effets_gilet_non_examine';END IF;s:=replace(s,a,b);
 a:=$a$      PERFORM public.militaire_soldat_pa_fixer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat', v_new);$a$;
 b:='      IF v_pnj IS NOT NULL THEN UPDATE public.pnj_membres SET pa=v_new WHERE id=v_pnj; PERFORM public.pnj_groupes_projeter_interne(ARRAY[v_pnj]); ELSE'||chr(10)||a||' END IF;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_effets_PA_non_examines';END IF;s:=replace(s,a,b);
 a:=$a$        UPDATE public.personnages_donnees
           SET current_city = 'caserne', current_building = 'caserne-militaire',$a$;
 b:='        PERFORM public.groupe_ecrou_separer_interne(act->>''cib_nom'');'||chr(10)||a;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_incapacite_non_examinee';END IF;s:=replace(s,a,b);
 a:=$a$      PERFORM public.militaire_soldat_supprimer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');$a$;
 b:='      IF v_pnj IS NOT NULL THEN PERFORM public.pnj_mourir(v_pnj,''degats''); PERFORM public.pnj_groupes_projeter_interne(ARRAY[v_pnj]); END IF;'||chr(10)
 ||'      IF act->>''cib_cie'' IS NOT NULL THEN'||chr(10)||a||' END IF;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_effets_mort_non_examinee';END IF;s:=replace(s,a,b);
 EXECUTE s;
END $effets$;

-- Les anciennes gardes reconnaissent aussi les nouveaux engagements PNJ.
DO $gardes$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.groupe_combattants_interne(text,text,bigint)'::regprocedure);
 a:='(NOT g.est_pj AND sm.pnj_id=g.identifiant)';
 IF position(a IN s)>0 THEN EXECUTE replace(s,a,'(NOT g.est_pj AND (sm.pnj_id=g.identifiant OR e.pnj_id=g.identifiant))');END IF;
 s:=pg_get_functiondef('public.pnj_confrontation_refus_interne(text[])'::regprocedure);
 IF position('-- bataille_PNJ_socle_garde_v1' IN s)=0 THEN
  a:=') x WHERE x.raison IS NOT NULL LIMIT 1;';
  IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_garde_PNJ_non_examinee';END IF;
  EXECUTE replace(s,a,E' -- bataille_PNJ_socle_garde_v1\n UNION ALL SELECT ''combat_en_cours'' FROM public.batailles_engagements e JOIN public.batailles b ON b.id=e.bataille_id WHERE e.pnj_id=ANY(p_ids) AND e.sorti_round IS NULL AND b.statut=''en_cours''\n '||a);
 END IF;
END $gardes$;

DO $projections$
DECLARE s text;
BEGIN
 s:=pg_get_functiondef('public.effectifs_ecriture_metier_garder()'::regprocedure);
 IF position('''/rpc/militaire_bataille_poursuivre''' IN s)=0 THEN
  IF position('''/rpc/force_publique_effectif_acte''' IN s)=0 THEN RAISE EXCEPTION 'bataille_projection_garde_non_examinee';END IF;
  EXECUTE replace(s,'''/rpc/force_publique_effectif_acte''','''/rpc/militaire_bataille_poursuivre'',''/rpc/militaire_bataille_decider'',''/rpc/militaire_bataille_engager'',''/rpc/force_publique_effectif_acte''');
 END IF;
END $projections$;

DO $chef$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_groupes_constituer(bigint)'::regprocedure);
 IF position('-- bataille_chef_universel_v1' IN s)>0 THEN RETURN;END IF;
 a:='  RETURN v_n;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_constitution_non_examinee';END IF;
 EXECUTE replace(s,a,E' -- bataille_chef_universel_v1\n UPDATE public.batailles_groupes g SET leader=(SELECT e.personnage FROM public.batailles_engagements e WHERE e.bataille_id=g.bataille_id AND e.groupe_id=g.groupe_id AND g.groupe_id=g.camp||''|pj:''||e.personnage LIMIT 1) WHERE g.bataille_id=p_bataille_id AND g.groupe_id LIKE g.camp||''|pj:%'';\n'||a);
END $chef$;

CREATE OR REPLACE FUNCTION public.militaire_bataille_decrocher_groupe(p_bataille_id bigint,p_groupe_id text,p_round integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE destination jsonb;ids text[];pnjs text[];nom text;v jsonb;n integer;b public.batailles%ROWTYPE;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT * INTO b FROM public.batailles WHERE id=p_bataille_id FOR UPDATE;
 SELECT repli INTO destination FROM public.batailles_groupes WHERE bataille_id=p_bataille_id AND groupe_id=p_groupe_id AND sorti_round IS NULL FOR UPDATE;
 IF destination IS NULL THEN RETURN 0;END IF;
 IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles WHERE pays=b.pays AND ville=destination->>'ville' AND batiment=destination->>'batiment' AND pieces ? (destination->>'piece') AND NOT ferme) THEN RAISE EXCEPTION 'repli_non_reference';END IF;
 SELECT array_agg(personnage ORDER BY personnage) FILTER(WHERE personnage IS NOT NULL),
  coalesce(array_agg(pnj_id ORDER BY pnj_id) FILTER(WHERE pnj_id IS NOT NULL),'{}'::text[]),count(*)
 INTO ids,pnjs,n FROM public.batailles_engagements WHERE bataille_id=p_bataille_id AND groupe_id=p_groupe_id AND sorti_round IS NULL;
 PERFORM public.pnj_groupes_verrouiller_projections_interne(pnjs);
 PERFORM name FROM public.personnages_donnees WHERE name=ANY(ids) ORDER BY name FOR UPDATE;
 PERFORM id FROM public.pnj_membres WHERE id=ANY(pnjs) ORDER BY id FOR UPDATE;
 -- Sortie de CET engagement avant la garde habituelle. Un échec de garde
 -- lève une erreur et annule aussi cette sortie ; aucun membre n'est déplacé.
 UPDATE public.batailles_engagements SET sorti_round=p_round,etat_final='replie'
 WHERE bataille_id=p_bataille_id AND groupe_id=p_groupe_id AND sorti_round IS NULL;
 FOREACH nom IN ARRAY coalesce(ids,'{}'::text[]) LOOP
  v:=public.navigation_disponibilite_interne(nom);
  IF NOT coalesce((v->>'ok')::boolean,false) THEN RAISE EXCEPTION 'repli_refuse' USING ERRCODE='P2194',DETAIL=v::text;END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.pnj_membres WHERE id=ANY(pnjs) AND statut<>'actif') THEN RAISE EXCEPTION 'repli_PNJ_indisponible';END IF;
 UPDATE public.personnages_donnees SET current_city=destination->>'ville',current_building=destination->>'batiment',
  current_room=destination->>'piece',current_street=NULL,updated_at=clock_timestamp() WHERE name=ANY(ids);
 UPDATE public.pnj_membres SET ville=destination->>'ville',building_id=destination->>'batiment',room_id=destination->>'piece',rue_noeud_id=NULL,maj_le=clock_timestamp()
 WHERE id=ANY(pnjs) AND leader_pj IS NULL AND leader_pnj_id IS NULL;
 PERFORM public.pnj_groupes_projeter_interne(pnjs);
 UPDATE public.batailles_groupes SET sorti_round=p_round,attente_depuis=NULL WHERE bataille_id=p_bataille_id AND groupe_id=p_groupe_id;
 RETURN n;
END $g$;
REVOKE ALL ON FUNCTION public.militaire_bataille_decrocher_groupe(bigint,text,integer) FROM PUBLIC,anon,authenticated,service_role;

DO $verrous$
DECLARE f text;s text;
BEGIN
 FOREACH f IN ARRAY ARRAY['militaire_bataille_engager()','militaire_bataille_poursuivre(bigint)','militaire_bataille_decider(bigint,text)','militaire_bataille_avancer(bigint)','militaire_bataille_round(bigint)'] LOOP
  s:=pg_get_functiondef(('public.'||f)::regprocedure);
  IF position('-- bataille_graphe_avant_lignes_v1' IN s)=0 THEN
   IF position('BEGIN' IN s)=0 THEN RAISE EXCEPTION 'bataille_verrou_non_examine: %',f;END IF;
   s:=overlay(s placing E'BEGIN\n -- bataille_graphe_avant_lignes_v1\n PERFORM pg_advisory_xact_lock(hashtextextended(''groupe_pj:graphe'',0));' FROM position('BEGIN' IN s) FOR 5);EXECUTE s;
  END IF;
 END LOOP;
END $verrous$;

-- L'observation d'un round ne permet jamais de faire combattre un PJ évacué,
-- détenu, hospitalisé ou ailleurs, ni un PNJ déjà mort/neutralisé.
DO $disponibles$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_combattants(bigint,text)'::regprocedure);
 IF position('-- bataille_disponibilite_round_v1' IN s)=0 THEN
  a:='     AND e.personnage IS NOT NULL AND e.sorti_round IS NULL';
  b:=a||E'\n -- bataille_disponibilite_round_v1\n AND pd.pa>0 AND coalesce(pd.hp,100)>0 AND (pd.est_emprisonne IS NULL OR pd.est_emprisonne=''null''::jsonb)\n AND coalesce(pd.hospitalisation->>''dateFinParis'','''')<=(statement_timestamp() AT TIME ZONE ''Europe/Paris'')::date::text\n AND NOT CASE WHEN coalesce(pd.hospitalisation->>''jourFin'','''')~''^[0-9]+$'' THEN (pd.hospitalisation->>''jourFin'')::numeric>coalesce(pd.day,1) ELSE false END\n AND EXISTS(SELECT 1 FROM public.batailles bb WHERE bb.id=e.bataille_id AND (pd.country,pd.current_city,pd.current_building,pd.current_room) IS NOT DISTINCT FROM (bb.pays,bb.ville,bb.batiment,bb.piece))';
  IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_disponibilite_PJ_non_examinee';END IF;s:=replace(s,a,b);
  a:='m.statut=''actif'' AND m.pa>0';
  b:=a||' AND EXISTS(SELECT 1 FROM public.pnj_position_effective(m.id) pe JOIN public.batailles bb ON bb.id=e.bataille_id WHERE (pe.pays,pe.ville,pe.building_id,pe.room_id) IS NOT DISTINCT FROM (bb.pays,bb.ville,bb.batiment,bb.piece))';
  IF (length(s)-length(replace(s,a,'')))/length(a)<>2 THEN RAISE EXCEPTION 'bataille_disponibilite_PNJ_non_examinee';END IF;
  EXECUTE replace(s,a,b);
 END IF;
 s:=pg_get_functiondef('public.militaire_bataille_round(bigint)'::regprocedure);
 IF position('-- bataille_sorties_indisponibles_v1' IN s)=0 THEN
  a:='  SELECT coalesce(array_agg(DISTINCT camp), ''{}'') INTO v_camps';
  b:=E' -- bataille_sorties_indisponibles_v1\n PERFORM public.pnj_groupes_verrouiller_projections_interne(ARRAY(SELECT pnj_id FROM public.batailles_engagements WHERE bataille_id=p_bataille_id AND sorti_round IS NULL AND pnj_id IS NOT NULL ORDER BY pnj_id));\n PERFORM d.name FROM public.personnages_donnees d WHERE d.name IN (SELECT personnage FROM public.batailles_engagements WHERE bataille_id=p_bataille_id AND sorti_round IS NULL) ORDER BY d.name FOR UPDATE;\n PERFORM m.id FROM public.pnj_membres m WHERE m.id IN (SELECT pnj_id FROM public.batailles_engagements WHERE bataille_id=p_bataille_id AND sorti_round IS NULL) ORDER BY m.id FOR UPDATE;\n UPDATE public.batailles_engagements e SET sorti_round=v_round,etat_final=''indisponible'' WHERE e.bataille_id=p_bataille_id AND e.sorti_round IS NULL AND NOT EXISTS(SELECT 1 FROM public.militaire_bataille_combattants(p_bataille_id,e.camp) c WHERE c.eng_id=e.id);\n'||a;
  IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_round_sorties_non_examinees';END IF;EXECUTE replace(s,a,b);
 END IF;
END $disponibles$;
