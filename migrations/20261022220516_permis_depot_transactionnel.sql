-- #94 / #57 PREPAREE : depot de permis indivisible. Aucun deploiement sans prevol reel.
-- Les gardes refusent une definition vivante differente de celle examinee.
BEGIN;
CREATE TABLE IF NOT EXISTS public.permis_transactions_internes (
 transaction_id bigint PRIMARY KEY, acteur uuid NOT NULL
);
ALTER TABLE public.permis_transactions_internes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.permis_transactions_internes FROM PUBLIC,anon,authenticated;
DO $guard$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.payer_ordre(text,text,integer,integer)') AND md5(prosrc) IN ('92234a6b14ff176d2c2c2236f705683e','9a461bfc3c33f04f342ce6f5586393a7')) THEN RAISE EXCEPTION 'definition_non_examinee: public.payer_ordre(text,text,integer,integer)'; END IF;
END;$guard$;
DO $patch$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef(to_regprocedure('public.payer_ordre(text,text,integer,integer)')) INTO d;
 IF position($needle$  IF v_fn = 'deposer_demande_permis' AND NOT EXISTS (
    SELECT 1 FROM public.permis_transactions_internes WHERE transaction_id=txid_current() AND acteur=auth.uid()
  ) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise'); END IF;
$needle$ IN d)=0 THEN
 EXECUTE replace(d,$needle$  PERFORM public.exiger_acteur(p_acteur);$needle$,$needle$  IF v_fn = 'deposer_demande_permis' AND NOT EXISTS (
    SELECT 1 FROM public.permis_transactions_internes WHERE transaction_id=txid_current() AND acteur=auth.uid()
  ) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise'); END IF;
  PERFORM public.exiger_acteur(p_acteur);$needle$);
 END IF;
END;$patch$;
DO $guard$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.terrain_permis_acte(text,text,jsonb)') AND md5(prosrc) IN ('bb14432f6064d189cdf9b3b85637f844','e52c2c7a16a7c13588e7dba99b39a513')) THEN RAISE EXCEPTION 'definition_non_examinee: public.terrain_permis_acte(text,text,jsonb)'; END IF;
END;$guard$;
DO $patch$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef(to_regprocedure('public.terrain_permis_acte(text,text,jsonb)')) INTO d;
 IF position($needle$  IF p_acte = 'permis_deposer' THEN
    RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');
  END IF;
$needle$ IN d)=0 THEN
 EXECUTE replace(d,$needle$  v_moi := public.mon_personnage();$needle$,$needle$  IF p_acte = 'permis_deposer' THEN
    RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');
  END IF;
  v_moi := public.mon_personnage();$needle$);
 END IF;
END;$patch$;
-- Le registre des couts reste la source du payeur commun. Refus de tout etat inattendu.
DO $g$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ordres_couts WHERE fn='deposer_demande_permis')
 OR EXISTS(SELECT 1 FROM public.ordres_couts WHERE fn='deposer_demande_permis' AND (pa,cost) NOT IN ((2,0),(1,100)))
 THEN RAISE EXCEPTION 'cout_permis_non_examine'; END IF;
END;$g$;
UPDATE public.ordres_couts SET pa=1,cost=100 WHERE fn='deposer_demande_permis';
CREATE TABLE IF NOT EXISTS public.permis_depots_recus (
 acteur uuid NOT NULL, requete uuid NOT NULL, archive text NOT NULL UNIQUE,
 PRIMARY KEY(acteur,requete)
);
ALTER TABLE public.permis_depots_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.permis_depots_recus FROM PUBLIC,anon,authenticated;
-- Les depots de permis ne doivent plus etre forgés via INSERT direct dans l'archive.
-- Les autres evenements d'urbanisme historiques restent inchanges dans ce lot.
CREATE OR REPLACE FUNCTION public.permis_depot_archive_proteger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $g$
BEGIN
 IF NEW.type_evenement='depot' AND NOT EXISTS(
  SELECT 1 FROM public.permis_transactions_internes
  WHERE transaction_id=txid_current() AND acteur=auth.uid()
 ) THEN RAISE EXCEPTION 'depot_permis_commande_versionnee_requise'; END IF;
 RETURN NEW;
