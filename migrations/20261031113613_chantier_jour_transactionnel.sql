-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261022123320_chantier_jour_transactionnel.sql ; aucun changement de règle.
-- #57 PREPAREE. Remplace l'ecriture quotidienne de construction ; aucune livraison automatique.
BEGIN;
DO $g$ DECLARE h text; BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_jour_traiter(text)'); IF h IS NOT NULL AND h<>'6410338f9007370e43d05703cbf73913' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_jour_traiter(text)';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.chantier_jour_traiter(p_terrain_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE r record;snapshot jsonb;etat jsonb;ch jsonb;source jsonb;jour text;avant numeric;apres numeric;d numeric;
 besoin jsonb;stock jsonb;plan jsonb;entrepot text;num integer;m text;req numeric;f numeric:=1;cap numeric;faites numeric;heures numeric;cout numeric;gain numeric;plafond numeric;taux numeric;rep jsonb;ancien text;
BEGIN
 IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','reserve_au_serveur');END IF;
 SELECT * INTO r FROM public.terrains_etat WHERE id=p_terrain_id;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_absent');END IF;
 snapshot:=r.data::jsonb;
 IF jsonb_typeof(snapshot->'chantier') IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('ok',true,'ignore',true);END IF;
 -- Le verrou du financeur precede celui du terrain, comme lancement/ventes/transferts.
 source:=public.chantier_financeur_verrouiller_interne(snapshot->>'proprietaire',r.country,snapshot->>'city');
 SELECT * INTO r FROM public.terrains_etat WHERE id=p_terrain_id FOR UPDATE;etat:=r.data::jsonb;
 IF etat->>'proprietaire' IS DISTINCT FROM snapshot->>'proprietaire' OR etat->>'city' IS DISTINCT FROM snapshot->>'city' THEN
  RETURN jsonb_build_object('ok',false,'raison','titulaire_modifie');END IF;
 ch:=etat->'chantier';jour:=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;
 IF coalesce(etat->>'succession_gel','')<>'' THEN RETURN jsonb_build_object('ok',true,'ignore',true,'raison','terrain_gele');END IF;
 IF ch->>'type' IS DISTINCT FROM 'construction' THEN RETURN jsonb_build_object('ok',false,'raison','chantier_historique_a_examiner');END IF;
 IF ch->>'jourTraite'=jour THEN RETURN jsonb_build_object('ok',true,'rejeu',true,'etat',etat);END IF;
 avant:=(ch->>'progressionJours')::numeric;d:=(ch->>'dureeJours')::numeric;
 IF avant IS NULL OR avant<0 OR d IS NULL OR d<=0 OR d<>trunc(d) THEN RAISE EXCEPTION 'dimensionnement_chantier_invalide';END IF;
 IF avant<d THEN
  ch:=public.chantier_appel_fonds_interne(ch,source);
  IF ch->>'arrete' IS DISTINCT FROM 'financement' THEN
   num:=floor(avant)::integer+1;
   SELECT jsonb_build_object('bois',bois,'minerai',minerai,'metal',metal) INTO besoin FROM public.chantiers_besoins_jour
    WHERE position_cycle=((num-1)%(SELECT count(*) FROM public.chantiers_besoins_jour))+1;
   IF besoin IS NULL THEN RAISE EXCEPTION 'besoin_chantier_absent';END IF;
   SELECT building_id INTO entrepot FROM public.entrepots_par_ville WHERE ville=etat->>'city';
   stock:=coalesce(ch->'stockMateriaux','{}');
   IF entrepot IS NOT NULL THEN
    plan:=public.approvisionner_chantier(source->>'destinataire',r.country,etat->>'city',entrepot,besoin,stock,coalesce((ch->>'tresorerie')::numeric,0));
    IF NOT coalesce((plan->>'ok')::boolean,false) THEN RAISE EXCEPTION 'approvisionnement_non_confirme';END IF;
    stock:=plan->'stockChantier';ch:=ch||jsonb_build_object('tresorerie',(ch->>'tresorerie')::numeric-(plan->>'depense')::numeric);
   END IF;
   FOREACH m IN ARRAY ARRAY['bois','minerai','metal'] LOOP
    req:=(besoin->>m)::numeric;
    IF req>0 THEN f:=least(f,greatest(0,coalesce((stock->>m)::numeric,0))/req);END IF;
   END LOOP;
   SELECT valeur INTO taux FROM public.entreprises_constantes WHERE cle='chantier_taux_horaire';
   IF taux IS NULL OR taux<=0 THEN RAISE EXCEPTION 'taux_chantier_indisponible';END IF;
   cap:=(ch->>'coutTravail')::numeric/taux/d;faites:=coalesce((ch->>'heuresFaites')::numeric,0);
   IF cap IS NULL OR cap<=0 OR faites<0 OR faites>cap THEN RAISE EXCEPTION 'capacite_travail_invalide';END IF;
   plafond:=CASE WHEN (ch->>'totalVerse')::numeric>=(ch->>'coutTotal')::numeric THEN d
     WHEN (ch->>'totalVerse')::numeric>=ceil((ch->>'coutTotal')::numeric*.7) THEN d*2/3 ELSE d/3 END;
   heures:=greatest(0,least(floor(cap*least(f,d-avant,plafond-avant))-faites,floor((ch->>'tresorerie')::numeric/taux)));cout:=heures*taux;
   IF cout>0 THEN
    ancien:=current_setting('rp.caisse_interne',true);PERFORM set_config('rp.caisse_interne','on',true);
    rep:=public.caisse_institution_mouvement(r.country||'_gouvernement-min_fin',cout,true);
    PERFORM set_config('rp.caisse_interne',coalesce(ancien,''),true);
    IF NOT coalesce((rep->>'ok')::boolean,false) THEN RAISE EXCEPTION 'remuneration_pnj_non_confirmee';END IF;
   END IF;
   gain:=least(1,f,(faites+heures)/cap,d-avant);
   gain:=greatest(0,least(gain,plafond-avant));apres:=avant+gain;
   FOREACH m IN ARRAY ARRAY['bois','minerai','metal'] LOOP
    stock:=jsonb_set(stock,ARRAY[m],to_jsonb(greatest(0,coalesce((stock->>m)::numeric,0)-floor((besoin->>m)::numeric*gain))));
   END LOOP;
   ch:=ch||jsonb_build_object('progressionJours',apres,'tresorerie',(ch->>'tresorerie')::numeric-cout,'stockMateriaux',stock,'heuresFaites',0,'arrete',CASE WHEN gain=0 THEN 'penurie_materiaux' ELSE NULL END,
    'evenements',coalesce(ch->'evenements','[]')||jsonb_build_array(jsonb_build_object('cle','journee','date',jour,'avance',gain,'heuresPNJ',heures,'coutPNJ',cout,'achats',plan->'achats')));
   -- Un seuil atteint aujourd'hui appelle immediatement la tranche suivante, sans avancer le temps utile si refus.
   IF apres<d THEN ch:=public.chantier_appel_fonds_interne(ch,source);END IF;
  END IF;
 END IF;
 IF (ch->>'progressionJours')::numeric>=d THEN
  IF NOT coalesce((ch->>'attenteReception')::boolean,false) AND nullif(source->>'destinataire','') IS NOT NULL THEN
   rep:=public.mail_systeme_poser_interne('Chef de Chantier',source->>'destinataire','Chantier acheve — reception sur place','Les travaux sont acheves. Venez sur place pour receptionner le batiment et ouvrir ses locaux.');
   IF NOT coalesce((rep->>'ok')::boolean,false) THEN ch:=ch||jsonb_build_object('notificationEchec',rep);END IF;
  END IF;
  ch:=ch||jsonb_build_object('attenteReception',true,'arrete',null);
 END IF;
 ch:=ch||jsonb_build_object('jourTraite',jour);
 etat:=etat||jsonb_build_object('chantier',ch);
 UPDATE public.terrains_etat SET data=etat::text,updated_at=now() WHERE id=p_terrain_id;
 RETURN jsonb_build_object('ok',true,'etat',etat,'attenteReception',coalesce((ch->>'attenteReception')::boolean,false),'avance',coalesce(gain,0));
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_jour_traiter(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.chantier_jour_traiter(text) TO service_role;
COMMIT;
