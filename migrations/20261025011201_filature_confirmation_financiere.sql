-- Confirmer les écritures réellement effectuées, même si un trigger les ignore.
-- Composant privé L09, aucun octroi de droit ni activation client.
BEGIN;
DO $g$ DECLARE h text;BEGIN
 SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.police_filature_commande(text,uuid)');
 IF h IS NULL OR h NOT IN('b9fb18b681d2f59a9d0cadfb74da364c','646fca07f84d381130d96b52a24c0ed4') THEN RAISE EXCEPTION 'definition_non_examinee: police_filature_commande';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.police_filature_commande(p_cible text,p_requete uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();p record;site record;ancien record;r jsonb;rapport jsonb;bonus integer;jet integer;taux numeric;per_cible numeric;inf_cible numeric;cible text:=btrim(coalesce(p_cible,''));solde numeric;
BEGIN
 IF moi IS NULL OR auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR cible='' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 IF NOT FOUND OR p.user_id IS DISTINCT FROM auth.uid() THEN RETURN jsonb_build_object('ok',false,'raison','personnage_non_possede');END IF;
 -- Le registre du poste décide, pas son badge de présentation.
 IF NOT EXISTS(SELECT 1 FROM public.postes_attribues a WHERE a.country=p.country AND a.poste_id='commissaire' AND a.city=p.current_city AND a.titulaire IN(moi,'pj:'||moi)) THEN RETURN jsonb_build_object('ok',false,'raison','commissaire_hors_juridiction');END IF;
 SELECT * INTO site FROM public.ordres_jets_sites s WHERE s.pays=p.country AND s.ville=p.current_city AND s.batiment=p.current_building AND s.piece=p.current_room AND s.ordre='organiser_filature' AND s.poste='commissaire';
 IF NOT FOUND OR site.caisse IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 SELECT * INTO ancien FROM public.police_filatures_recus WHERE acteur=p.id AND requete=p_requete;
 IF FOUND THEN
  IF ancien.cible IS DISTINCT FROM cible THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  r:=ancien.resultat||'{"rejeu":true}';
 ELSE
  IF coalesce(p.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(moi)) OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
  SELECT coalesce(nullif((d.stats->>'PER')::numeric,0),8),coalesce(d.inf,0) INTO per_cible,inf_cible FROM public.personnages_donnees d WHERE d.name=cible;
  -- Formule actuelle de filature : aucune caractéristique ni chance envoyée par le navigateur.
  taux:=50+2*(public.personnage_stat_jet_interne(moi,'PER')-13)-(coalesce(per_cible,8)-13)
    +(public.personnage_securite_jet_interne(moi)-50)/5+(coalesce(p.inf,0)-coalesce(inf_cible,0))*.3;
  SELECT coalesce((data->>'solde')::numeric,0) INTO solde FROM public.caisses_batiments WHERE id=site.caisse FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','caisse_introuvable');END IF;
  INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,p.country||'_'||p.current_building,'organiser_filature',site.pa,0);
  r:=public.payer_ordre(moi,'organiser_filature',site.pa,0);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(r->>'raison','paiement_refuse');END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE id=p.id) IS DISTINCT FROM p.pa-site.pa THEN RAISE EXCEPTION 'paiement_filature_non_confirme';END IF;
  r:=public.caisse_client_mouvement(site.caisse,-site.cout,'organiser_filature',false);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(r->>'raison','caisse_insuffisante');END IF;
  IF (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id=site.caisse) IS DISTINCT FROM solde-site.cout THEN RAISE EXCEPTION 'caisse_filature_non_confirmee';END IF;
  bonus:=public.religion_benediction_consommer_interne(p.id,'organiser_filature',p_requete);
  taux:=greatest(10,least(90,floor(taux+bonus+.5)));jet:=public.terrain_negociation_jet_interne();
  IF jet IS NULL OR jet NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'jet_invalide';END IF;
  IF jet<=taux THEN
   rapport:=public.filature_deplacements(cible);
   IF rapport->>'ok' IS DISTINCT FROM 'true' OR jsonb_typeof(rapport->'deplacements') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'rapport_filature_non_confirme';END IF;
  END IF;
  r:=jsonb_build_object('ok',true,'succes',jet<=taux,'jet',jet,'taux',taux,'bonus',bonus,'cible',cible,'cout',site.cout,'paPreleves',site.pa,
   'rapportA',clock_timestamp(),'deplacements',rapport->'deplacements','horodatagesInconnus',CASE WHEN jet<=taux THEN(SELECT count(*) FROM public.historique_deplacements h WHERE h.name=cible AND h.created_at IS NULL) ELSE 0 END);
  INSERT INTO public.police_filatures_recus VALUES(p.id,p_requete,cible,r,clock_timestamp());
  DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;
  UPDATE public.personnages_donnees SET updated_at=clock_timestamp() WHERE name=moi;
 END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 RETURN r||jsonb_build_object('pa',p.pa,'liquide',p.liquide,'arg',p.arg,'solde_caisse',(SELECT data->'solde' FROM public.caisses_batiments WHERE id=site.caisse),'realites',public.religion_benediction_lire());
EXCEPTION WHEN SQLSTATE 'P0135' THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);
END;$f$;
COMMIT;
