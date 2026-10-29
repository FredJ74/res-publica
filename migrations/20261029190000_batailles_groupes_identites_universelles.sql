-- #219. Même bataille, mêmes engagements, coups et effets. Une référence au
-- socle permet d'engager un PNJ sans lui fabriquer une carrière militaire.
ALTER TABLE public.batailles_engagements ADD COLUMN IF NOT EXISTS pnj_id text REFERENCES public.pnj_membres(id);
UPDATE public.batailles_engagements e SET pnj_id=m.pnj_id
FROM public.pnj_soldats_metier m WHERE e.pnj_id IS NULL AND e.personnage IS NULL
 AND (e.compagnie_id,e.section_id,e.matricule)=(m.compagnie_id,m.section_id,m.matricule);
CREATE UNIQUE INDEX IF NOT EXISTS batailles_engagements_socle_unique
 ON public.batailles_engagements(bataille_id,pnj_id) WHERE pnj_id IS NOT NULL;

DO $adapter$
DECLARE s text;
BEGIN
 IF to_regprocedure('public.militaire_bataille_recruter_metier_interne(bigint,text,text,text,text)') IS NULL THEN
  s:=pg_get_functiondef('public.militaire_bataille_recruter(bigint,text,text,text,text)'::regprocedure);
  IF position('-- recrutement_presence_et_etat_v1' IN s)=0 THEN RAISE EXCEPTION 'recrutement_metier_precondition_absente';END IF;
  IF position('(bataille_id, camp, compagnie_id, section_id, matricule, grade, pa_initial, groupe_id)' IN s)=0 THEN RAISE EXCEPTION 'recrutement_identite_PNJ_non_examinee';END IF;
  s:=replace(s,'(bataille_id, camp, compagnie_id, section_id, matricule, grade, pa_initial, groupe_id)',
    '(bataille_id, camp, compagnie_id, section_id, matricule, grade, pa_initial, groupe_id, pnj_id)');
  s:=replace(s,'m.pa, p_camp || ''|'' || cm.id || '':'' || sm.section_id','m.pa, p_camp || ''|'' || cm.id || '':'' || sm.section_id, m.id');
  EXECUTE replace(s,'CREATE OR REPLACE FUNCTION public.militaire_bataille_recruter(','CREATE OR REPLACE FUNCTION public.militaire_bataille_recruter_metier_interne(');
 END IF;