END;$g$;
REVOKE ALL ON FUNCTION public.permis_depot_archive_proteger() FROM PUBLIC,anon,authenticated;
DO $guard$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.dossiers_urbanisme'::regclass
 AND tgname='permis_depot_archive_versionnee') THEN
 CREATE TRIGGER permis_depot_archive_versionnee
 BEFORE INSERT ON public.dossiers_urbanisme FOR EACH ROW
 EXECUTE FUNCTION public.permis_depot_archive_proteger();
 END IF;
END;$guard$;
DO $nouveau$ BEGIN
 IF to_regprocedure('public.terrain_permis_deposer(text,text,uuid)') IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.terrain_permis_deposer(text,text,uuid)')
  AND md5(prosrc)='fe477be60c077cee84331a80426dc22b') THEN RAISE EXCEPTION 'definition_non_examinee: terrain_permis_deposer'; END IF;
END;$nouveau$;
CREATE OR REPLACE FUNCTION public.terrain_permis_deposer(p_terrain text,p_palier text,p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text:=public.mon_personnage(); identite uuid:=auth.uid(); pays text;ville text;jour integer;
 lu jsonb; etat jsonb; permis jsonb; precedent jsonb;doc jsonb; paiement jsonb;reception jsonb;
 duree integer; reference text; batiment text;
BEGIN
 IF acteur IS NULL OR identite IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_requete IS NULL OR nullif(btrim(p_terrain),'') IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide'); END IF;
 duree:=CASE p_palier WHEN 'hangar' THEN 2 WHEN 'commerce_standard' THEN 4 WHEN 'commerce_premium' THEN 6 WHEN 'building' THEN 7 END;
 IF duree IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','palier_invalide'); END IF;
 -- Meme ordre de verrous que les commandes financieres : personnage, requete, terrain.
 SELECT country,current_city INTO pays,ville FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable'); END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('permis:'||identite::text||':'||p_requete::text,0));
 reference:='urb-depot-'||identite::text||'-'||p_requete::text;
 SELECT d.data INTO precedent FROM public.permis_depots_recus r
 JOIN public.dossiers_urbanisme d ON d.id=r.archive
 WHERE r.acteur=identite AND r.requete=p_requete;
 IF FOUND THEN
  IF precedent->>'buildingId' IS DISTINCT FROM p_terrain
     OR precedent->>'palier' IS DISTINCT FROM p_palier OR precedent->>'demandeur' IS DISTINCT FROM acteur THEN
   RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');
  END IF;
  -- La preuve du debit reste l'archive, jamais une nouvelle livraison au rejeu.
  SELECT jsonb_build_object('pa',p.pa,'arg',p.arg,'liquide',p.liquide,
   'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=acteur AND banque='nationale'),0))
   INTO paiement FROM public.personnages_donnees p WHERE p.name=acteur;
  lu:=public.terrain_etat_verrouiller_interne((precedent->>'pays')||'_'||p_terrain);
  RETURN jsonb_build_object('ok',true,'rejeu',true,'document',precedent,'etat',lu->'etat','paiement',paiement);
 END IF;
 -- Une cle canonique pays/batiment evite de choisir un terrain homonyme d'un autre pays.
 SELECT building_id INTO batiment FROM public.terrains_etat WHERE id=pays||'_'||p_terrain AND country=pays;
 IF batiment IS DISTINCT FROM p_terrain THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
 lu:=public.terrain_etat_verrouiller_interne(pays||'_'||p_terrain);etat:=lu->'etat';
 IF coalesce((lu->>'gele')::boolean,true) THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele'); END IF;
 IF etat->>'city' IS DISTINCT FROM ville OR ville IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','hors_juridiction'); END IF;
 IF public.titulaire_est_moi(etat->>'proprietaire') IS NOT TRUE THEN
  IF etat->>'compromis' IS DISTINCT FROM 'true' OR etat->>'compromisPar' IS DISTINCT FROM acteur THEN
   RETURN jsonb_build_object('ok',false,'raison','pas_titulaire'); END IF;
  IF jsonb_typeof(etat->'compromisExpireAt') IS DISTINCT FROM 'number' THEN
   RETURN jsonb_build_object('ok',false,'raison','compromis_expiration_inconnue'); END IF;
  IF (etat->>'compromisExpireAt')::numeric<=extract(epoch FROM clock_timestamp())*1000 THEN
   RETURN jsonb_build_object('ok',false,'raison','compromis_expire'); END IF;
 END IF;
 IF nullif(etat->>'niveau_construction','') IS NOT NULL OR jsonb_typeof(etat->'chantier')='object' THEN
  RETURN jsonb_build_object('ok',false,'raison','deja_construit'); END IF;
 permis:=etat->'permis';jour:=public.jour_de_jeu_pays(pays);
 IF jour IS NULL THEN RAISE EXCEPTION 'calendrier_indisponible'; END IF;
 IF permis->>'statut' IN ('instruction','attente_validation','valide') THEN
  RETURN jsonb_build_object('ok',false,'raison','permis_existant'); END IF;
 IF permis->>'statut'='refuse' AND permis->>'jourRefus' IS NOT NULL
    AND jour<(permis->>'jourRefus')::integer+3 THEN
  RETURN jsonb_build_object('ok',false,'raison','cooldown_refus'); END IF;
 permis:=jsonb_build_object('demandeur',acteur,'palierDemande',p_palier,'dateDepot',jour,
  'dureeInstruction',duree,'joursInstructionFaits',0,'dateInstructionTerminee',jour+duree,
  'statut','instruction','numeroDossier','URB-'||pays||'-'||p_terrain||'-'||p_requete::text,'decoupageInitial','[]'::jsonb);
 INSERT INTO public.permis_transactions_internes VALUES(txid_current(),identite);
 paiement:=public.payer_ordre(acteur,'deposer_demande_permis',1,100);
 DELETE FROM public.permis_transactions_internes WHERE transaction_id=txid_current();
 IF paiement->>'ok' IS DISTINCT FROM 'true' THEN RETURN paiement; END IF;
 etat:=public.terrain_etat_fusionner_interne(pays||'_'||p_terrain,jsonb_build_object('permis',permis),pays);
 doc:=jsonb_build_object('id',reference,'nature','depot','numeroDossier',permis->>'numeroDossier',
  'jour',jour,'jourDepot',jour,'demandeur',acteur,'pays',pays,'ville',ville,
  'buildingId',p_terrain,'palier',p_palier,'palierLabel',CASE p_palier WHEN 'hangar' THEN 'Hangar'
   WHEN 'commerce_standard' THEN 'Commerce standard' WHEN 'commerce_premium' THEN 'Commerce premium' ELSE 'Building' END,
  'surfaceExploitable',etat->'surface','decoupage','[]'::jsonb);
 INSERT INTO public.dossiers_urbanisme(id,country,city,building_id,numero_dossier,type_evenement,demandeur,jour,libelle,data)
 VALUES(reference,pays,ville,p_terrain,permis->>'numeroDossier','depot',acteur,jour,'Depot de demande de permis',doc);
 reception:=public.objet_sas_deposer('document_urbanisme',acteur,jsonb_build_object('id',reference,
  'type','document_urbanisme_depot','name','Recepisse de demande de permis','icon','ti-file-text','legal',true,'documentUrbanisme',doc),reference);
 IF reception->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'document_non_confirme'; END IF;
 INSERT INTO public.permis_depots_recus VALUES(identite,p_requete,reference);
 RETURN jsonb_build_object('ok',true,'etat',etat,'document',doc,'paiement',paiement);
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_permis_deposer(text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.terrain_permis_deposer(text,text,uuid) TO authenticated;
COMMIT;
