-- #219 : ordres de recrutement existants, profils métier et miroir existants.
-- Fin du paiement séparé et du document d'effectifs construit par le navigateur.
CREATE OR REPLACE FUNCTION public.force_publique_effectif_acte(
 p_service text,p_action text,p_type text,p_matricule text,p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
<<acte>>
DECLARE moi text;p public.personnages_donnees%ROWTYPE;pays text;ville text;bat text;cle text;agents text;
 id_etat text;ancien jsonb;etat jsonb;eff jsonb;liste jsonb;modele jsonb;profil jsonb;v jsonb;args jsonb;tarif record;
 mat text;ident text;lieu jsonb;piece text;fn text;
BEGIN
 moi:=public.mon_personnage();IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie');END IF;
 IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_absente');END IF;
 IF p_service NOT IN ('police','douane') OR p_action NOT IN ('recruter','licencier')
 OR p_service IS NULL OR p_action IS NULL OR (p_action='recruter' AND (p_type IS NULL OR p_type NOT IN ('standard','cynophile')))
 OR (p_action='licencier' AND (p_service<>'douane' OR nullif(p_matricule,'') IS NULL)) THEN
 RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 args:=jsonb_build_object('operation','effectif','service',p_service,'action',p_action,'type',p_type,'matricule',p_matricule);
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT verdict INTO v FROM public.navigation_requetes WHERE acteur=moi AND requete=p_requete AND arguments=args;
 IF FOUND THEN RETURN v;END IF;
 IF EXISTS(SELECT 1 FROM public.navigation_requetes WHERE acteur=moi AND requete=p_requete) THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 IF p_service='police' THEN
  SELECT a.country,a.city INTO pays,ville FROM public.postes_attribues a
  WHERE a.titulaire=moi AND a.poste_id='commissaire' AND a.country=p.country AND a.city=p.current_city ORDER BY a.id LIMIT 1;
  bat:=CASE WHEN ville='capitale' THEN 'commissariat' ELSE 'commissariat-local' END;
  cle:='effectifsPolice';agents:='policiers';profil:=public.police_caracteristiques_metier();
 ELSE
  IF (SELECT count(*) FROM public.postes_attribues WHERE titulaire=moi AND poste_id='chef_douanes')<>1 THEN
   RETURN jsonb_build_object('ok',false,'raison','autorite_insuffisante');END IF;
  SELECT a.country INTO pays FROM public.postes_attribues a WHERE a.titulaire=moi AND a.poste_id='chef_douanes';
  ville:='ville_a';bat:='port-sainte-marie';cle:='effectifsDouane';agents:='douaniers';profil:=public.douane_caracteristiques_metier();
 END IF;
 IF pays IS NULL OR ville IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','autorite_insuffisante');END IF;
 IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles WHERE navigation_lieux_regles.pays=acte.pays AND navigation_lieux_regles.ville=acte.ville AND batiment=bat) THEN
 RETURN jsonb_build_object('ok',false,'raison','service_non_reference');END IF;
 IF (SELECT count(*) FROM public.batiments_etat b WHERE b.country=pays AND b.city=ville AND b.building_id=bat)>1 THEN
 RETURN jsonb_build_object('ok',false,'raison','etat_service_ambigu');END IF;
 SELECT b.id,b.data INTO id_etat,ancien FROM public.batiments_etat b WHERE b.country=pays AND b.city=ville AND b.building_id=bat FOR UPDATE;
 etat:=coalesce(public.batiment_etat_lire(ancien),'{}'::jsonb);eff:=etat->cle;
 IF eff IS NULL THEN
  IF EXISTS(SELECT 1 FROM public.pnj_membres WHERE proprietaire_institution=p_service AND proprietaire_perimetre=ville||':'||bat AND pnj_membres.pays=acte.pays) THEN
   RETURN jsonb_build_object('ok',false,'raison','effectifs_sans_projection');END IF;
  eff:=jsonb_build_object(agents,'[]'::jsonb,'dernierPaiementJour',NULL);
 END IF;
 liste:=eff->agents;
 IF jsonb_typeof(liste) IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('ok',false,'raison','effectifs_invalides');END IF;
 v:=public.groupe_confrontation_refus_interne(moi);
 IF v IS NOT NULL THEN RETURN jsonb_build_object('ok',false)||v;END IF;
 v:=public.navigation_disponibilite_interne(moi);
 IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v;END IF;
 IF p_action='recruter' THEN
  IF jsonb_array_length(liste)>=200 THEN RETURN jsonb_build_object('ok',false,'raison','effectif_plein');END IF;
  fn:='recruter_'||CASE WHEN p_service='police' THEN 'policier' ELSE 'douanier' END||CASE WHEN p_type='cynophile' THEN '_cynophile' ELSE '' END;
  IF (SELECT count(*) FROM public.ordres_couts WHERE ordres_couts.fn=acte.fn)<>1 THEN RETURN jsonb_build_object('ok',false,'raison','tarif_ambigu');END IF;
  SELECT * INTO tarif FROM public.ordres_couts WHERE ordres_couts.fn=acte.fn;
  mat:=CASE WHEN p_service='police' THEN 'POL-' ELSE 'DOU-' END||replace(gen_random_uuid()::text,'-','');
  piece:=CASE WHEN p_service='douane' THEN 'douanes' WHEN ville='capitale' THEN 'accueil_police' ELSE 'accueil_loc' END;
  IF (p.country,p.current_city,p.current_building)=(pays,ville,bat) AND EXISTS(
    SELECT 1 FROM public.navigation_lieux_regles WHERE navigation_lieux_regles.pays=acte.pays AND navigation_lieux_regles.ville=acte.ville AND batiment=bat AND pieces ? p.current_room) THEN piece:=p.current_room;END IF;
  IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles WHERE navigation_lieux_regles.pays=acte.pays AND navigation_lieux_regles.ville=acte.ville AND batiment=bat AND pieces ? piece) THEN
    RETURN jsonb_build_object('ok',false,'raison','lieu_service_non_reference');END IF;
  modele:=jsonb_build_object('matricule',mat,'type',p_type,'stats',profil,'buildingId',bat,'roomId',piece,'rueNoeudId',NULL,'recruteLe',(extract(epoch FROM clock_timestamp())*1000)::bigint);
  IF p_type='cynophile' THEN modele:=modele||jsonb_build_object('maitreNom','Maître-chien '||right(mat,4),'chienNom','Chien '||right(mat,4));END IF;
  v:=public.payer_ordre_interne(moi,fn,tarif.pa,tarif.cost,1);
  IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v;END IF;
  liste:=liste||jsonb_build_array(modele);
 ELSE
  mat:=p_matricule;ident:=public.douane_pnj_id(pays,ville,mat);
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(liste) x WHERE x->>'matricule'=mat) THEN RETURN jsonb_build_object('ok',false,'raison','agent_absent');END IF;
  v:=public.pnj_confrontation_refus_interne(ARRAY[ident]);
  IF v IS NOT NULL THEN RETURN jsonb_build_object('ok',false)||v;END IF;
  PERFORM id FROM public.pnj_membres WHERE id=ident FOR UPDATE;
  SELECT to_jsonb(pe) INTO lieu FROM public.pnj_position_effective(ident) pe;
  IF lieu IS NOT NULL THEN PERFORM public.pnj_positions_separer_interne(jsonb_build_object(ident,lieu));END IF;
  SELECT coalesce(jsonb_agg(x),'[]'::jsonb) INTO liste FROM jsonb_array_elements(liste) x WHERE x->>'matricule'<>mat;
 END IF;
 eff:=jsonb_set(eff,ARRAY[agents],liste);etat:=jsonb_set(etat,ARRAY[cle],eff);
 IF id_etat IS NULL THEN
  id_etat:=pays||'_'||ville||'_'||bat;
  INSERT INTO public.batiments_etat(id,country,city,building_id,data) VALUES(id_etat,pays,ville,bat,to_jsonb(etat::text));
 ELSE UPDATE public.batiments_etat SET data=CASE WHEN jsonb_typeof(ancien)='string' THEN to_jsonb(etat::text) ELSE etat END WHERE id=id_etat;END IF;
 IF p_service='police' THEN PERFORM public.pnj_miroir_police(pays,ville,bat);ELSE PERFORM public.pnj_miroir_douane(pays,ville,bat);END IF;
 SELECT public.batiment_etat_lire(data)->cle INTO eff FROM public.batiments_etat WHERE id=id_etat;
 v:=jsonb_build_object('ok',true,'matricule',mat,'action',p_action,'service',p_service,'effectifs',eff);
 INSERT INTO public.navigation_requetes(acteur,requete,arguments,verdict) VALUES(moi,p_requete,args,v);
 RETURN v;
