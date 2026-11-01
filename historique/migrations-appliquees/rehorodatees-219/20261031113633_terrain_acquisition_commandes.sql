-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261024123700_terrain_acquisition_commandes.sql ; aucun changement de règle.
-- Acquisition : intentions seulement ; prix, versements, titres et historique par les moteurs existants.
BEGIN;
DO $nouveau$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='terrain_acquisition_commande' AND (p.oid IS DISTINCT FROM to_regprocedure('public.terrain_acquisition_commande(text,text,jsonb,uuid)') OR md5(p.prosrc)<>'c17c1bf98d1b64ba5fada309718b3999')) THEN RAISE EXCEPTION 'definition_non_examinee: terrain_acquisition_commande';END IF;END;$nouveau$;

CREATE OR REPLACE FUNCTION public.terrain_acquisition_commande(p_terrain text,p_action text,p_parametres jsonb,p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();p record;t record;a record;fiche record;e jsonb;r jsonb;patch jsonb;params jsonb:=coalesce(p_parametres,'{}');prix numeric;surface numeric;montant numeric;pa integer;ordre text;ms numeric:=floor(extract(epoch FROM clock_timestamp())*1000);date_rdv numeric;terme integer;conjoint text;pret jsonb;permis text;
BEGIN
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR p_action IS NULL OR p_action NOT IN('depot','compromis','acte_direct','acte_compromis') OR jsonb_typeof(params)<>'object' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 IF EXISTS(SELECT 1 FROM jsonb_object_keys(params) k WHERE k NOT IN('occupation','pret','permis')) THEN RETURN jsonb_build_object('ok',false,'raison','parametre_non_autorise');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 SELECT * INTO a FROM public.terrain_acquisitions_recus WHERE acteur=moi AND requete=p_requete;
 IF FOUND THEN
  IF (a.terrain,a.action,a.parametres) IS DISTINCT FROM (p.country||'_'||p_terrain,p_action,params) THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  SELECT data::jsonb INTO e FROM public.terrains_etat WHERE id=a.terrain;
  RETURN a.resultat||jsonb_build_object('rejeu',true,'etat',e);
 END IF;
 IF coalesce(p.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(moi)) OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE id=p.country||'_'||p_terrain AND country=p.country AND building_id=p_terrain FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable');END IF;e:=t.data::jsonb;
 IF coalesce(e->>'succession_gel','')<>'' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele');END IF;
 IF e->>'proprietaire'='Helvetia' THEN RETURN jsonb_build_object('ok',false,'raison','circuit_helvetia_requis');END IF;
 IF p_action IN('depot','compromis') THEN
  IF p.current_building IS DISTINCT FROM p_terrain OR p.current_city IS DISTINCT FROM e->>'city' THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
  IF nullif(e->>'proprietaire','') IS NOT NULL OR coalesce((e->>'compromis')::boolean,false) OR jsonb_typeof(e->'achatDirect')='object' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_indisponible');END IF;
  IF coalesce(e->>'pnj','')<>'' OR coalesce(e->>'policeAppellee','')<>'' OR coalesce((e->>'enqueteJusqua')::numeric,0)>ms THEN RETURN jsonb_build_object('ok',false,'raison','terrain_occupe');END IF;
  IF params->>'occupation' IS DISTINCT FROM coalesce(e->>'dateGeneration','historique')||':'||coalesce(e->>'pnj','') THEN RETURN jsonb_build_object('ok',false,'raison','occupation_modifiee');END IF;
  SELECT * INTO fiche FROM public.terrains_referentiel WHERE pays=t.country AND ville=e->>'city' AND batiment=t.building_id;
  surface:=coalesce((e->>'surface')::numeric,fiche.surface);prix:=coalesce((e->>'valeur_totale')::numeric,fiche.prix_achat);
  IF surface IS NULL OR surface<=0 OR surface::text IN('NaN','Infinity','-Infinity') OR prix IS NULL OR prix<1000 OR prix<>trunc(prix) OR prix::text IN('NaN','Infinity','-Infinity') THEN RETURN jsonb_build_object('ok',false,'raison','prix_ou_surface_non_reference');END IF;
  pret:=params->'pret';permis:=params->>'permis';
  IF jsonb_typeof(pret)='object' THEN
   IF p_action<>'compromis' OR (pret->>'montant')::numeric<1000 OR (pret->>'montant')::numeric>150000 OR (pret->>'montant')::numeric<>trunc((pret->>'montant')::numeric) OR (pret->>'duree')::numeric<>trunc((pret->>'duree')::numeric) OR (pret->>'duree')::integer<=0 OR NOT(pret ? 'montant' AND pret ? 'duree') THEN RETURN jsonb_build_object('ok',false,'raison','pret_invalide');END IF;
   pret:=jsonb_build_object('demandeur',moi,'montant',(pret->>'montant')::numeric,'duree',(pret->>'duree')::integer,'taux',CASE WHEN p.country='republic' THEN public.taux_pret_nationale(p.country) ELSE (SELECT 5+(data->'indices'->p.country->>'IE')::numeric/10 FROM public.terrain_actions_regles WHERE id) END,'statut','attente_validation');
  ELSIF pret IS NOT NULL AND pret<>'null'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','pret_invalide');END IF;
  IF permis IS NOT NULL AND (p_action<>'compromis' OR permis NOT IN('hangar','commerce_standard','commerce_premium','building')) THEN RETURN jsonb_build_object('ok',false,'raison','palier_invalide');END IF;
  montant:=1000;pa:=2;ordre:=CASE p_action WHEN 'depot' THEN 'acheter_terrain' ELSE 'signer_compromis' END;
 ELSE
  IF p.current_building IS DISTINCT FROM 'office-notarial' OR p.current_city IS DISTINCT FROM 'capitale' THEN RETURN jsonb_build_object('ok',false,'raison','pas_chez_notaire');END IF;
  IF nullif(e->>'proprietaire','') IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison','deja_acquis');END IF;
  IF p_action='acte_direct' THEN
   IF e->'achatDirect'->>'demandeur' IS DISTINCT FROM moi THEN RETURN jsonb_build_object('ok',false,'raison','pas_mon_achat_direct');END IF;
   IF e->'achatDirect'->>'dateAchat' IS NULL OR e->'achatDirect'->>'dateLimite' IS NULL OR ms<(e->'achatDirect'->>'dateAchat')::numeric OR ms>(e->'achatDirect'->>'dateLimite')::numeric THEN RETURN jsonb_build_object('ok',false,'raison','rendez_vous_hors_delai');END IF;
   prix:=(e->'achatDirect'->>'prix')::numeric;montant:=prix-(e->'achatDirect'->>'acompte')::numeric;
  ELSE
   IF e->>'compromis' IS DISTINCT FROM 'true' OR e->>'compromisPar' IS DISTINCT FROM moi THEN RETURN jsonb_build_object('ok',false,'raison','pas_mon_compromis');END IF;
   IF e->'pretDemande'->>'statut'='attente_validation' AND (e->>'compromisExpireAt')::numeric<=ms THEN
    r:=public.compromis_expire_resoudre('terrain',t.id);SELECT data::jsonb INTO e FROM public.terrains_etat WHERE id=t.id;
   END IF;
   IF e->>'compromis' IS DISTINCT FROM 'true' OR (e->>'compromisExpireAt')::numeric<=ms AND e->'pretDemande'->>'statut' IS DISTINCT FROM 'accorde' THEN RETURN jsonb_build_object('ok',false,'raison','compromis_expire');END IF;
   IF e->'pretDemande'->>'statut' IS NOT NULL AND e->'pretDemande'->>'statut'<>'accorde' OR e->'permis'->>'statut' IN('instruction','attente_validation','refuse') THEN RETURN jsonb_build_object('ok',false,'raison','clauses_non_acquises');END IF;
   prix:=(e->>'valeur_totale')::numeric;montant:=prix-coalesce((e->>'acompte')::numeric,0);
  END IF;
  surface:=(e->>'surface')::numeric;pa:=1;ordre:='acte_vente_terrain';
 END IF;
 IF montant IS NULL OR montant<0 OR montant<>trunc(montant) THEN RETURN jsonb_build_object('ok',false,'raison','montant_invalide');END IF;
 -- Tout echec apres le premier paiement leve : debit, credit, permis, titre et recu disparaissent ensemble.
 INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,t.id,ordre,pa,montant);
 r:=public.payer_ordre(moi,ordre,pa,montant::integer);IF r->>'ok' IS DISTINCT FROM 'true' THEN DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;RETURN r;END IF;
 IF p_action='depot' THEN
  terme:=2+floor(random()*6)::integer;date_rdv:=extract(epoch FROM (((clock_timestamp() AT TIME ZONE 'Europe/Paris')+make_interval(days=>terme)) AT TIME ZONE 'Europe/Paris'))*1000;
  patch:=jsonb_build_object('achatDirect',jsonb_build_object('demandeur',moi,'acompte',1000,'prix',prix,'surface',surface,'dateAchat',date_rdv,'dateLimite',date_rdv+86400000));
  r:=public.terrain_compromis_acte(t.id,'achat_direct_deposer',patch);
 ELSIF p_action='compromis' THEN
  patch:=jsonb_build_object('compromis',true,'compromisPar',moi,'acompte',1000,'compromisAt',ms,'compromisExpireAt',floor(extract(epoch FROM (((clock_timestamp() AT TIME ZONE 'Europe/Paris')+interval '7 days') AT TIME ZONE 'Europe/Paris'))*1000),'pretDemande',pret);
  r:=public.terrain_compromis_acte(t.id,'compromis_signer',patch);
 ELSE
  SELECT CASE WHEN conjoint1=moi THEN conjoint2 ELSE conjoint1 END INTO conjoint FROM public.mariages WHERE statut='actif' AND (conjoint1=moi OR conjoint2=moi) LIMIT 1;
  patch:=jsonb_build_object('proprietaire',moi,'coproprietaire',conjoint,'acheteAt',ms,'surface',surface,'valeur_totale',prix,'dette_fonciere',0,'city',e->>'city','constructionAutorisee',coalesce((e->>'constructionAutorisee')::boolean,false));
  patch:=patch||CASE p_action WHEN 'acte_direct' THEN '{"achatDirect":null}'::jsonb ELSE '{"compromis":null,"compromisPar":null,"acompte":null,"compromisAt":null,"compromisExpireAt":null}'::jsonb END;
  r:=public.terrain_proprietaire_muter(t.id,CASE p_action WHEN 'acte_direct' THEN 'achat_direct' ELSE 'compromis' END,patch,p_requete::text);
 END IF;
 IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING MESSAGE=coalesce(r->>'raison','acquisition_refusee');END IF;
 e:=r->'etat';
 e:=public.terrain_etat_fusionner_interne(t.id,jsonb_build_object('acquisitionVersion',2,'acquisitionRequete',p_requete,'surface',surface,'valeur_totale',prix),p.country);
 IF p_action='compromis' AND permis IS NOT NULL THEN
  r:=public.terrain_permis_deposer(p_terrain,permis,p_requete);IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING MESSAGE=coalesce(r->>'raison','permis_non_confirme');END IF;e:=r->'etat';
 END IF;
 r:=jsonb_build_object('ok',true,'action',p_action,'montant',montant,'prix',prix,'etat',e,'pretCapture',pret);
 INSERT INTO public.terrain_acquisitions_recus VALUES(moi,p_requete,t.id,p_action,params,r-'etat');
 DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;
 UPDATE public.personnages_donnees SET updated_at=clock_timestamp() WHERE name=moi;
 RETURN r;
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_acquisition_commande(text,text,jsonb,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.terrain_acquisition_commande(text,text,jsonb,uuid) TO authenticated;
COMMIT;
