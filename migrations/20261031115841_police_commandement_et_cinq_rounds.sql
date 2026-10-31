-- #219 NON APPLIQUEE. Même détection, dossiers, justice et reçus policiers.
-- La décision du chef n'attribue aucune condamnation à ses compagnons innocents.
DO $adapter$
DECLARE s text;a text;
BEGIN
 IF to_regprocedure('public.police_reddition_personnage_interne(text,text)') IS NOT NULL THEN RETURN;END IF;
 SELECT prosrc INTO s FROM pg_proc WHERE oid='public.police_reddition_resoudre(text)'::regprocedure;
 a:='v_nom:=public.mon_personnage();';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'reddition_identite_non_examinee';END IF;
 s:=replace(s,a,'v_nom:=p_cible;');
 s:=replace(s,'public.justice_recherches(v_nom)','public.douane_recherches_interne(v_nom)');
 s:=replace(s,'public.justice_executer_condamnation_soi(v_jugement)','public.douane_condamnation_executer_interne(v_jugement,v_nom)');
 EXECUTE format('CREATE OR REPLACE FUNCTION public.police_reddition_personnage_interne(p_rencontre text,p_cible text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',s);
END $adapter$;
REVOKE ALL ON FUNCTION public.police_reddition_personnage_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.police_reddition_resoudre(p_rencontre text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE moi text;cible text;v jsonb;n integer;g jsonb;x jsonb;
BEGIN
 moi:=public.mon_personnage();IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie');END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT verdict INTO v FROM public.police_action_receipts WHERE rencontre=p_rencontre AND action='reddition' AND round_key=0
 AND (personnage=moi OR verdict->>'commandeur'=moi) LIMIT 1;
 IF FOUND THEN RETURN v;END IF;
 IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE membre=moi) THEN RETURN jsonb_build_object('ok',false,'raison','chef_de_groupe_requis');END IF;
 SELECT i.personnage INTO cible FROM public.police_interceptions i JOIN public.groupe_participants_interne(moi) p ON p.est_pj AND p.identifiant=i.personnage
 WHERE i.rencontre=p_rencontre AND i.expires_at>now() LIMIT 1;
 IF cible IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','rencontre_invalide');END IF;
 -- Contrôle ordinaire : même acte entier, sans ouvrir un combat artificiel.
 IF EXISTS(SELECT 1 FROM public.police_interceptions WHERE rencontre=p_rencontre AND nature='ordinaire') THEN
  IF cible<>moi THEN RETURN jsonb_build_object('ok',false,'raison','controle_personnel_a_raccorder');END IF;
  RETURN public.police_controle_action_interne(p_rencontre,'reddition');END IF;
 SELECT coalesce(max(round_key),0) INTO n FROM public.police_action_receipts WHERE rencontre=p_rencontre AND action='combat';
 IF NOT public.combat_desengagement_autorise_interne(n,n>0) THEN RETURN jsonb_build_object('ok',false,'raison','cinq_rounds_obligatoires');END IF;
 g:=public.police_groupe_combattants_interne(cible,p_rencontre);
 -- La primitive judiciaire refuse/annule avant toute neutralisation si l'écrou échoue.
 v:=public.police_reddition_personnage_interne(p_rencontre,cible);
 IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v;END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(g) LOOP
  IF x ? 'pj_nom' THEN UPDATE public.personnages_donnees SET pa=0 WHERE name=x->>'pj_nom';
  ELSE UPDATE public.pnj_membres SET pa=0 WHERE id=x->>'pnj_socle_id' AND statut='actif';END IF;
 END LOOP;
 PERFORM public.pnj_groupes_projeter_interne(ARRAY(SELECT el.obj->>'pnj_socle_id' FROM jsonb_array_elements(g) AS el(obj) WHERE el.obj ? 'pnj_socle_id'));
 v:=v||jsonb_build_object('commandeur',moi,'personnage_intercepte',cible,'contrat_groupes',1,'reddition',true);
 UPDATE public.police_action_receipts SET verdict=v WHERE personnage=cible AND rencontre=p_rencontre AND action='reddition' AND round_key=0;
 RETURN v;
END $g$;
REVOKE ALL ON FUNCTION public.police_reddition_resoudre(text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.police_reddition_resoudre(text) TO authenticated;
DO $fuite$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.police_fuite_resoudre(text)'::regprocedure);
 IF position('-- police_fuite_cinq_rounds_v1' IN s)>0 THEN RETURN;END IF;
 a:=$a$ IF EXISTS(SELECT 1 FROM public.police_action_receipts WHERE rencontre=p_rencontre AND personnage=cible AND action='combat') THEN
 RETURN jsonb_build_object('ok',false,'raison','combat_deja_engage');END IF;$a$;
 b:=$b$ -- police_fuite_cinq_rounds_v1
 IF NOT public.combat_desengagement_autorise_interne(
  (SELECT coalesce(max(round_key),0) FROM public.police_action_receipts WHERE rencontre=p_rencontre AND personnage=cible AND action='combat'),
  EXISTS(SELECT 1 FROM public.police_action_receipts WHERE rencontre=p_rencontre AND personnage=cible AND action='combat')) THEN
 RETURN jsonb_build_object('ok',false,'raison','cinq_rounds_obligatoires');END IF;$b$;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'police_fuite_phase_non_examinee';END IF;EXECUTE replace(s,a,b);
 s:=pg_get_functiondef('public.police_reprise_lire(text)'::regprocedure);
 a:='''reddition_personnelle'',cible=moi';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'police_reprise_chef_non_examinee';END IF;
 EXECUTE replace(s,a,'''reddition_personnelle'',chef=moi');
END $fuite$;
