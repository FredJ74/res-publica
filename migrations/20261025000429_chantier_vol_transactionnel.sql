-- #135 / L09 : acte hôte privé. Ne pas exposer avant raccordement et fermeture des chemins historiques.
BEGIN;
DO $g$ BEGIN
 IF to_regclass('public.chantier_vols_recus') IS NOT NULL AND obj_description(to_regclass('public.chantier_vols_recus')) IS DISTINCT FROM 'HG chantier vol atomique #135 v1' THEN RAISE EXCEPTION 'registre_vol_chantier_inconnu';END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='chantier_vol_commande' AND (p.oid IS DISTINCT FROM to_regprocedure('public.chantier_vol_commande(text,text,uuid)') OR md5(p.prosrc)<>'f74a0fba9ee0d31a81b337f6955f0e37')) THEN RAISE EXCEPTION 'definition_non_examinee: chantier_vol_commande';END IF;
END;$g$;
DO $deps$ DECLARE signature text;BEGIN
 FOREACH signature IN ARRAY ARRAY['public.mon_personnage()','public.payer_ordre(text,text,integer,integer)',
 'public.terrain_chantier_acte(text,text,text,integer,integer)','public.inventaire_reception_etat(text)',
 'public.inventaire_reclamer_livraison(text,text,uuid,bigint)','public.personnage_stat_jet_interne(text,text)',
 'public.personnage_securite_jet_interne(text)','public.religion_benediction_consommer_interne(uuid,text,uuid)',
 'public.religion_benediction_lire()','public.detention_active(text)','public.recherche_inscrire(jsonb,text)',
 'public.indice_ville_ajuster_interne(text,text,text,integer)','public.jour_de_jeu_pays(text)',
 'public.terrain_negociation_jet_interne()'] LOOP
  IF to_regprocedure(signature) IS NULL THEN RAISE EXCEPTION 'dependance_vol_chantier_absente: %',signature;END IF;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=to_regclass('public.personnages_donnees') AND attname='inventory_revision' AND atttypid='bigint'::regtype AND attnotnull AND NOT attisdropped)
 OR NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=to_regclass('public.objets_recus') AND attname='reception_token' AND atttypid='uuid'::regtype AND attnotnull AND NOT attisdropped)
 OR to_regclass('public.ordres_jets_sites') IS NULL OR to_regclass('public.acquisitions_transactions_internes') IS NULL THEN RAISE EXCEPTION 'socle_vol_chantier_incomplet';END IF;
