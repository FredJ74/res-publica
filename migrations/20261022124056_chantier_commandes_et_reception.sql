-- Separation technique : migration sous la limite du canal MCP. PREPAREE.
BEGIN;
DO $g$ DECLARE h text; BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_commande(text,text,text,jsonb)'); IF h IS NOT NULL AND h<>'2a7f00f8cb89712411867063f13977f8' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_commande(text,text,text,jsonb)';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.chantier_commande(p_requete text,p_terrain_id text,p_action text,p_parametres jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
#variable_conflict use_variable
DECLARE acteur text:=public.mon_personnage();t record;a record;etat jsonb;ancien_etat jsonb;source jsonb;ch jsonb;pal record;rec record;commande jsonb;resultat jsonb;
 montant numeric;prix jsonb;plan jsonb;lot jsonb;lots jsonb:='[]';s numeric;total numeric:=0;minimum numeric;vus text[]:=ARRAY[]::text[];idlot text;dest text;r jsonb;cle text;v numeric;caisse text;avant text;entrepot text;besoin jsonb;
BEGIN
 IF acteur IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501';END IF;
 IF p_requete IS NULL OR p_requete !~ '^ch-[A-Za-z0-9-]{8,100}$' OR p_parametres IS NULL OR jsonb_typeof(p_parametres)<>'object' THEN RAISE EXCEPTION 'commande_invalide';END IF;
 SELECT * INTO a FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 PERFORM pg_advisory_xact_lock(hashtextextended('chantier:'||acteur||':'||p_requete,0));
 commande:=jsonb_build_object('action',p_action,'parametres',p_parametres);
 SELECT * INTO rec FROM public.chantier_commandes_recus cr WHERE cr.acteur=acteur AND cr.requete=p_requete;
 IF FOUND THEN
  IF rec.personnage_id IS DISTINCT FROM a.id OR rec.terrain_id IS DISTINCT FROM p_terrain_id OR rec.commande<>commande THEN RAISE EXCEPTION 'requete_reutilisee';END IF;
  RETURN rec.resultat||jsonb_build_object('rejeu',true);
 END IF;
 IF coalesce(a.hp,0)<=0 OR coalesce(a.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RAISE EXCEPTION 'acteur_incapacite';END IF;
 IF EXISTS(SELECT 1 FROM public.detention_active(acteur)) THEN RAISE EXCEPTION 'acteur_detenu';END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE country=a.country AND
  (id=p_terrain_id OR building_id=p_terrain_id AND data::jsonb->>'city'=a.current_city) ORDER BY (id=p_terrain_id) DESC LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'terrain_introuvable';END IF;
 ancien_etat:=t.data::jsonb;
 source:=public.chantier_financeur_verrouiller_interne(ancien_etat->>'proprietaire',t.country,ancien_etat->>'city');
 SELECT * INTO t FROM public.terrains_etat WHERE id=t.id FOR UPDATE;etat:=t.data::jsonb;
 IF etat->>'proprietaire' IS DISTINCT FROM ancien_etat->>'proprietaire' OR etat->>'city' IS DISTINCT FROM ancien_etat->>'city' THEN RAISE EXCEPTION 'titulaire_modifie';END IF;
 PERFORM public.chantier_autorite_exiger_interne(etat->>'proprietaire',t.country,etat->>'city');
 IF coalesce(etat->>'succession_gel','')<>'' THEN RAISE EXCEPTION 'terrain_gele';END IF;
 ch:=etat->'chantier';
 IF p_action='lancer' THEN
  IF p_parametres-ARRAY['palier','apport']<>'{}' THEN RAISE EXCEPTION 'champs_interdits';END IF;
  IF jsonb_typeof(ch)='object' OR jsonb_typeof(etat->'chantierReamenagement')='object' OR nullif(etat->>'niveau_construction','') IS NOT NULL THEN RAISE EXCEPTION 'chantier_ou_batiment_existant';END IF;
  IF NOT coalesce((etat->>'constructionAutorisee')::boolean,false) OR etat->'permis'->>'palierDemande' IS DISTINCT FROM p_parametres->>'palier' THEN RAISE EXCEPTION 'permis_non_conforme';END IF;
  IF etat->>'pnj' IN('squatter_cool','squatter_agr','cadavre') THEN RAISE EXCEPTION 'occupation_bloquante';END IF;
  SELECT * INTO pal FROM public.chantiers_paliers WHERE palier=p_parametres->>'palier';
  IF NOT FOUND THEN RAISE EXCEPTION 'palier_inconnu';END IF;
  IF p_parametres->>'apport' !~ '^[0-9]+$' OR p_parametres->>'apport' IS NULL THEN RAISE EXCEPTION 'francs_entiers_requis';END IF;
  montant:=(p_parametres->>'apport')::numeric;
  IF montant<pal.apport_minimal OR montant>pal.cout_total THEN RAISE EXCEPTION 'apport_hors_bornes';END IF;
  SELECT jsonb_object_agg(e.cle,ceil(e.prix_base*1.1)) INTO prix FROM public.ressources_economie e WHERE e.cle IN('bois','minerai','metal') AND e.prix_base>=0 AND e.prix_base::text NOT IN('NaN','Infinity','-Infinity');
  IF prix IS NULL OR (SELECT count(*) FROM jsonb_object_keys(prix))<>3 THEN RAISE EXCEPTION 'prix_indisponibles';END IF;
  IF NOT public.chantier_financeur_debiter_interne(source,montant) THEN RAISE EXCEPTION 'fonds_insuffisants';END IF;
  ch:=pal.gabarit||jsonb_build_object('jourDebut',a.day,'jourTraite',(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text,'totalVerse',montant,'tresorerie',montant,'prixAchatPJ',prix,'maitreOuvrage',etat->>'proprietaire','planInitialValide',false);
  SELECT building_id INTO entrepot FROM public.entrepots_par_ville WHERE ville=etat->>'city';
  IF entrepot IS NOT NULL THEN
   SELECT jsonb_build_object('bois',bois,'minerai',minerai,'metal',metal) INTO besoin FROM public.chantiers_besoins_jour WHERE position_cycle=1;
   IF besoin IS NULL THEN RAISE EXCEPTION 'besoin_chantier_absent';END IF;
   plan:=public.approvisionner_chantier(acteur,t.country,etat->>'city',entrepot,besoin,coalesce(ch->'stockMateriaux','{}'),(ch->>'tresorerie')::numeric);
   IF NOT coalesce((plan->>'ok')::boolean,false) THEN RAISE EXCEPTION 'approvisionnement_non_confirme';END IF;
   ch:=ch||jsonb_build_object('stockMateriaux',plan->'stockChantier','tresorerie',(ch->>'tresorerie')::numeric-(plan->>'depense')::numeric);
  END IF;
  etat:=etat||jsonb_build_object('chantier',ch);
 ELSIF p_action='verser' THEN
  IF p_parametres-ARRAY['montant']<>'{}' OR jsonb_typeof(ch) IS DISTINCT FROM 'object' OR (ch->>'progressionJours')::numeric>=(ch->>'dureeJours')::numeric THEN RAISE EXCEPTION 'versement_impossible';END IF;
  IF p_parametres->>'montant' !~ '^[0-9]+$' OR p_parametres->>'montant' IS NULL THEN RAISE EXCEPTION 'francs_entiers_requis';END IF;
  montant:=least((p_parametres->>'montant')::numeric,(ch->>'coutTotal')::numeric-(ch->>'totalVerse')::numeric);
  IF montant<=0 THEN RAISE EXCEPTION 'montant_invalide';END IF;
  IF NOT public.chantier_financeur_debiter_interne(source,montant) THEN RAISE EXCEPTION 'fonds_insuffisants';END IF;
  ch:=ch||jsonb_build_object('totalVerse',(ch->>'totalVerse')::numeric+montant,'tresorerie',(ch->>'tresorerie')::numeric+montant);
  etat:=etat||jsonb_build_object('chantier',ch);
 ELSIF p_action='receptionner' THEN
  IF p_parametres<>'{}'::jsonb OR jsonb_typeof(ch) IS DISTINCT FROM 'object' OR NOT coalesce((ch->>'progressionJours')::numeric>=(ch->>'dureeJours')::numeric AND (ch->>'dureeJours')::numeric>0,false) THEN RAISE EXCEPTION 'chantier_non_acheve';END IF;
  IF coalesce((ch->>'totalVerse')::numeric,0)<coalesce((ch->>'coutTotal')::numeric,1) THEN RAISE EXCEPTION 'financement_incomplet';END IF;
  IF a.country IS DISTINCT FROM t.country OR a.current_city IS DISTINCT FROM etat->>'city' OR a.current_building IS DISTINCT FROM t.building_id THEN RAISE EXCEPTION 'pas_sur_place';END IF;
  IF etat->'chantierAcheve'->'reliquats'->>'restitue'='false' THEN RAISE EXCEPTION 'anciens_reliquats_en_attente';END IF;
  plan:=coalesce(etat->'permis'->'decoupageInitial','[]');
  IF jsonb_typeof(plan)<>'array' THEN RAISE EXCEPTION 'plan_invalide';END IF;
  -- Les minima proviennent de SURFACES_MIN_LOT (plateau-immobilier.js) ; comparaison locale obligatoire.
  FOR lot IN SELECT value FROM jsonb_array_elements(plan) LOOP
   idlot:=nullif(btrim(lot->>'id'),'');dest:=coalesce(lot->>'destination','commerce');
   minimum:=CASE WHEN ch->>'niveau'='commerce_premium' AND dest='commerce' THEN 600 WHEN ch->>'niveau'='building' AND dest='commerce' THEN 300 WHEN ch->>'niveau'='building' AND dest='appartement' THEN 150 END;
   s:=(lot->>'surface')::numeric;total:=total+s;
   IF idlot IS NULL OR idlot=ANY(vus) OR minimum IS NULL OR s IS NULL OR s<minimum OR nullif(etat->>'surface','') IS NULL OR total>(etat->>'surface')::numeric THEN RAISE EXCEPTION 'plan_invalide';END IF;
   vus:=array_append(vus,idlot);
   lots:=lots||jsonb_build_array(jsonb_build_object('id',idlot,'label',coalesce(nullif(btrim(lot->>'label'),''),'Lot'),'surface',s,'destination',dest,'locataire',NULL,'loyer',0));
  END LOOP;
  IF jsonb_array_length(coalesce(etat->'subdivisions','[]'))>0 THEN RAISE EXCEPTION 'lots_preexistants_a_examiner';END IF;
  montant:=coalesce((ch->>'tresorerie')::numeric,0);
  IF montant<0 OR montant<>trunc(montant) OR montant::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'reliquat_invalide';END IF;
  caisse:=t.country||'_'||(etat->>'city')||'_'||t.building_id;
  IF montant>0 THEN
   avant:=current_setting('rp.caisse_interne',true);PERFORM set_config('rp.caisse_interne','on',true);
   r:=public.caisse_institution_mouvement(caisse,montant,false);PERFORM set_config('rp.caisse_interne',coalesce(avant,''),true);
   IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'reliquat_caisse_non_confirme';END IF;
  END IF;
  FOREACH cle IN ARRAY ARRAY['bois','minerai','metal'] LOOP
   v:=coalesce((ch->'stockMateriaux'->>cle)::numeric,0);
   IF v<0 OR v<>trunc(v) OR v::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'stock_reliquat_invalide';END IF;
   etat:=jsonb_set(etat,'{stockMateriaux}',coalesce(etat->'stockMateriaux','{}')||jsonb_build_object(cle,coalesce((etat->'stockMateriaux'->>cle)::numeric,0)+v));
  END LOOP;
  IF jsonb_typeof(etat->'chantierAcheve')='object' THEN etat:=etat||jsonb_build_object('chantiersArchives',coalesce(etat->'chantiersArchives','[]')||jsonb_build_array(etat->'chantierAcheve'));END IF;
  etat:=(etat-'chantier')||jsonb_build_object('niveau_construction',ch->>'niveau','subdivisions',lots,'planInitialValide',coalesce((ch->>'planInitialValide')::boolean,false),
   'chantierAcheve',ch||jsonb_build_object('livre',true,'jourLivraison',(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text,'tresorerie',0,'stockMateriaux',jsonb_build_object('bois',0,'minerai',0,'metal',0),'reliquats',jsonb_build_object('restitue',true,'beneficiaire',etat->>'proprietaire','caisse',caisse,'tresorerie',montant,'materiaux',ch->'stockMateriaux')));
 ELSE RAISE EXCEPTION 'action_inconnue';
 END IF;
 UPDATE public.terrains_etat SET data=etat::text,niveau_construction=etat->>'niveau_construction',updated_at=now() WHERE id=t.id;
 resultat:=jsonb_build_object('ok',true,'etat',etat,'chantier',etat->'chantier','montant',montant,'pourcentage',CASE WHEN etat ? 'chantier' THEN floor((etat->'chantier'->>'totalVerse')::numeric*100/(etat->'chantier'->>'coutTotal')::numeric) ELSE 100 END);
 INSERT INTO public.chantier_commandes_recus(personnage_id,acteur,requete,terrain_id,commande,resultat) VALUES(a.id,acteur,p_requete,p_terrain_id,commande,resultat);
 RETURN resultat;
EXCEPTION WHEN SQLSTATE 'P0001' OR insufficient_privilege THEN
 IF SQLERRM=ANY(ARRAY['acteur_detenu','financement_incomplet','acteur_incapacite','acteur_non_authentifie','action_inconnue','anciens_reliquats_en_attente','apport_hors_bornes','approvisionnement_non_confirme','besoin_chantier_absent','champs_interdits','chantier_non_acheve','chantier_ou_batiment_existant','commande_invalide','fonds_insuffisants','francs_entiers_requis','lots_preexistants_a_examiner','mandat_municipal_requis','montant_invalide','occupation_bloquante','palier_inconnu','pas_proprietaire','pas_sur_place','permis_non_conforme','plan_invalide','prix_indisponibles','reliquat_caisse_non_confirme','reliquat_invalide','requete_reutilisee','stock_reliquat_invalide','terrain_gele','terrain_introuvable','titulaire_modifie','versement_impossible','representation_organisation_refusee','etat_financier_non_entier','organisation_absente']) THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);END IF;
 RAISE;
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_commande(text,text,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.chantier_commande(text,text,text,jsonb) TO authenticated;
COMMIT;
