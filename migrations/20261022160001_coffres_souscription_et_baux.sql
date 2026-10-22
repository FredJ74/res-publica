-- #69 PREPAREE. Ancien debit separe ferme, cle du bail et inscription dans la meme transaction.
BEGIN;
DO $hist$ BEGIN
IF EXISTS(SELECT 1 FROM public.locations_actives b WHERE b.country='republic' AND b.data->>'city'='capitale' AND b.data->>'buildingId'='banque-nationale' AND b.data->>'roomId'='coffre_privatif' AND NOT EXISTS(SELECT 1 FROM public.coffres_bancaires c WHERE c.bail_id=b.id)) THEN RAISE EXCEPTION 'coffres_historiques_a_reconcilier';END IF;
IF NOT EXISTS(SELECT 1 FROM public.ordres_couts WHERE fn='louer_local' AND pa=1 AND cost=0) THEN RAISE EXCEPTION 'cout_louer_local_non_conforme';END IF;
END;$hist$;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.payer_ordre(text,text,integer,integer)');
IF h='484babaafa7271f5e4dc4040711d5db8' THEN
s:=replace(s,$a0$  PERFORM public.exiger_acteur(p_acteur);$a0$,$b0$  PERFORM public.exiger_acteur(p_acteur);
  IF v_fn='louer_local' AND EXISTS(SELECT 1 FROM public.personnages_donnees p WHERE p.name=p_acteur AND p.country='republic' AND p.current_city='capitale' AND p.current_building='banque-nationale' AND p.current_room='coffre_privatif'
    AND NOT EXISTS(SELECT 1 FROM public.coffres_couts_autorises a WHERE a.transaction_id=txid_current() AND a.personnage_id=p.id)) THEN
    RETURN jsonb_build_object('ok',false,'raison','coffre_versionne_requis');END IF;$b0$);
EXECUTE s;
ELSIF h IS DISTINCT FROM 'e47fb90a89d167f7cd74109f2d705e41' THEN RAISE EXCEPTION 'definition_non_examinee: payer_ordre(text,text,integer,integer)';END IF;
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.bail_cle_coherente()');
IF h='38f56c678edc959419da212e870b0951' THEN
s:=replace(s,$a0$DECLARE v_base text;$a0$,$b0$DECLARE v_base text;coffre public.coffres_bancaires;attendu jsonb;cle text;nom text;$b0$);
s:=replace(s,$a1$  IF public.est_appel_serveur() THEN RETURN NEW; END IF;$a1$,$b1$  SELECT * INTO coffre FROM public.coffres_bancaires WHERE bail_id=NEW.id;
  IF FOUND THEN
    SELECT name INTO nom FROM public.personnages_donnees WHERE id=coffre.titulaire_id;
    IF nom IS NULL THEN RAISE EXCEPTION 'coffre_titulaire_absent';END IF;
    attendu:=coffre.site||jsonb_build_object('coffreId',coffre.id::text,'locataire',nom,'periodicite','annuelle','prix',public.coffre_tarif_annuel_interne(coffre.taille),'tailleCoffre',coffre.taille);
    FOR cle IN SELECT jsonb_object_keys(attendu) LOOP
      IF NEW.data->cle IS DISTINCT FROM attendu->cle THEN RAISE EXCEPTION 'contrat_coffre_modifie' USING ERRCODE='42501';END IF;
    END LOOP;
    IF NEW.country IS DISTINCT FROM coffre.site->>'country' OR NEW.id IS DISTINCT FROM (coffre.site->>'country')||':'||(coffre.site->>'buildingId')||':'||(coffre.site->>'roomId')||':'||(coffre.site->>'city')||':coffre:'||coffre.id::text THEN RAISE EXCEPTION 'bail_cle_incoherente';END IF;
    RETURN NEW;
  END IF;
  IF TG_OP='INSERT' AND NEW.country='republic' AND NEW.data->>'city'='capitale' AND NEW.data->>'buildingId'='banque-nationale' AND NEW.data->>'roomId'='coffre_privatif' THEN RAISE EXCEPTION 'contrat_coffre_versionne_requis';END IF;
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;$b1$);
EXECUTE s;
ELSIF h IS DISTINCT FROM '3dbc6ff2886b7948b8a48d15babaee6d' THEN RAISE EXCEPTION 'definition_non_examinee: bail_cle_coherente()';END IF;
END;$p$;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_souscrire(text,text)');IF h IS NOT NULL AND h<>'c2ec0a56ed2115a4a05cbacbcc5959da' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_souscrire(text,text)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_catalogue()');IF h IS NOT NULL AND h<>'8dba4c07fc18a6fa0c69c674b3659cf1' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_catalogue()';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.coffre_souscrire(p_requete text,p_taille text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE n text:=public.mon_personnage();pj record;rec record;commande jsonb;r jsonb;id uuid;cle text;site jsonb;prix integer;jour date:=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;verdict text;
BEGIN
 IF n IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie';END IF;
 PERFORM public.inventaire_reception_etat(n);SELECT * INTO pj FROM public.personnages_donnees WHERE name=n;
 IF p_requete IS NULL OR p_requete !~ '^coffre-[A-Za-z0-9-]{8,100}$' THEN RAISE EXCEPTION 'requete_invalide';END IF;
 commande:=jsonb_build_object('action','souscrire','taille',p_taille);
 SELECT * INTO rec FROM public.coffres_requetes WHERE personnage_id=pj.id AND requete=p_requete;
 IF FOUND THEN
  IF rec.commande IS DISTINCT FROM commande THEN RAISE EXCEPTION 'requete_reutilisee';END IF;
  RETURN rec.resultat||jsonb_build_object('rejeu',true);
 END IF;
 IF pj.country IS DISTINCT FROM 'republic' OR pj.current_city IS DISTINCT FROM 'capitale' OR pj.current_building IS DISTINCT FROM 'banque-nationale' OR pj.current_room IS DISTINCT FROM 'coffre_privatif' THEN RAISE EXCEPTION 'pas_sur_place';END IF;
 IF coalesce(pj.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(n)) OR coalesce(pj.hospitalisation->>'dateFinParis','')>jour::text THEN RAISE EXCEPTION 'acteur_indisponible';END IF;
 prix:=public.coffre_tarif_annuel_interne(p_taille);
 IF prix IS NULL THEN RAISE EXCEPTION 'taille_invalide';END IF;
 -- Le cout PA passe par le moteur commun, autorise uniquement dans cette transaction privee.
 INSERT INTO public.coffres_couts_autorises VALUES(txid_current(),pj.id);
 r:=public.payer_ordre(n,'louer_local',1,0);
 DELETE FROM public.coffres_couts_autorises WHERE transaction_id=txid_current() AND personnage_id=pj.id;
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'cout_souscription_refuse';END IF;
 id:=gen_random_uuid();cle:='republic:banque-nationale:coffre_privatif:capitale:coffre:'||id::text;
 site:=jsonb_build_object('country',pj.country,'city',pj.current_city,'buildingId',pj.current_building,'roomId',pj.current_room);
 INSERT INTO public.coffres_bancaires(id,bail_id,titulaire_id,site,taille,debut_annuel,renouvellement_annuel)
 VALUES(id,cle,pj.id,site,p_taille,jour,(jour+interval '1 year')::date);
 INSERT INTO public.locations_actives(id,country,data) VALUES(cle,pj.country,site||jsonb_build_object('coffreId',id::text,'tailleCoffre',p_taille,'periodicite','annuelle','prix',prix,'locataire',n,'locataireRef','pj:'||n,'orgaId','','depuis',pj.day,'localLabel','Coffre bancaire '||p_taille));
 verdict:=public.prelever_loyer_bail(cle);
 IF verdict IS DISTINCT FROM 'paye' THEN RAISE EXCEPTION 'premier_loyer_refuse';END IF;
 r:=jsonb_build_object('ok',true,'coffre',id,'taille',p_taille,'capacite',public.coffre_capacite_interne(p_taille),'tarifAnnuel',prix,'renouvellementAnnuel',(jour+interval '1 year')::date);
 INSERT INTO public.coffres_requetes(personnage_id,requete,commande,resultat) VALUES(pj.id,p_requete,commande,r);
 RETURN r;
