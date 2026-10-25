-- Après jets_resources_canoniques : caractéristiques du PNJ, pas une estimation navigateur.
BEGIN;
DO $g$ DECLARE h text;BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.vol_commande(text,text,uuid)');IF h IS NULL OR h NOT IN('0c67ee7c26e527a33d328a90354ce820','c1f53a92a8a780482bed1d576e6fe883') THEN RAISE EXCEPTION 'definition_non_examinee: vol_commande';END IF;END;$g$;
CREATE OR REPLACE FUNCTION public.vol_commande(p_cible text,p_genre text,p_requete uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();p record;v record;pnj record;ancien record;stats_cible jsonb;pj boolean;
 r jsonb;reception jsonb;objet jsonb;inv jsonb;nouvel_inv jsonb;bonus integer;score numeric;alea numeric;per_cible numeric;int_cible numeric;
 carrieres jsonb;succes boolean;palier text;butin text:='rien';montant numeric:=0;amende numeric:=0;fonds numeric;fonds_apres numeric;
 v_fonds numeric;v_banque numeric;p_banque numeric;pos integer;qte integer;jeton uuid;revision bigint;v_revision bigint;v_id text;jour integer;perte_pop integer:=0;
BEGIN
 IF moi IS NULL OR auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR p_genre NOT IN('argent','objet') OR p_genre IS NULL OR coalesce(btrim(p_cible),'')='' OR moi=p_cible THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 -- Ordre stable des deux verrous pour les vols réciproques.
 PERFORM 1 FROM public.personnages_donnees d WHERE d.name IN(moi,p_cible) ORDER BY d.id FOR UPDATE;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 IF NOT FOUND OR p.user_id IS DISTINCT FROM auth.uid() THEN RETURN jsonb_build_object('ok',false,'raison','personnage_non_possede');END IF;
 SELECT * INTO ancien FROM public.vols_commandes_recus WHERE acteur=p.id AND requete=p_requete;
 IF FOUND THEN
  IF ancien.cible IS DISTINCT FROM p_cible OR ancien.genre IS DISTINCT FROM p_genre THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  r:=ancien.resultat||'{"rejeu":true}';
 ELSE
  IF coalesce(p.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(moi)) OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
  SELECT * INTO v FROM public.personnages_donnees WHERE name=p_cible;pj:=FOUND;
  IF pj THEN
   IF v.country IS DISTINCT FROM p.country OR v.current_city IS DISTINCT FROM p.current_city OR v.current_building IS DISTINCT FROM p.current_building OR v.current_room IS DISTINCT FROM p.current_room THEN RETURN jsonb_build_object('ok',false,'raison','cible_absente');END IF;
   stats_cible:=v.stats;
  ELSE
   SELECT * INTO pnj FROM public.pnj_membres WHERE nom=p_cible ORDER BY id LIMIT 1;
   IF FOUND THEN
    IF NOT public.pnj_co_present(moi,pnj.id) THEN RETURN jsonb_build_object('ok',false,'raison','cible_absente');END IF;
    stats_cible:=jsonb_build_object('PER',to_jsonb(pnj)->'car_per','INT',to_jsonb(pnj)->'car_int');
   ELSE
    SELECT s.stats INTO stats_cible FROM public.vol_pnj_referentiel s WHERE s.pays=p.country AND s.ville=p.current_city AND s.batiment=p.current_building AND s.piece=p.current_room AND s.nom=p_cible;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','cible_absente');END IF;
   END IF;
  END IF;
  r:=public.inventaire_reception_etat(moi);revision:=(r->>'revision')::bigint;
  SELECT data->'bonusCarrieres' INTO carrieres FROM public.armes_jets_referentiel WHERE pays=p.country LIMIT 1;
  IF carrieres IS NULL THEN RAISE EXCEPTION 'regles_carrieres_vol_absentes';END IF;
  per_cible:=coalesce(nullif((stats_cible->>'PER')::numeric,0),9);int_cible:=coalesce(nullif((stats_cible->>'INT')::numeric,0),9);
  INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,p.country||'_'||p.current_building,'voler',2,0);
  r:=public.payer_ordre(moi,'voler',2,0);IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(r->>'raison','paiement_refuse');END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE id=p.id) IS DISTINCT FROM p.pa-2 THEN RAISE EXCEPTION 'paiement_vol_non_confirme';END IF;
  bonus:=public.religion_benediction_consommer_interne(p.id,'vol',p_requete);alea:=public.vol_hasard_interne();
  IF alea IS NULL OR alea<0 OR alea>=1 OR alea::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'hasard_vol_invalide';END IF;
  score:=greatest(0,least(100,floor(50+public.personnage_stat_jet_interne(moi,'PER')+public.personnage_stat_jet_interne(moi,'CHA')-per_cible-int_cible+coalesce((carrieres->>p.career)::numeric,0)-public.personnage_securite_jet_interne(moi)/3+bonus+alea*50-25+.5)));
  succes:=score>=25;palier:=CASE WHEN score<25 THEN 'echec' WHEN score<50 THEN 'identifie' WHEN score<75 THEN 'anonyme' ELSE 'discret' END;v_id:='vol-'||p_requete::text;jour:=public.jour_de_jeu_pays(p.country);
  IF NOT succes THEN
   SELECT coalesce(solde,0) INTO p_banque FROM public.comptes_bancaires WHERE personnage=moi AND banque='nationale' FOR UPDATE;fonds:=coalesce(p.liquide,0)+coalesce(p_banque,0);
   amende:=CASE p.country WHEN 'republic' THEN least(300,fonds) WHEN 'narco' THEN floor(fonds*.5) WHEN 'soviet' THEN least(100,fonds) ELSE 0 END;
   IF amende>0 AND NOT public.helvetia_debiter_fonds_ordinaires(moi,amende) THEN RAISE EXCEPTION 'amende_vol_refusee';END IF;
   fonds_apres:=(SELECT coalesce(liquide,0) FROM public.personnages_donnees WHERE id=p.id)+coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=moi AND banque='nationale'),0);
   IF fonds_apres IS DISTINCT FROM fonds-amende THEN RAISE EXCEPTION 'amende_vol_non_confirmee';END IF;
   IF p.country='soviet' THEN perte_pop:=least(10,coalesce((p.resources->>'pop')::integer,0));UPDATE public.personnages_donnees SET resources=jsonb_set(coalesce(resources,'{}'),'{pop}',to_jsonb(greatest(0,coalesce((resources->>'pop')::integer,0)-10)),true) WHERE id=p.id;END IF;
   IF p.country='soviet' AND NOT EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.id=p.id AND (d.resources->>'pop')::integer=greatest(0,coalesce((p.resources->>'pop')::integer,0)-10)) THEN RAISE EXCEPTION 'sanction_pop_vol_non_confirmee';END IF;
   IF p.country IN('republic','khalija') THEN UPDATE public.personnages_donnees SET historique_crimes=coalesce(historique_crimes,'[]')||jsonb_build_array(jsonb_build_object('id',v_id,'acte','vol','cible',p_cible,'jour',jour,'expireJour',jour+CASE WHEN p.country='khalija' THEN 15 ELSE 8 END)) WHERE id=p.id;END IF;
   IF p.country IN('republic','khalija') AND NOT EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.id=p.id AND d.historique_crimes @> jsonb_build_array(jsonb_build_object('id',v_id))) THEN RAISE EXCEPTION 'historique_vol_non_confirme';END IF;
  ELSIF pj THEN
   IF p_genre='argent' THEN
    SELECT coalesce(solde,0) INTO v_banque FROM public.comptes_bancaires WHERE personnage=p_cible AND banque='nationale' FOR UPDATE;
    v_fonds:=coalesce(v.liquide,0)+coalesce(v_banque,0);
    IF v_fonds>0 THEN
     montant:=least(floor(random()*150)+50,v_fonds);
     -- Les colonnes historiques entières ne doivent pas arrondir silencieusement un solde.
     IF montant<>trunc(montant) OR v.liquide<>trunc(v.liquide) THEN RAISE EXCEPTION 'etat_financier_fractionnaire_a_examiner';END IF;
     IF NOT public.helvetia_debiter_fonds_ordinaires(p_cible,montant) THEN RAISE EXCEPTION 'debit_victime_refuse';END IF;
     PERFORM public.helvetia_crediter_destination(moi,montant,'liquide');
     UPDATE public.personnages_donnees SET arg=coalesce(arg,0)+montant,updated_at=clock_timestamp() WHERE id=p.id;
     IF (SELECT coalesce(liquide,0) FROM public.personnages_donnees WHERE id=p.id) IS DISTINCT FROM coalesce(p.liquide,0)+montant OR (SELECT coalesce(liquide,0) FROM public.personnages_donnees WHERE id=v.id)+coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=p_cible AND banque='nationale'),0) IS DISTINCT FROM v_fonds-montant THEN RAISE EXCEPTION 'transfert_vol_non_confirme';END IF;
     butin:='argent';
    END IF;
   ELSE
    IF jsonb_typeof(v.inventory) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'inventaire_victime_non_confirme';END IF;v_revision:=v.inventory_revision;
    SELECT e,ord::integer-1 INTO objet,pos FROM jsonb_array_elements(v.inventory) WITH ORDINALITY x(e,ord) WHERE coalesce(e->>'type','') NOT IN('acte_officiel','colis_secret_pat') AND (coalesce((e->>'stackable')::boolean,false) AND coalesce(e->>'stackKey','')<>'' OR e->>'origine'='objets_trouves' OR e->>'type'='arme') ORDER BY random() LIMIT 1;
    IF FOUND THEN
     IF coalesce((objet->>'stackable')::boolean,false) AND coalesce(objet->>'stackKey','')<>'' THEN
      IF coalesce((objet->>'qty')::numeric,1)<=0 OR coalesce((objet->>'qty')::numeric,1)<>trunc(coalesce((objet->>'qty')::numeric,1)) THEN RAISE EXCEPTION 'quantite_victime_invalide';END IF;
      qte:=least(floor(random()*5)::integer+1,coalesce((objet->>'qty')::integer,1));
      IF coalesce((objet->>'qty')::integer,1)=qte THEN nouvel_inv:=public.inventaire_retirer_position(v.inventory,pos);ELSE nouvel_inv:=jsonb_set(v.inventory,ARRAY[pos::text,'qty'],to_jsonb((objet->>'qty')::integer-qte));END IF;
      objet:=objet||jsonb_build_object('qty',qte);butin:='matiere';
     ELSE nouvel_inv:=public.inventaire_retirer_position(v.inventory,pos);qte:=1;butin:='objet';END IF;
     UPDATE public.personnages_donnees SET inventory=nouvel_inv,updated_at=clock_timestamp() WHERE id=v.id;
     IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.id=v.id AND d.inventory=nouvel_inv AND d.inventory_revision=v_revision+1) THEN RAISE EXCEPTION 'retrait_victime_non_confirme';END IF;
     INSERT INTO public.objets_recus(id,destinataire,expediteur,data) VALUES(v_id,moi,p_cible,objet) RETURNING reception_token INTO jeton;
     reception:=public.inventaire_reclamer_livraison(moi,v_id,jeton,revision);IF reception->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'reception_vol_non_confirmee';END IF;
    END IF;
   END IF;
   IF butin<>'rien' THEN
    INSERT INTO public.actions_tracables(id,auteur,cible,type_action,country,city,jour,jour_expiration) VALUES(v_id,moi,p_cible,'vol',p.country,p.current_city,jour,jour+7);
    IF NOT EXISTS(SELECT 1 FROM public.actions_tracables WHERE id=v_id AND auteur=moi AND cible=p_cible) THEN RAISE EXCEPTION 'trace_vol_non_confirmee';END IF;
    IF score<75 THEN PERFORM public.mail_systeme_poser_interne('Système',p_cible,'Vous avez été volé(e)',CASE WHEN score<50 THEN moi ELSE 'Quelqu''un' END||' vous a dérobé '||CASE WHEN butin='argent' THEN montant::text||' FR' ELSE coalesce(objet->>'name','un objet') END||CASE WHEN score<50 THEN '. Vous l''avez reconnu(e) sur le fait.' ELSE '. Vous n''avez pas pu identifier l''auteur.' END);END IF;
   END IF;
  END IF;
  -- PNJ : conserver l'issue sans butin du circuit actuel ; ne pas inventer sa distribution.
  r:=jsonb_build_object('ok',true,'succes',succes,'score',score,'palier',palier,'bonus',bonus,'cible',p_cible,'butin',butin,'montant',montant,'objet',objet,'quantite',qte,'amende',amende,'pertePop',perte_pop,'paPreleves',2);
  INSERT INTO public.vols_commandes_recus(acteur,requete,cible,genre,resultat) VALUES(p.id,p_requete,p_cible,p_genre,r);
  IF NOT EXISTS(SELECT 1 FROM public.vols_commandes_recus d WHERE d.acteur=p.id AND d.requete=p_requete AND d.resultat=r) THEN RAISE EXCEPTION 'recu_vol_non_confirme';END IF;
  DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;
  UPDATE public.personnages_donnees SET updated_at=clock_timestamp() WHERE id=p.id;
 END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 RETURN r||jsonb_build_object('pa',p.pa,'liquide',p.liquide,'arg',p.arg,'pop',coalesce((p.resources->>'pop')::integer,0),'historiqueCrimes',p.historique_crimes,'inventaire',public.inventaire_reception_etat(moi),'realites',public.religion_benediction_lire());
EXCEPTION WHEN SQLSTATE 'P0135' THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);
END;$f$;
COMMIT;