END $adapter$;
REVOKE ALL ON FUNCTION public.militaire_bataille_recruter_metier_interne(bigint,text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.militaire_bataille_recruter(p_bataille_id bigint,p_camp text,p_ville text,p_bat text,p_piece text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE s record;g record;racine text;gid text;pnj text;personne text;ids text[];
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 PERFORM public.militaire_bataille_recruter_metier_interne(p_bataille_id,p_camp,p_ville,p_bat,p_piece);
 UPDATE public.batailles_engagements e SET pnj_id=m.pnj_id FROM public.pnj_soldats_metier m
 WHERE e.bataille_id=p_bataille_id AND e.personnage IS NULL AND e.pnj_id IS NULL
 AND (e.compagnie_id,e.section_id,e.matricule)=(m.compagnie_id,m.section_id,m.matricule);
 -- Les graines restent celles autorisées par la guerre et les services.
 -- L'accompagnement n'accorde ni grade, ni mandat, ni changement d'employeur.
 FOR s IN SELECT e.*,m.leader_pj,m.leader_pnj_id FROM public.batailles_engagements e
 LEFT JOIN public.pnj_membres m ON m.id=e.pnj_id
 WHERE e.bataille_id=p_bataille_id AND e.camp=p_camp AND e.sorti_round IS NULL ORDER BY e.id LOOP
  personne:=coalesce(s.personnage,s.leader_pj);
  IF personne IS NOT NULL THEN
   racine:=coalesce((SELECT chef FROM public.groupes_pj_adhesions WHERE membre=personne),personne);
   gid:=p_camp||'|pj:'||racine;
   FOR g IN SELECT * FROM public.groupe_combattants_interne(personne,NULL,p_bataille_id) LOOP
    IF EXISTS(SELECT 1 FROM public.batailles_engagements e WHERE e.bataille_id=p_bataille_id AND e.camp<>p_camp
       AND ((g.est_pj AND e.personnage=g.identifiant) OR (NOT g.est_pj AND e.pnj_id=g.identifiant))) THEN
     RAISE EXCEPTION 'groupe_camps_incompatibles';
    END IF;
    IF g.est_pj THEN
     INSERT INTO public.batailles_engagements(bataille_id,camp,personnage,pa_initial,groupe_id)
      VALUES(p_bataille_id,p_camp,g.identifiant,g.pa,gid) ON CONFLICT DO NOTHING;
     UPDATE public.batailles_engagements SET groupe_id=gid WHERE bataille_id=p_bataille_id AND personnage=g.identifiant;
    ELSE
     IF EXISTS(SELECT 1 FROM public.pnj_membres m WHERE m.id=g.identifiant AND m.famille<>'soldat' AND (m.car_per IS NULL OR m.car_dup IS NULL)) THEN RAISE EXCEPTION 'profil_combattant_incomplet';END IF;
     INSERT INTO public.batailles_engagements(bataille_id,camp,pnj_id,compagnie_id,section_id,matricule,pa_initial,groupe_id)
      SELECT p_bataille_id,p_camp,g.identifiant,sm.compagnie_id,sm.section_id,coalesce(sm.matricule,g.identifiant),g.pa,gid
      FROM public.pnj_membres m LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id=m.id WHERE m.id=g.identifiant ON CONFLICT DO NOTHING;
     UPDATE public.batailles_engagements SET groupe_id=gid WHERE bataille_id=p_bataille_id AND pnj_id=g.identifiant;
    END IF;
   END LOOP;
  ELSE
   -- Détachement de PNJ déjà présent : aucune autonomie de déplacement ajoutée.
   racine:=coalesce(s.leader_pnj_id,s.pnj_id);gid:=p_camp||'|pnj:'||racine;
   FOR g IN SELECT m.id,m.pa FROM public.pnj_membres m
    CROSS JOIN LATERAL public.pnj_position_effective(m.id) pe
    JOIN public.batailles b ON b.id=p_bataille_id
    WHERE (m.id=racine OR m.leader_pnj_id=racine) AND m.statut='actif' AND m.pa>0
    AND (pe.pays,pe.ville,pe.building_id,pe.room_id) IS NOT DISTINCT FROM (b.pays,p_ville,p_bat,p_piece)
    AND NOT EXISTS(SELECT 1 FROM public.batailles_engagements e JOIN public.batailles autre ON autre.id=e.bataille_id
      WHERE e.pnj_id=m.id AND e.sorti_round IS NULL AND autre.statut='en_cours' AND autre.id<>p_bataille_id)
    ORDER BY m.id LOOP
    IF EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille_id AND pnj_id=g.id AND camp<>p_camp) THEN RAISE EXCEPTION 'groupe_camps_incompatibles';END IF;
    INSERT INTO public.batailles_engagements(bataille_id,camp,pnj_id,compagnie_id,section_id,matricule,pa_initial,groupe_id)
     SELECT p_bataille_id,p_camp,g.id,sm.compagnie_id,sm.section_id,coalesce(sm.matricule,g.id),g.pa,gid
     FROM public.pnj_membres m LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id=m.id WHERE m.id=g.id ON CONFLICT DO NOTHING;
    UPDATE public.batailles_engagements SET groupe_id=gid WHERE bataille_id=p_bataille_id AND pnj_id=g.id;
   END LOOP;
  END IF;
 END LOOP;
END $g$;
REVOKE ALL ON FUNCTION public.militaire_bataille_recruter(bigint,text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;

-- Le gilet PNJ a un seul résolveur, extrait du corps existant sans changer
-- le jet, l'ordre du choix ni la dégradation de l'objet.
DO $gilet$
DECLARE s text;debut integer;fin integer;corps text;
BEGIN
 s:=pg_get_functiondef('public.militaire_gilet_absorber(boolean,text,text,text,text)'::regprocedure);
 IF position('-- gilet_pnj_commun_v1' IN s)>0 THEN RETURN;END IF;
 debut:=position('  -- LE PNJ :' IN s);fin:=position('  -- Le jet AVANT' IN s);
 IF debut=0 OR fin<=debut THEN RAISE EXCEPTION 'gilet_pnj_corps_non_examine';END IF;
 corps:=substring(s FROM fin);fin:=position('END;' IN corps);
 IF fin=0 THEN RAISE EXCEPTION 'gilet_pnj_fin_non_examinee';END IF;
 corps:=substring(corps FROM 1 FOR fin-1);
 EXECUTE 'CREATE OR REPLACE FUNCTION public.combat_gilet_pnj_absorber_interne(p_id text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $giletcorps$ DECLARE v_ligne bigint;v_objet jsonb;v_protege boolean; BEGIN '
 ||' SELECT p.id,p.objet INTO v_ligne,v_objet FROM public.pnj_possessions p WHERE p.pnj_id=p_id AND p.objet->>''produitMilitaire''=''gilet_pare_balles'' AND coalesce((p.objet->>''fragilise'')::boolean,false)=false ORDER BY p.id LIMIT 1 FOR UPDATE;'
 ||' IF v_ligne IS NULL THEN RETURN jsonb_build_object(''protege'',false,''raison'',''aucun_gilet_intact'');END IF;'||corps||' END $giletcorps$';
 s:=substring(s FROM 1 FOR debut-1)||E' -- gilet_pnj_commun_v1\n SELECT pnj_id INTO v_pnj FROM public.pnj_soldats_metier WHERE compagnie_id=p_compagnie_id AND section_id=p_section_id AND matricule=p_matricule;\n RETURN public.combat_gilet_pnj_absorber_interne(v_pnj);\nEND;\n$function$';
 EXECUTE s;
END $gilet$;
REVOKE ALL ON FUNCTION public.combat_gilet_pnj_absorber_interne(text) FROM PUBLIC,anon,authenticated,service_role;

-- Ajouter les PNJ non soldats au lecteur existant, sans changer son contrat.
DO $lecteur$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_combattants(bigint,text)'::regprocedure);
 IF position('-- bataille_identites_socle_v1' IN s)>0 THEN RETURN;END IF;
 a:='     AND sm.section_id = e.section_id;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_lecteur_corps_non_examine';END IF;
 b:=$branche$
     AND sm.section_id = e.section_id AND m.statut='actif' AND m.pa>0
  -- bataille_identites_socle_v1
  UNION ALL
  SELECT e.id,false,m.nom,NULL::text,NULL::text,m.id,m.pa,
    0::numeric,0::numeric,(af.cle IS NOT NULL),coalesce(af.cle,ac.cle,'corps_a_corps'),coalesce(af.bonus,ac.bonus,0),
    m.car_per::numeric,m.car_dup::numeric,e.saute_round,e.groupe_id
  FROM public.batailles_engagements e JOIN public.pnj_membres m ON m.id=e.pnj_id
  LEFT JOIN LATERAL (SELECT b.cle,b.bonus FROM public.pnj_possessions p JOIN public.militaire_armes_bonus b ON b.cle=coalesce(p.objet->>'produitMilitaire',p.objet->>'name') WHERE p.pnj_id=m.id AND p.objet->>'type'='arme' AND b.mode='feu' ORDER BY b.bonus DESC,p.id LIMIT 1) af ON true
  LEFT JOIN LATERAL (SELECT b.cle,b.bonus FROM public.pnj_possessions p JOIN public.militaire_armes_bonus b ON b.cle=coalesce(p.objet->>'produitMilitaire',p.objet->>'name') WHERE p.pnj_id=m.id AND p.objet->>'type'='arme' AND b.mode='cac' ORDER BY b.bonus DESC,p.id LIMIT 1) ac ON true
  WHERE e.bataille_id=p_bataille_id AND e.camp=p_camp AND e.sorti_round IS NULL
  AND e.personnage IS NULL AND m.famille<>'soldat' AND m.statut='actif' AND m.pa>0;
$branche$;
 -- Comme un PJ sans apprentissage militaire : tir et CAC non entraînés = 0.
 -- Défenses : caractéristiques du métier ; armes : possessions canoniques.
 s:=replace(s,a,b);
 EXECUTE s;
END $lecteur$;

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
  b:=E' -- bataille_sorties_indisponibles_v1\n UPDATE public.batailles_engagements e SET sorti_round=v_round,etat_final=''indisponible'' WHERE e.bataille_id=p_bataille_id AND e.sorti_round IS NULL AND NOT EXISTS(SELECT 1 FROM public.militaire_bataille_combattants(p_bataille_id,e.camp) c WHERE c.eng_id=e.id);\n'||a;
  IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_round_sorties_non_examinees';END IF;EXECUTE replace(s,a,b);
 END IF;
END $disponibles$;
