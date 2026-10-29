-- Même jet de fuite et reçu existants ; déplacement entier par le moteur commun.
DO $fuite$
DECLARE s text;a text;b text;
BEGIN
 IF to_regprocedure('public.police_fuite_personnage_interne(text,text)') IS NOT NULL THEN RETURN;END IF;
 SELECT prosrc INTO s FROM pg_proc WHERE oid='public.police_fuite_resoudre(text)'::regprocedure;
 a:='v_nom:=public.mon_personnage();';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'fuite_identite_non_examinee';END IF;
 s:=replace(s,a,'v_nom:=p_cible;');
 a:=' FOR v_a IN SELECT value FROM jsonb_array_elements(v_agents) LOOP';
 b:=' v_agents:=public.police_force_combattants_interne(v_nom,p_rencontre);'||chr(10)||a;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'fuite_forces_non_examinees';END IF;
 s:=replace(s,a,b);
 a:=' UPDATE public.personnages_donnees SET current_street=v_destination WHERE id=v_pj.id;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'fuite_rue_position_non_examinee';END IF;
 s:=replace(s,a,' NULL; -- Déplacement délégué au moteur commun après validation.');
 a:=' UPDATE public.personnages_donnees SET current_building=NULL,current_room=NULL,current_street=v_destination WHERE id=v_pj.id;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'fuite_sortie_position_non_examinee';END IF;
 s:=replace(s,a,' NULL; -- Sortie déléguée au moteur commun après validation.');
 a:=' v_receipt:=jsonb_build_object(''ok'',true,''reussite'',true,''destination'',v_destination);';
 b:=$mouvement$
 -- Une seule mutation de position par membre, confiée au moteur commun.
 DECLARE v_mouvement jsonb;
 BEGIN
  v_mouvement:=public.navigation_commander_interne('rue',v_destination,NULL);
  IF NOT coalesce((v_mouvement->>'ok')::boolean,false) THEN
   RAISE EXCEPTION USING ERRCODE='P2193',MESSAGE='fuite_collective_refusee',DETAIL=v_mouvement::text;
  END IF;
 END;
 v_receipt:=jsonb_build_object('ok',true,'contrat_groupes',1,'commandeur',public.mon_personnage(),'personnage_intercepte',v_nom,'reussite',true,'destination',v_destination);
$mouvement$;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'fuite_deplacement_non_examine';END IF;
 s:=replace(s,a,b);
 a:='v_receipt:=jsonb_build_object(''ok'',true,''reussite'',false);';
 b:='v_receipt:=jsonb_build_object(''ok'',true,''contrat_groupes'',1,''commandeur'',public.mon_personnage(),''personnage_intercepte'',v_nom,''reussite'',false);';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'fuite_recu_non_examine';END IF;
 s:=replace(s,a,b);
 EXECUTE format('CREATE OR REPLACE FUNCTION public.police_fuite_personnage_interne(p_rencontre text,p_cible text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',s);
END $fuite$;
REVOKE ALL ON FUNCTION public.police_fuite_personnage_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.police_fuite_resoudre(p_rencontre text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text;cible text;v jsonb;detail text;
BEGIN
 moi:=public.mon_personnage();IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie');END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT verdict INTO v FROM public.police_action_receipts WHERE rencontre=p_rencontre AND action='fuite' AND round_key=0
 AND (personnage=moi OR verdict->>'commandeur'=moi) ORDER BY created_at DESC LIMIT 1;
 IF FOUND THEN RETURN v;END IF;
 IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE membre=moi) THEN RETURN jsonb_build_object('ok',false,'raison','chef_de_groupe_requis');END IF;
 PERFORM public.pnj_groupes_verrouiller_projections_interne(ARRAY(SELECT identifiant FROM public.groupe_participants_interne(moi) WHERE NOT est_pj));
 v:=public.navigation_disponibilite_interne(moi);
 IF NOT coalesce((v->>'ok')::boolean,false) AND v->>'raison'<>'interception_en_cours' THEN RETURN v;END IF;
 SELECT i.personnage INTO cible FROM public.police_interceptions i
 JOIN public.groupe_participants_interne(moi) g ON g.est_pj AND g.identifiant=i.personnage
 WHERE i.rencontre=p_rencontre AND i.expires_at>now() ORDER BY i.personnage LIMIT 1;
 IF cible IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','rencontre_invalide');END IF;
 IF EXISTS(SELECT 1 FROM public.police_action_receipts WHERE rencontre=p_rencontre AND personnage=cible AND action='combat') THEN
 RETURN jsonb_build_object('ok',false,'raison','combat_deja_engage');END IF;
 BEGIN
  RETURN public.police_fuite_personnage_interne(p_rencontre,cible);
 EXCEPTION WHEN SQLSTATE 'P2193' THEN GET STACKED DIAGNOSTICS detail=PG_EXCEPTION_DETAIL;RETURN detail::jsonb;
 END;
END $g$;