END;$deps$;
CREATE TABLE IF NOT EXISTS public.chantier_vols_recus(acteur uuid NOT NULL,requete uuid NOT NULL,terrain text NOT NULL,matiere text NOT NULL,resultat jsonb NOT NULL,traitee_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(acteur,requete));
COMMENT ON TABLE public.chantier_vols_recus IS 'HG chantier vol atomique #135 v1';
ALTER TABLE public.chantier_vols_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.chantier_vols_recus FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.chantier_vol_commande(p_terrain text,p_matiere text,p_requete uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();p record;t record;site record;recu record;e jsonb;ch jsonb;r jsonb;inv jsonb;objet jsonb;livraison text;jeton uuid;revision bigint;
 jet integer;bonus integer;score numeric;vigiles integer;rep integer;plafond integer;quantite integer:=0;stock numeric;numero integer;jour integer;succes boolean;detecte boolean;social_avant integer;
BEGIN
 IF auth.uid() IS NULL OR moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR p_matiere IS NULL OR p_matiere NOT IN('bois','minerai','metal') OR nullif(p_terrain,'') IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 IF NOT FOUND OR p.user_id IS DISTINCT FROM auth.uid() THEN RETURN jsonb_build_object('ok',false,'raison','personnage_non_possede');END IF;
 SELECT * INTO recu FROM public.chantier_vols_recus WHERE acteur=p.id AND requete=p_requete;
 IF FOUND THEN
  IF recu.terrain IS DISTINCT FROM p.country||'_'||p_terrain OR recu.matiere IS DISTINCT FROM p_matiere THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  r:=recu.resultat||'{"rejeu":true}';
 ELSE
  SELECT * INTO site FROM public.ordres_jets_sites s WHERE s.pays=p.country AND s.ville=p.current_city AND s.batiment=p_terrain AND s.piece=p.current_room AND s.ordre='voler_materiel_chantier';
  IF NOT FOUND OR p.current_building IS DISTINCT FROM p_terrain THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
  IF coalesce(p.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(moi)) OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
  SELECT * INTO t FROM public.terrains_etat WHERE id=p.country||'_'||p_terrain AND country=p.country AND building_id=p_terrain FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable');END IF;e:=t.data::jsonb;ch:=e->'chantier';
  IF e->>'city' IS DISTINCT FROM p.current_city THEN RETURN jsonb_build_object('ok',false,'raison','hors_territoire');END IF;
  IF coalesce(e->>'succession_gel','') NOT IN('','null','false') THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele');END IF;
  IF jsonb_typeof(ch) IS DISTINCT FROM 'object' OR coalesce((ch->>'dureeJours')::numeric,0)<=0 OR coalesce((ch->>'progressionJours')::numeric,0)>=(ch->>'dureeJours')::numeric THEN RETURN jsonb_build_object('ok',false,'raison','chantier_absent_ou_termine');END IF;
  stock:=coalesce((ch->'stockMateriaux'->>p_matiere)::numeric,0);
  IF stock<0 OR stock<>trunc(stock) OR stock::text IN('NaN','Infinity','-Infinity') THEN RETURN jsonb_build_object('ok',false,'raison','stock_invalide');END IF;
  -- Même score et mêmes seuils que plateau-chantiers.js ; aucun score fourni par le client.
  vigiles:=CASE WHEN jsonb_typeof(ch->'vigiles')='array' THEN jsonb_array_length(ch->'vigiles') ELSE greatest(0,floor(coalesce((ch->>'vigiles')::numeric,0)))::integer END;
  rep:=CASE WHEN coalesce(p.reputation_criminelle,0)>=70 THEN 15 WHEN p.reputation_criminelle>=40 THEN 10 WHEN p.reputation_criminelle>=20 THEN 5 ELSE 0 END;
  r:=public.inventaire_reception_etat(moi);IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'inventaire_non_confirme';END IF;revision:=(r->>'revision')::bigint;
  INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,t.id,'voler_materiel_chantier',site.pa,site.cout);
  r:=public.payer_ordre(moi,'voler_materiel_chantier',site.pa,site.cout);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(r->>'raison','paiement_refuse');END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE id=p.id) IS DISTINCT FROM p.pa-site.pa THEN RAISE EXCEPTION 'paiement_vol_non_confirme';END IF;
  bonus:=public.religion_benediction_consommer_interne(p.id,'voler_materiel_chantier',p_requete);jet:=public.terrain_negociation_jet_interne();
  IF jet IS NULL OR jet NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'jet_invalide';END IF;
  score:=greatest(0,least(100,jet+2*(public.personnage_stat_jet_interne(moi,'DUP')-10)-(public.personnage_securite_jet_interne(moi)-45)/3+rep+bonus-CASE WHEN vigiles>0 THEN 20+(vigiles-1)*10 ELSE 0 END));
  succes:=score>=50;detecte:=score<20;jour:=public.jour_de_jeu_pays(p.country);
  IF succes THEN
   numero:=floor(greatest(0,coalesce((ch->>'progressionJours')::numeric,0)))::integer+1;
   IF p_matiere='metal' THEN plafond:=(ARRAY[6,7,7])[((numero-1)%3)+1];
   ELSE SELECT floor(CASE WHEN p_matiere='bois' THEN bois ELSE minerai END*.2)::integer INTO plafond FROM public.chantiers_besoins_jour WHERE position_cycle=((numero-1)%(SELECT count(*) FROM public.chantiers_besoins_jour))+1;END IF;
   IF plafond IS NULL THEN RAISE EXCEPTION 'besoin_chantier_absent';END IF;
   quantite:=least(stock,plafond,greatest(1,floor((score-50)/50*plafond+.5)))::integer;
   IF quantite>0 THEN
    r:=public.terrain_chantier_acte(t.id,'chantier_materiaux_voler',p_matiere,quantite,jour);
    IF r->>'ok' IS DISTINCT FROM 'true' OR (r->>'quantite')::integer IS DISTINCT FROM quantite OR NOT EXISTS(SELECT 1 FROM public.terrains_etat d WHERE d.id=t.id AND (d.data::jsonb->'chantier'->'stockMateriaux'->>p_matiere)::numeric=stock-quantite) THEN RAISE EXCEPTION 'retrait_chantier_non_confirme';END IF;
    -- Le même circuit de réception fusionne le premier lot seulement et garde les métadonnées.
    objet:=jsonb_build_object('id','vol-chantier-'||p_requete::text,'name',CASE p_matiere WHEN 'bois' THEN 'Bois' WHEN 'minerai' THEN 'Minerai' ELSE 'Métal' END,'icon',CASE p_matiere WHEN 'bois' THEN 'ti-trees' WHEN 'minerai' THEN 'ti-mountain' ELSE 'ti-bolt' END,'stackable',true,'stackKey',p_matiere,'qty',quantite,'desc','Dérobé sur un chantier.');
    livraison:='vol-chantier-'||p_requete::text;
    INSERT INTO public.objets_recus(id,destinataire,expediteur,data) VALUES(livraison,moi,'Chantier',objet) RETURNING reception_token INTO jeton;
    r:=public.inventaire_reclamer_livraison(moi,livraison,jeton,revision);
    IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'reception_butin_non_confirmee';END IF;
    IF p.country='republic' THEN SELECT coalesce((data->>'social')::integer,50) INTO social_avant FROM public.indices_villes WHERE id=p.country||'_'||p.current_city FOR UPDATE;END IF;
    PERFORM public.indice_ville_ajuster_interne(p.country,p.current_city,'social',-1);
    IF social_avant IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.indices_villes WHERE id=p.country||'_'||p.current_city AND (data->>'social')::integer=greatest(0,least(100,social_avant-1))) THEN RAISE EXCEPTION 'indice_social_non_confirme';END IF;
   END IF;
  END IF;
  IF detecte THEN
   r:=public.recherche_inscrire(jsonb_build_object('id','vol-chantier-'||p_requete::text,'acte','vol_materiel_chantier','type','delit_mineur','jour',jour));
   IF r->>'ok' IS DISTINCT FROM 'true' OR NOT EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.name=moi AND d.recherche @> jsonb_build_array(jsonb_build_object('id','vol-chantier-'||p_requete::text))) THEN RAISE EXCEPTION 'recherche_non_confirmee';END IF;
  ELSIF NOT succes OR quantite>0 THEN
   INSERT INTO public.actions_tracables(id,auteur,cible,type_action,country,city,jour,jour_expiration) VALUES('vol-chantier-'||p_requete::text,moi,e->>'proprietaire',CASE WHEN succes THEN 'vol_materiel_chantier' ELSE 'tentative_vol_materiel_chantier' END,p.country,p.current_city,jour,jour+15);
   IF NOT EXISTS(SELECT 1 FROM public.actions_tracables a WHERE a.id='vol-chantier-'||p_requete::text AND a.auteur=moi AND a.country=p.country AND a.city=p.current_city) THEN RAISE EXCEPTION 'trace_vol_non_confirmee';END IF;
  END IF;
  r:=jsonb_build_object('ok',true,'succes',succes,'detecte',detecte,'quantite',quantite,'matiere',p_matiere,'score',score,'jet',jet,'bonus',bonus,'paPreleves',site.pa,'terrain',p_terrain);
  INSERT INTO public.chantier_vols_recus(acteur,requete,terrain,matiere,resultat) VALUES(p.id,p_requete,t.id,p_matiere,r);
  DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;
  UPDATE public.personnages_donnees SET updated_at=clock_timestamp() WHERE name=moi;
 END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 RETURN r||jsonb_build_object('pa',p.pa,'inventaire',public.inventaire_reception_etat(moi),'realites',public.religion_benediction_lire(),'etat',(SELECT data::jsonb FROM public.terrains_etat WHERE id=p.country||'_'||p_terrain));
EXCEPTION WHEN SQLSTATE 'P0135' THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_vol_commande(text,text,uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
