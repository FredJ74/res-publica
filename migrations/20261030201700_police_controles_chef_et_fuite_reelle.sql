-- #219 PRÉPARÉE. Même acte ordinaire, mêmes saisies, jets, convocations et écrous.
-- Seul le chef commande ; la conséquence judiciaire vise le porteur réel.
DO $controle$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.police_controle_action_interne(text,text)'::regprocedure);
 IF position('-- controle_chef_et_fuite_reelle_v1' IN s)>0 THEN RETURN;END IF;
 a:='DECLARE moi text;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'controle_variables_non_examinees';END IF;
 s:=replace(s,a,'DECLARE acteur text;destination text;deplacement jsonb;moi text;');
 a:=' IF p_action NOT IN (''reddition'',''fuite'')';
 b:=$b$
 -- controle_chef_et_fuite_reelle_v1
 acteur:=moi;
 IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE membre=acteur) THEN RETURN jsonb_build_object('ok',false,'raison','chef_de_groupe_requis');END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT r.verdict INTO v FROM public.police_action_receipts r WHERE rencontre=p_rencontre AND action=p_action AND round_key=0
  AND (personnage=acteur OR r.verdict->>'commandeur'=acteur) ORDER BY created_at DESC LIMIT 1;
 IF FOUND THEN RETURN v;END IF;
 SELECT rencontre_lue.personnage INTO moi FROM public.police_interceptions rencontre_lue JOIN public.groupe_participants_interne(acteur) g ON g.est_pj AND g.identifiant=rencontre_lue.personnage
 WHERE rencontre_lue.rencontre=p_rencontre AND rencontre_lue.nature='ordinaire' LIMIT 1;
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','rencontre_invalide');END IF;
$b$||a;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'controle_acteur_non_examine';END IF;s:=replace(s,a,b);
 a:=' IF p_action=''fuite'' THEN';
 b:=$b$ IF p_action='fuite' THEN
  deplacement:=public.navigation_destination_fuite_interne(moi);
  IF NOT coalesce((deplacement->>'ok')::boolean,false) THEN RETURN deplacement;END IF;
  destination:=deplacement->>'destination';$b$;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'controle_destination_non_examinee';END IF;s:=replace(s,a,b);
 a:=' -- Le reçu est dans la transaction des conséquences.';
 b:=$b$ IF v->>'phase'='fuite' THEN
  -- Le contrôle est clos dans cette même transaction avant la garde commune.
  deplacement:=public.navigation_commander_interne('rue',destination,NULL);
  IF NOT coalesce((deplacement->>'ok')::boolean,false) THEN
   RAISE EXCEPTION USING ERRCODE='P2193',MESSAGE='controle_fuite_collective_refusee',DETAIL=deplacement::text;
  END IF;
  v:=v||jsonb_build_object('destination',destination);
 END IF;
 v:=v||jsonb_build_object('commandeur',acteur,'personnage_intercepte',moi,'contrat_groupes',1);
$b$||a;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'controle_mouvement_non_examine';END IF;s:=replace(s,a,b);
 -- Une garde aval annule le jet, l'expiration et toutes les mutations du bloc.
 a:=' RETURN v;'||chr(10)||'END';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'controle_transaction_non_examinee';END IF;
 s:=replace(s,a,' RETURN v;'||chr(10)||'EXCEPTION WHEN SQLSTATE ''P2193'' THEN GET STACKED DIAGNOSTICS destination=PG_EXCEPTION_DETAIL;RETURN destination::jsonb;'||chr(10)||'END');
 EXECUTE s;
 -- Supprimer le seul raccord temporaire, sans nouvelle route.
 s:=pg_get_functiondef('public.police_reddition_resoudre(text)'::regprocedure);
 a:='  IF cible<>moi THEN RETURN jsonb_build_object(''ok'',false,''raison'',''controle_personnel_a_raccorder'');END IF;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'controle_reddition_non_examinee';END IF;EXECUTE replace(s,a,'');
 -- Le dispatch ordinaire de fuite doit trouver le compagnon contrôlé, pas seulement le chef.
 s:=pg_get_functiondef('public.police_fuite_resoudre(text)'::regprocedure);
 a:='WHERE personnage=public.mon_personnage() AND rencontre=p_rencontre AND nature=''ordinaire''';
 b:='WHERE personnage IN (SELECT identifiant FROM public.groupe_participants_interne(public.mon_personnage()) WHERE est_pj) AND rencontre=p_rencontre AND nature=''ordinaire''';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'controle_fuite_dispatch_non_examine';END IF;EXECUTE replace(s,a,b);
END $controle$;

CREATE OR REPLACE FUNCTION public.police_reprise_lire(p_rencontre text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE moi text;chef text;i public.police_interceptions%ROWTYPE;v jsonb;
BEGIN
 moi:=public.mon_personnage();IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie');END IF;
 SELECT coalesce((SELECT a.chef FROM public.groupes_pj_adhesions a WHERE a.membre=moi),moi) INTO chef;
 SELECT * INTO i FROM public.police_interceptions r
 WHERE (p_rencontre IS NULL OR r.rencontre=p_rencontre)
 AND (r.personnage=moi OR (r.expires_at>now() AND r.personnage IN (SELECT identifiant FROM public.groupe_participants_interne(moi) WHERE est_pj)))
 ORDER BY (r.expires_at>now()) DESC,(r.personnage=moi) DESC,r.personnage LIMIT 1;
 IF FOUND AND i.nature='ordinaire' THEN
  v:=jsonb_build_object('ok',true,'active',i.expires_at>now(),'rencontre',i.rencontre,
   'country',i.country,'city',i.city,'building',i.building,'room',i.room,'street',i.street,
   'controle',i.controle,'controle_ordinaire',true);
 ELSE v:=public.police_reprise_personnage_interne(p_rencontre,coalesce(i.personnage,moi));END IF;
 RETURN v||jsonb_build_object('personnage_intercepte',coalesce(i.personnage,moi),'chef',chef,
  'peut_commander',chef=moi,'reddition_personnelle',chef=moi,'contrat_groupes',1);
END $g$;
