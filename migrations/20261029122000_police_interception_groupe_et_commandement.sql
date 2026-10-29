-- #219 : mêmes détecteur et round, cible judiciaire distincte du commandeur.
-- Pas de substitution JWT : adaptateurs privés explicites.
DO $adaptateurs$
DECLARE s text;f record;nom text;a text;b text;
BEGIN
 FOR f IN SELECT * FROM (VALUES
 ('police_detection_verifier(text,text,text)','police_detection_personnage_interne','p_batiment text,p_piece text,p_rue text,p_cible text','CREATE OR REPLACE FUNCTION public.police_detection_personnage_interne('),
 ('police_combat_resoudre(text,text,text,text,integer)','police_combat_personnage_interne','p_rencontre text,p_rue text,p_batiment text,p_piece text,p_round integer,p_cible text','CREATE OR REPLACE FUNCTION public.police_combat_personnage_interne('),
 ('police_reprise_lire(text)','police_reprise_personnage_interne','p_rencontre text,p_cible text','CREATE OR REPLACE FUNCTION public.police_reprise_personnage_interne(')
 ) t(signature,prive,args,declaration) LOOP
  IF EXISTS(SELECT 1 FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname=f.prive) THEN CONTINUE;END IF;
  SELECT prosrc INTO s FROM pg_proc WHERE oid=('public.'||f.signature)::regprocedure AND prolang=(SELECT oid FROM pg_language WHERE lanname='plpgsql');
  IF s IS NULL THEN RAISE EXCEPTION 'police_adaptateur_corps_non_examine: %',f.signature;END IF;
  IF (SELECT count(*) FROM regexp_matches(s,'v_nom\s*:=\s*public.mon_personnage\(\)','g'))<>1 THEN RAISE EXCEPTION 'police_adaptateur_identite_non_examinee: %',f.signature;END IF;
  s:=regexp_replace(s,'v_nom\s*:=\s*public.mon_personnage\(\)','v_nom := p_cible');
  s:=replace(s,'public.justice_recherches(v_nom)','public.douane_recherches_interne(v_nom)');
  s:=replace(s,'public.justice_executer_condamnation_soi(v_jugement)','public.douane_condamnation_executer_interne(v_jugement,v_nom)');
  IF f.prive='police_combat_personnage_interne' THEN
   IF position('-- police_rounds_mixtes_v1' IN s)=0 THEN RAISE EXCEPTION 'rounds_mixtes_requis';END IF;
   s:=replace(s,'WHERE membre=v_nom','WHERE membre=public.mon_personnage()');
   a:=' INSERT INTO public.police_combat_rounds(personnage,rencontre,round_key)';
   b:=' IF p_round<>(SELECT coalesce(max(round_key),0)+1 FROM public.police_action_receipts WHERE personnage=v_nom AND rencontre=p_rencontre AND action=''combat'') THEN RETURN jsonb_build_object(''ok'',false,''raison'',''round_obsolete'');END IF;'||chr(10)||a;
   IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'police_sequence_rounds_non_examinee';END IF;
   s:=replace(s,a,b);
   s:=replace(s,'v_receipt:=jsonb_build_object(''ok'',true,''pa'',v_pj_pa,',
    'v_receipt:=jsonb_build_object(''ok'',true,''contrat_groupes'',1,''commandeur'',public.mon_personnage(),''personnage_intercepte'',v_nom,''pa'',(SELECT pa FROM public.personnages_donnees WHERE name=public.mon_personnage()),');
  END IF;
  EXECUTE format('%s%s) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',f.declaration,f.args,s);
 END LOOP;
