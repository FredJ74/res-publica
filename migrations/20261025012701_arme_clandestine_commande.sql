-- L09 privé : moteur commercial et réception existants, aucune activation client.
BEGIN;
DO $g$ BEGIN
 IF to_regclass('public.armes_clandestines_recus') IS NOT NULL AND obj_description(to_regclass('public.armes_clandestines_recus')) IS DISTINCT FROM 'HG arme clandestine atomique #135 v1' THEN RAISE EXCEPTION 'registre_armes_clandestines_inconnu';END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='arme_clandestine_commande' AND (p.oid IS DISTINCT FROM to_regprocedure('public.arme_clandestine_commande(text,text,uuid)') OR md5(p.prosrc)<>'907007ebbc464d16e4c447e7c84622e9')) THEN RAISE EXCEPTION 'definition_non_examinee: arme_clandestine_commande';END IF;
END;$g$;
CREATE TABLE IF NOT EXISTS public.armes_clandestines_recus(acteur uuid NOT NULL,requete uuid NOT NULL,entreprise text NOT NULL,arme text NOT NULL,resultat jsonb NOT NULL,traitee_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(acteur,requete));
COMMENT ON TABLE public.armes_clandestines_recus IS 'HG arme clandestine atomique #135 v1';
ALTER TABLE public.armes_clandestines_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.armes_clandestines_recus FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.arme_clandestine_commande(p_entreprise text,p_arme text,p_requete uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();p record;catalogue record;ancien record;e jsonb;r jsonb;vente jsonb;objet jsonb;conv jsonb;
 prix numeric;stock numeric;v_banque numeric;fonds numeric;caisse numeric;bonus integer;jet integer;taux numeric;succes boolean;
 revision bigint;jeton uuid;livraison text;jour integer;v_id text;instant timestamptz:=statement_timestamp();
BEGIN
 IF moi IS NULL OR auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR coalesce(p_entreprise,'')='' OR coalesce(p_arme,'')='' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 IF NOT FOUND OR p.user_id IS DISTINCT FROM auth.uid() THEN RETURN jsonb_build_object('ok',false,'raison','personnage_non_possede');END IF;
 SELECT * INTO ancien FROM public.armes_clandestines_recus WHERE acteur=p.id AND requete=p_requete;
 IF FOUND THEN
  IF ancien.entreprise IS DISTINCT FROM p_entreprise OR ancien.arme IS DISTINCT FROM p_arme THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  r:=ancien.resultat||'{"rejeu":true}';
 ELSE
  IF coalesce(p.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(moi)) OR coalesce(p.hospitalisation->>'dateFinParis','')>(instant AT TIME ZONE 'Europe/Paris')::date::text THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
  SELECT * INTO catalogue FROM public.armes_jets_referentiel a WHERE a.pays=p.country AND a.ville=p.current_city AND a.batiment=p.current_building AND a.piece=p.current_room AND a.arme=p_arme;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place_ou_arme_inconnue');END IF;
  SELECT data INTO e FROM public.entreprises WHERE id=p_entreprise FOR UPDATE;
  IF NOT FOUND OR e->>'type'<>'armurerie' OR e->>'country' IS DISTINCT FROM p.country OR e->>'city' IS DISTINCT FROM p.current_city OR e->>'buildingId' IS DISTINCT FROM p.current_building OR nullif(e->>'roomId','') IS NOT NULL AND e->>'roomId'<>p.current_room THEN RETURN jsonb_build_object('ok',false,'raison','commerce_hors_contexte');END IF;
  stock:=coalesce((e->'stockProduits'->>p_arme)::numeric,0);prix:=(e->'parametres'->'prixVente'->>p_arme)::numeric*3;
  IF stock::text IN('NaN','Infinity','-Infinity') OR stock<>trunc(stock) THEN RETURN jsonb_build_object('ok',false,'raison','stock_invalide');END IF;
  IF stock<=0 THEN RETURN jsonb_build_object('ok',false,'raison','stock_insuffisant');END IF;
  IF prix IS NULL OR prix<0 OR prix::text IN('NaN','Infinity','-Infinity') THEN RETURN jsonb_build_object('ok',false,'raison','prix_non_defini');END IF;
  SELECT solde INTO v_banque FROM public.comptes_bancaires WHERE personnage=moi AND banque='nationale' FOR UPDATE;
  fonds:=coalesce(p.liquide,0)+coalesce(v_banque,0);caisse:=coalesce((e->>'caisse')::numeric,0);
  IF fonds<prix THEN RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants');END IF;
  r:=public.inventaire_reception_etat(moi);IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'inventaire_non_confirme';END IF;revision:=(r->>'revision')::bigint;
  bonus:=public.religion_benediction_consommer_interne(p.id,'achat_arme_illegal',p_requete);
  taux:=greatest(5,least(95,floor(50+coalesce((catalogue.data->'bonusCarrieres'->>p.career)::numeric,0)-public.personnage_securite_jet_interne(moi)/3+bonus+.5)));
  jet:=public.terrain_negociation_jet_interne();IF jet IS NULL OR jet NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'jet_invalide';END IF;succes:=jet<=taux;jour:=public.jour_de_jeu_pays(p.country);v_id:='arme-clandestine-'||p_requete::text;
  IF succes THEN
   INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,p.country||'_'||p.current_building,'choisir_arme',1,0);
   vente:=public.commerce_vendre_produit_interne(moi,p_entreprise,jsonb_build_array(jsonb_build_object('produit',p_arme,'qte',1)),'marche_noir','choisir_arme',1,0,NULL,NULL);
   IF vente->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(vente->>'raison','vente_refusee');END IF;
   IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.id=p.id AND d.pa=p.pa-1) OR (SELECT coalesce(liquide,0) FROM public.personnages_donnees WHERE id=p.id)+coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=moi AND banque='nationale'),0) IS DISTINCT FROM fonds-prix THEN RAISE EXCEPTION 'debit_arme_non_confirme';END IF;
   IF NOT EXISTS(SELECT 1 FROM public.entreprises d WHERE d.id=p_entreprise AND (d.data->'stockProduits'->>p_arme)::numeric=stock-1 AND coalesce((d.data->>'caisse')::numeric,0)=caisse) THEN RAISE EXCEPTION 'stock_arme_non_confirme';END IF;
   objet:=catalogue.data->'objet'||jsonb_build_object('id',v_id);livraison:=v_id;
   INSERT INTO public.objets_recus(id,destinataire,expediteur,data) VALUES(livraison,moi,'Armurerie',objet) RETURNING reception_token INTO jeton;
   vente:=vente||jsonb_build_object('reception',public.inventaire_reclamer_livraison(moi,livraison,jeton,revision));
   IF vente->'reception'->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'livraison_arme_non_confirmee';END IF;
   UPDATE public.personnages_donnees SET historique_crimes=coalesce(historique_crimes,'[]')||jsonb_build_array(jsonb_build_object('id',v_id,'acte','achat_arme_illegal','cible',NULL,'jour',jour,'expireJour',jour+8)),updated_at=clock_timestamp() WHERE id=p.id;
   INSERT INTO public.actions_tracables(id,auteur,cible,type_action,country,city,jour,jour_expiration) VALUES(v_id,moi,NULL,'achat_arme_illegal',p.country,p.current_city,jour,jour+7);
   IF NOT EXISTS(SELECT 1 FROM public.actions_tracables WHERE id=v_id AND auteur=moi) OR NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE id=p.id AND historique_crimes @> jsonb_build_array(jsonb_build_object('id',v_id))) THEN RAISE EXCEPTION 'trace_arme_non_confirmee';END IF;
  ELSE
   r:=public.recherche_inscrire(jsonb_build_object('id',v_id,'acte','achat_arme_illegal','type','delit_mineur','jour',jour));
   conv:=jsonb_build_object('id',v_id,'motif','achat_arme_illegal','jourEmission',jour,'heureEmission',extract(hour FROM instant AT TIME ZONE 'Europe/Paris')::integer,'jourLimite',jour+1,'heureLimite',extract(hour FROM instant AT TIME ZONE 'Europe/Paris')::integer,'limiteTs',instant+interval '24 hours','traitee',false);
   UPDATE public.personnages_donnees SET convocations=coalesce(convocations,'[]')||jsonb_build_array(conv),updated_at=clock_timestamp() WHERE id=p.id;
   IF r->>'ok' IS DISTINCT FROM 'true' OR NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE id=p.id AND recherche @> jsonb_build_array(jsonb_build_object('id',v_id)) AND convocations @> jsonb_build_array(conv)) THEN RAISE EXCEPTION 'convocation_arme_non_confirmee';END IF;
   PERFORM public.mail_systeme_poser_interne(CASE p.country WHEN 'republic' THEN 'Raoul Toufaud' WHEN 'narco' THEN 'El Capitan Gordo' WHEN 'soviet' THEN 'Camarade Borodine' ELSE 'Chambellan Ibn Protocole' END,moi,'Convocation officielle','L''armurier a refusé la vente et vous a dénoncé. Présentez-vous au commissariat sous 24h pour vous justifier, faute de quoi vous serez arrêté(e).');
  END IF;
  r:=jsonb_build_object('ok',true,'succes',succes,'jet',jet,'taux',taux,'bonus',bonus,'arme',p_arme,'objet',CASE WHEN succes THEN objet ELSE NULL END,'prix',CASE WHEN succes THEN prix ELSE 0 END,'paPreleves',CASE WHEN succes THEN 1 ELSE 0 END,'vente',vente,'convocation',conv);
  INSERT INTO public.armes_clandestines_recus(acteur,requete,entreprise,arme,resultat) VALUES(p.id,p_requete,p_entreprise,p_arme,r);
  IF NOT EXISTS(SELECT 1 FROM public.armes_clandestines_recus d WHERE d.acteur=p.id AND d.requete=p_requete AND d.resultat=r) THEN RAISE EXCEPTION 'recu_arme_non_confirme';END IF;
  DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;
 END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 RETURN r||jsonb_build_object('pa',p.pa,'arg',p.arg,'liquide',p.liquide,'inventaire',public.inventaire_reception_etat(moi),'convocations',p.convocations,'recherche',p.recherche,'historiqueCrimes',p.historique_crimes,'realites',public.religion_benediction_lire());
EXCEPTION WHEN SQLSTATE 'P0135' THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);
END;$f$;
REVOKE ALL ON FUNCTION public.arme_clandestine_commande(text,text,uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
