-- #219 NON APPLIQUÉE. Même dossier, reçus, saisie et écrou ; pas de sanction cliente.
-- Dépend de 220000 et du lot complet groupes/inventaire. Prévol vivant obligatoire.
CREATE OR REPLACE FUNCTION public.police_controle_action_interne(p_rencontre text,p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE moi text;p public.personnages_donnees%ROWTYPE;i public.police_interceptions%ROWTYPE;
 v jsonb;forces jsonb;vol numeric;chance numeric;peine record;motifs jsonb;
BEGIN
 moi:=public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie');END IF;
 IF p_action NOT IN ('reddition','fuite') OR p_action IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','action_invalide');END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 PERFORM public.pnj_groupes_verrouiller_projections_interne(ARRAY(SELECT identifiant FROM public.groupe_participants_interne(moi) WHERE NOT est_pj));
 PERFORM name FROM public.personnages_donnees WHERE name IN (SELECT identifiant FROM public.groupe_participants_interne(moi) WHERE est_pj) ORDER BY name FOR UPDATE;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 SELECT verdict INTO v FROM public.police_action_receipts WHERE personnage=moi AND rencontre=p_rencontre AND action=p_action AND round_key=0;
 IF FOUND THEN RETURN v;END IF;
 IF EXISTS(SELECT 1 FROM public.police_action_receipts WHERE personnage=moi AND rencontre=p_rencontre AND verdict->>'controle_ordinaire'='true') THEN
 RETURN jsonb_build_object('ok',false,'raison','controle_termine');END IF;
 SELECT * INTO i FROM public.police_interceptions WHERE personnage=moi AND rencontre=p_rencontre FOR UPDATE;
 IF NOT FOUND OR i.nature<>'ordinaire' OR i.expires_at<=now() OR i.controle->>'phase' IS DISTINCT FROM 'choix'
 OR (i.country,i.city,i.building) IS DISTINCT FROM (p.country,p.current_city,p.current_building)
 OR (CASE WHEN i.building IS NULL THEN i.street IS DISTINCT FROM p.current_street ELSE i.room IS DISTINCT FROM p.current_room END) THEN
 RETURN jsonb_build_object('ok',false,'raison','rencontre_invalide');END IF;
 v:=public.navigation_disponibilite_interne(moi);
 IF NOT coalesce((v->>'ok')::boolean,false) AND v->>'raison' IS DISTINCT FROM 'interception_en_cours' THEN RETURN v;END IF;
 forces:=public.police_force_combattants_interne(moi,p_rencontre);
 IF jsonb_array_length(forces)=0 THEN RETURN jsonb_build_object('ok',false,'raison','aucun_policier_present');END IF;
 IF p_action='fuite' THEN
  SELECT avg((x->'stats'->>'VOL')::numeric) INTO vol FROM jsonb_array_elements(forces) x;
  IF vol IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','profil_combattant_a_raccorder');END IF;
  -- Règle historique du contrôle ordinaire : VOL/VOL, aucun bonus d'effectif ou DIS.
  chance:=greatest(10,least(90,50+5*(coalesce((p.stats->>'VOL')::numeric,8)-vol)));
  IF floor(random()*100)+1<=chance THEN
   v:=jsonb_build_object('ok',true,'controle_ordinaire',true,'reussite',true,'phase','fuite');
  END IF;
 END IF;
 IF v IS NULL OR v->>'phase' IS DISTINCT FROM 'fuite' THEN
  v:=public.douane_confisquer_personnage_interne(moi);
  IF NOT coalesce((v->>'ok')::boolean,false) THEN RAISE EXCEPTION 'confiscation_non_confirmee';END IF;
  IF jsonb_array_length(v->'saisis')=0 THEN
   v:=jsonb_build_object('ok',true,'controle_ordinaire',true,'phase','rien');
  ELSIF p_action='reddition' THEN
   UPDATE public.personnages_donnees SET convocations=coalesce(convocations,'[]'::jsonb)||jsonb_build_array(jsonb_build_object(
    'id','conv-police-'||p_rencontre,'motif','possession_illegale_douane','jourEmission',coalesce(day,1),
    'heureEmission',extract(hour FROM now() AT TIME ZONE 'Europe/Paris')::integer,'jourLimite',coalesce(day,1)+1,
    'heureLimite',extract(hour FROM now() AT TIME ZONE 'Europe/Paris')::integer,'traitee',false,
    'limiteTs',to_char((now()+interval '24 hours') AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'))) WHERE name=moi;
   PERFORM public.mail_systeme_poser_interne('Commissariat',moi,'Convocation officielle',
    'Des objets prohibés ont été confisqués. Présentez-vous au commissariat sous 24h.');
   v:=v||jsonb_build_object('controle_ordinaire',true,'phase','convocation');
  ELSE
   -- Le +1 jour appartient à la même ouverture de peine, jamais à une sauvegarde.
   IF p.country='republic' THEN SELECT libelle,jours_reference INTO peine FROM public.infractions WHERE id='possession_illegale_douane';
   ELSE SELECT libelle,jours_reference INTO peine FROM public.infractions_categories WHERE id='delit_mineur';END IF;
   IF NOT FOUND OR peine.jours_reference IS NULL OR peine.jours_reference<1 THEN RAISE EXCEPTION 'bareme_possession_absent';END IF;
   motifs:=jsonb_build_array(jsonb_build_object('type',peine.libelle,'jours',peine.jours_reference,'source','controle_police'),
    jsonb_build_object('type','Fuite ratée','jours',1,'source','controle_police'));
   v:=public.detention_ouvrir_interne(moi,peine.libelle,peine.jours_reference+1,p.current_city,p.country,motifs,'controle_police','fuite_ratee');
   IF NOT coalesce((v->>'ok')::boolean,false) OR v->>'detention_id' IS NULL THEN RAISE EXCEPTION 'detention_non_confirmee';END IF;
   v:=v||jsonb_build_object('controle_ordinaire',true,'phase','detention','reussite',false);
  END IF;
 END IF;
 UPDATE public.police_interceptions SET expires_at=now(),controle=v,fuite_tentee=p_action='fuite' WHERE personnage=moi AND rencontre=p_rencontre;
 -- Le reçu est dans la transaction des conséquences. L'inventaire sera toujours relu
 -- par le client : un reçu ancien ne doit pas restaurer un état d'inventaire périmé.
 INSERT INTO public.police_action_receipts(personnage,rencontre,action,round_key,verdict) VALUES(moi,p_rencontre,p_action,0,v);
 RETURN v;
END $g$;
REVOKE ALL ON FUNCTION public.police_controle_action_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
DO $portes$
DECLARE s text;f record;a text;b text;
BEGIN
 FOR f IN SELECT * FROM (VALUES ('police_reddition_resoudre(text)','reddition'),('police_fuite_resoudre(text)','fuite'),('police_combat_resoudre(text,text,text,text,integer)','combat')) t(sig,action) LOOP
  s:=pg_get_functiondef(('public.'||f.sig)::regprocedure);
  IF position('-- controle_ordinaire_dispatch_v1' IN s)>0 THEN CONTINUE;END IF;
  a:='BEGIN';
  b:=$b$BEGIN
 -- controle_ordinaire_dispatch_v1
 IF EXISTS(SELECT 1 FROM public.police_interceptions WHERE personnage=public.mon_personnage() AND rencontre=p_rencontre AND nature='ordinaire')
 OR EXISTS(SELECT 1 FROM public.police_action_receipts WHERE personnage=public.mon_personnage() AND rencontre=p_rencontre AND verdict->>'controle_ordinaire'='true') THEN
 $b$||CASE WHEN f.action='combat' THEN 'RETURN jsonb_build_object(''ok'',false,''raison'',''controle_non_judiciaire'');'
 ELSE 'RETURN public.police_controle_action_interne(p_rencontre,'||quote_literal(f.action)||');' END||chr(10)||' END IF;';
  IF position(a IN s)=0 OR position('public.mon_personnage()' IN s)=0 THEN RAISE EXCEPTION 'controle_porte_non_examinee:%',f.sig;END IF;
  EXECUTE overlay(s placing b FROM position(a IN s) FOR length(a));
 END LOOP;
 s:=pg_get_functiondef('public.police_reprise_lire(text)'::regprocedure);
 IF position('-- controle_ordinaire_reprise_v1' IN s)>0 THEN RETURN;END IF;
 a:=' SELECT coalesce((SELECT a.chef';
 b:=$b$ -- controle_ordinaire_reprise_v1
 SELECT jsonb_build_object('ok',true,'active',i.expires_at>now(),'rencontre',i.rencontre,
  'country',i.country,'city',i.city,'building',i.building,'room',i.room,'street',i.street,
  'controle',i.controle,'controle_ordinaire',true) INTO v FROM public.police_interceptions i
 WHERE i.personnage=moi AND i.nature='ordinaire' AND (p_rencontre IS NULL OR i.rencontre=p_rencontre);
 IF FOUND THEN RETURN v;END IF;
$b$||a;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'controle_reprise_non_examinee';END IF;EXECUTE replace(s,a,b);
END $portes$;