EXCEPTION WHEN raise_exception THEN
 IF SQLERRM=ANY(ARRAY['acteur_non_authentifie','requete_invalide','requete_reutilisee','pas_sur_place','acteur_indisponible','taille_invalide','cout_souscription_refuse','premier_loyer_refuse']) THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);END IF;RAISE;
END;$f$;
CREATE OR REPLACE FUNCTION public.coffre_catalogue()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE n text:=public.mon_personnage();p uuid;offres jsonb;contrats jsonb;
BEGIN
 IF n IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 SELECT id INTO p FROM public.personnages_donnees WHERE name=n AND user_id=auth.uid();
 IF p IS NULL THEN RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE='42501';END IF;
 SELECT jsonb_agg(jsonb_build_object('taille',t,'capacite',public.coffre_capacite_interne(t),'tarifAnnuel',public.coffre_tarif_annuel_interne(t)) ORDER BY rang) INTO offres FROM unnest(ARRAY['S','M','L','XL']) WITH ORDINALITY x(t,rang);
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',c.id,'taille',c.taille,'capacite',public.coffre_capacite_interne(c.taille),'occupation',public.inventaire_occupation_unites(c.contenu),'revisionCoffre',c.revision,'tarifAnnuel',public.coffre_tarif_annuel_interne(c.taille),'renouvellementAnnuel',c.renouvellement_annuel,'impaye',c.loyer_impaye,'gele',c.succession_id IS NOT NULL) ORDER BY c.cree_le,c.id),'[]') INTO contrats FROM public.coffres_bancaires c WHERE c.titulaire_id=p;
 RETURN jsonb_build_object('ok',true,'offres',offres,'coffres',contrats);
END;$f$;
REVOKE ALL ON FUNCTION public.coffre_souscrire(text,text),public.coffre_catalogue() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coffre_souscrire(text,text),public.coffre_catalogue() TO authenticated;
COMMIT;