END $g$;
REVOKE ALL ON FUNCTION public.force_publique_effectif_acte(text,text,text,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.force_publique_effectif_acte(text,text,text,text,uuid) TO authenticated;

-- Le mandat national ne disparaît pas quand son titulaire voyage.
CREATE OR REPLACE FUNCTION public.douane_autorite_de_perimetre(p_pays text,p_perimetre text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT min(titulaire) FROM public.postes_attribues
 WHERE country=p_pays AND poste_id='chef_douanes' AND city IS NULL
 AND p_perimetre='ville_a:port-sainte-marie'
 HAVING count(*)=1;
$g$;

-- Même dotation initiale déjà décidée : quatre agents DOU-PNJ-1 à 4.
-- Pas de recréation d'un effectif déjà vide, ni de bâtiments fictifs.
DO $initial$
DECLARE n record;b record;e jsonb;liste jsonb;
BEGIN
 FOR n IN SELECT DISTINCT pays FROM public.navigation_lieux_regles
 WHERE ville='ville_a' AND batiment='port-sainte-marie' AND pieces ? 'douanes' LOOP
  IF (SELECT count(*) FROM public.batiments_etat WHERE country=n.pays AND city='ville_a' AND building_id='port-sainte-marie')>1 THEN RAISE EXCEPTION 'etat_douane_ambigu: %',n.pays;END IF;
  SELECT * INTO b FROM public.batiments_etat WHERE country=n.pays AND city='ville_a' AND building_id='port-sainte-marie' FOR UPDATE;
  e:=coalesce(public.batiment_etat_lire(b.data),'{}'::jsonb);
  IF e ? 'effectifsDouane' THEN CONTINUE;END IF;
  IF EXISTS(SELECT 1 FROM public.pnj_membres WHERE pays=n.pays AND proprietaire_institution='douane') THEN RAISE EXCEPTION 'douane_sans_projection: %',n.pays;END IF;
  SELECT jsonb_agg(jsonb_build_object('matricule','DOU-PNJ-'||i,'type','standard',
    'stats',public.douane_caracteristiques_metier(),'buildingId','port-sainte-marie','roomId','douanes',
    'recruteLe',(extract(epoch FROM clock_timestamp())*1000)::bigint) ORDER BY i) INTO liste FROM generate_series(1,4) i;
  e:=jsonb_set(e,'{effectifsDouane}',jsonb_build_object('douaniers',liste,'dernierPaiementJour',NULL));
  IF b.id IS NULL THEN INSERT INTO public.batiments_etat(id,country,city,building_id,data)
    VALUES(n.pays||'_ville_a_port-sainte-marie',n.pays,'ville_a','port-sainte-marie',to_jsonb(e::text));
  ELSE UPDATE public.batiments_etat SET data=CASE WHEN jsonb_typeof(b.data)='string' THEN to_jsonb(e::text) ELSE e END WHERE id=b.id;END IF;
  PERFORM public.pnj_miroir_douane(n.pays,'ville_a','port-sainte-marie');
 END LOOP;
END $initial$;

-- Fermer le remplacement de listes et le paiement isolé APRES leur raccordement.
-- Les autres sous-clés métier et les autres paiements ne changent pas.
DO $anciennes$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.batiment_etat_sous_cle_ecrire(text,text,text,text,jsonb)'::regprocedure);
 IF position('-- effectifs_commandes_atomiques_v1' IN s)=0 THEN
  a:='v_serveur := public.est_appel_serveur();';
  IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'effectifs_ancienne_porte_non_examinee';END IF;
  s:=replace(s,a,a||E'\n -- effectifs_commandes_atomiques_v1\n IF NOT v_serveur AND p_sous_cle IN (''effectifsPolice'',''effectifsDouane'') THEN RETURN jsonb_build_object(''ok'',false,''raison'',''operation_atomique_requise'');END IF;');
  EXECUTE s;
 END IF;
 s:=pg_get_functiondef('public.payer_ordre(text,text,integer,integer)'::regprocedure);
 IF position('-- effectifs_paiement_atomique_v1' IN s)=0 THEN
  IF position('BEGIN' IN s)=0 THEN RAISE EXCEPTION 'effectifs_paiement_corps_non_examine';END IF;
  s:=overlay(s placing E'BEGIN\n -- effectifs_paiement_atomique_v1\n IF p_fn IN (''recruter_policier'',''recruter_policier_cynophile'',''recruter_douanier'',''recruter_douanier_cynophile'') THEN RETURN jsonb_build_object(''ok'',false,''raison'',''operation_atomique_requise'');END IF;' FROM position('BEGIN' IN s) FOR 5);
  EXECUTE s;
 END IF;
END $anciennes$;

CREATE OR REPLACE FUNCTION public.effectifs_ecriture_metier_garder()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp' AS $g$
DECLARE avant jsonb;apres jsonb;chemin text:=coalesce(current_setting('request.path',true),'');
BEGIN
 IF public.est_appel_serveur() OR (current_user NOT IN ('authenticated','anon') AND chemin=ANY(ARRAY[
 '/rpc/force_publique_effectif_acte','/rpc/pnj_prendre','/rpc/pnj_quitter_groupe','/rpc/pnj_transferer',
 '/rpc/pnj_deployer_unite','/rpc/pnj_rappeler_radio','/rpc/rue_position_enregistrer','/rpc/navigation_interieure',
 '/rpc/transport_effectuer','/rpc/douane_controle_groupe','/rpc/police_combat_resoudre',
 '/rpc/police_reddition_resoudre','/rpc/police_fuite_resoudre','/rpc/justice_executer_condamnation_soi',
 '/rpc/detention_ouvrir_soi','/rpc/detention_transferer_qhs','/rpc/police_payer_effectifs','/rpc/douane_payer_effectifs'])) THEN
  IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
 END IF;
 IF TG_OP<>'INSERT' THEN avant:=public.batiment_etat_lire(OLD.data);END IF;
 IF TG_OP<>'DELETE' THEN apres:=public.batiment_etat_lire(NEW.data);END IF;
 IF (avant->'effectifsPolice',avant->'effectifsDouane') IS DISTINCT FROM (apres->'effectifsPolice',apres->'effectifsDouane')
 OR (TG_OP='UPDATE' AND ((avant ? 'effectifsPolice') OR (avant ? 'effectifsDouane')) AND
 (OLD.id,OLD.country,OLD.city,OLD.building_id) IS DISTINCT FROM (NEW.id,NEW.country,NEW.city,NEW.building_id)) THEN
  RAISE EXCEPTION 'effectifs_ecriture_metier_requise';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END $g$;
REVOKE ALL ON FUNCTION public.effectifs_ecriture_metier_garder() FROM PUBLIC,anon,authenticated,service_role;
DO $garde$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.batiments_etat'::regclass AND tgname='effectifs_ecriture_metier') THEN
  CREATE TRIGGER effectifs_ecriture_metier BEFORE INSERT OR UPDATE OR DELETE ON public.batiments_etat FOR EACH ROW EXECUTE FUNCTION public.effectifs_ecriture_metier_garder();
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.batiments_etat'::regclass AND tgname='effectifs_ecriture_metier' AND tgenabled='O' AND tgfoid='public.effectifs_ecriture_metier_garder()'::regprocedure) THEN RAISE EXCEPTION 'effectifs_garde_non_conforme';END IF;
END $garde$;

-- Un PNJ détaché mais déjà recruté dans une interception reste engagé.
DO $confrontation$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.pnj_confrontation_refus_interne(text[])'::regprocedure);
 IF position('-- effectifs_interception_figee_v1' IN s)>0 THEN RETURN;END IF;
 a:=E'  SELECT ''combat_en_cours'' FROM public.batailles_engagements e';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'effectifs_confrontation_corps_non_examine';END IF;
 s:=replace(s,a,E'  -- effectifs_interception_figee_v1\n  SELECT ''interception_en_cours'' FROM public.police_interceptions i\n  CROSS JOIN LATERAL jsonb_array_elements_text(coalesce(i.combattants_forces,''[]''::jsonb)||coalesce(i.combattants_victimes,''[]''::jsonb)) x(cle)\n  WHERE i.expires_at>now() AND x.cle LIKE ''pnj:%'' AND substring(x.cle FROM 5)=ANY(p_ids)\n  UNION ALL\n'||a);
 EXECUTE s;
END $confrontation$;