END $adaptateurs$;
REVOKE ALL ON FUNCTION public.police_detection_personnage_interne(text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.police_combat_personnage_interne(text,text,text,text,integer,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.police_reprise_personnage_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.police_detection_verifier(p_batiment text,p_piece text,p_rue text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text;p public.personnages_donnees%ROWTYPE;n text;v jsonb;dernier jsonb;recherche boolean:=false;
BEGIN
 moi:=public.mon_personnage();IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie');END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 PERFORM name FROM public.personnages_donnees WHERE name IN (SELECT identifiant FROM public.groupe_participants_interne(moi) WHERE est_pj) ORDER BY name FOR UPDATE;
 FOR n IN SELECT g.identifiant FROM public.groupe_participants_interne(moi) g
 WHERE g.est_pj AND (g.pays,g.ville,g.batiment) IS NOT DISTINCT FROM (p.country,p.current_city,p.current_building)
 AND CASE WHEN p.current_building IS NULL THEN g.rue=p.current_street ELSE g.piece IS NOT DISTINCT FROM p.current_room END
 ORDER BY (g.identifiant=moi) DESC,g.identifiant LOOP
  v:=public.police_detection_personnage_interne(p_batiment,p_piece,p_rue,n);dernier:=v;
  IF v->>'raison' IS DISTINCT FROM 'non_recherche' THEN recherche:=true;END IF;
  IF coalesce((v->>'detecte')::boolean,false) THEN
   UPDATE public.police_interceptions SET
    combattants_victimes=coalesce(combattants_victimes,(SELECT jsonb_agg(g.cle) FROM public.groupe_combattants_interne(n,v->>'rencontre') g)),
    combattants_forces=coalesce(combattants_forces,(SELECT jsonb_agg(x->>'cle') FROM jsonb_array_elements(public.police_force_combattants_interne(n,v->>'rencontre')) x))
   WHERE personnage=n AND rencontre=v->>'rencontre';
   RETURN v||jsonb_build_object('personnage_intercepte',n,'contrat_groupes',1);END IF;
 END LOOP;
 IF recherche THEN
  IF dernier->>'raison'='non_recherche' THEN RETURN jsonb_build_object('ok',true,'detecte',false);END IF;
  RETURN coalesce(dernier,jsonb_build_object('ok',false,'raison','position_invalide'));END IF;
 RETURN jsonb_build_object('ok',true,'detecte',false,'raison','non_recherche');
END $g$;

CREATE OR REPLACE FUNCTION public.police_combat_resoudre(p_rencontre text,p_rue text DEFAULT NULL,p_batiment text DEFAULT NULL,p_piece text DEFAULT NULL,p_round integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text;cible text;v jsonb;chef text;
BEGIN
 moi:=public.mon_personnage();IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie');END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT verdict INTO v FROM public.police_action_receipts WHERE rencontre=p_rencontre AND action='combat' AND round_key=p_round
 AND (personnage=moi OR verdict->>'commandeur'=moi) ORDER BY created_at DESC LIMIT 1;
 IF FOUND THEN RETURN v;END IF;
 IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE membre=moi) THEN RETURN jsonb_build_object('ok',false,'raison','chef_de_groupe_requis');END IF;
 PERFORM public.pnj_groupes_verrouiller_projections_interne(ARRAY(SELECT identifiant FROM public.groupe_participants_interne(moi) WHERE NOT est_pj));
 v:=public.navigation_disponibilite_interne(moi);
 IF NOT coalesce((v->>'ok')::boolean,false) AND v->>'raison'<>'interception_en_cours' THEN RETURN v;END IF;
 IF EXISTS(SELECT 1 FROM public.police_interceptions WHERE personnage=moi AND expires_at>now() AND rencontre<>p_rencontre) THEN RETURN jsonb_build_object('ok',false,'raison','autre_interception_en_cours');END IF;
 SELECT i.personnage INTO cible FROM public.police_interceptions i
 JOIN public.groupe_participants_interne(moi) g ON g.est_pj AND g.identifiant=i.personnage
 JOIN public.personnages_donnees m ON m.name=moi
 WHERE i.rencontre=p_rencontre AND i.expires_at>now()
 AND (g.pays,g.ville,g.batiment) IS NOT DISTINCT FROM (m.country,m.current_city,m.current_building)
 AND CASE WHEN m.current_building IS NULL THEN g.rue=m.current_street ELSE g.piece IS NOT DISTINCT FROM m.current_room END
 ORDER BY i.personnage LIMIT 1;
 IF cible IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','detection_non_confirmee');END IF;
 RETURN public.police_combat_personnage_interne(p_rencontre,p_rue,p_batiment,p_piece,p_round,cible);
END $g$;

CREATE OR REPLACE FUNCTION public.police_reprise_lire(p_rencontre text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text;cible text;chef text;v jsonb;
BEGIN
 moi:=public.mon_personnage();IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie');END IF;
 SELECT coalesce((SELECT a.chef FROM public.groupes_pj_adhesions a WHERE a.membre=moi),moi) INTO chef;
 SELECT i.personnage INTO cible FROM public.police_interceptions i
 WHERE (p_rencontre IS NULL OR i.rencontre=p_rencontre)
 AND (i.personnage=moi OR (i.expires_at>now() AND i.personnage IN (SELECT identifiant FROM public.groupe_participants_interne(moi) WHERE est_pj)))
 ORDER BY (i.expires_at>now()) DESC,(i.personnage=moi) DESC,i.personnage LIMIT 1;
 cible:=coalesce(cible,moi);
 v:=public.police_reprise_personnage_interne(p_rencontre,cible);
 RETURN v||jsonb_build_object('personnage_intercepte',cible,'chef',chef,'peut_commander',chef=moi,'reddition_personnelle',cible=moi,'contrat_groupes',1);
END $g$;
-- CREATE OR REPLACE préserve les ACL publiques déjà définies ; tous les nouveaux
-- adaptateurs sont privés. Le rendu collectif doit accompagner cette migration.

DO $recu$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.police_action_resultat_lire(text,text,integer)'::regprocedure);
 IF position('-- police_recu_commandeur_v1' IN s)>0 THEN RETURN;END IF;
 a:='   WHERE personnage=v_nom AND rencontre=p_rencontre';
 b:='   -- police_recu_commandeur_v1'||chr(10)||'   WHERE (personnage=v_nom OR verdict->>''commandeur''=v_nom) AND rencontre=p_rencontre';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'police_recu_corps_non_examine';END IF;
 EXECUTE replace(s,a,b);
END $recu$;
