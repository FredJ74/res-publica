-- #219 PRÉPARÉE, après 20261030223558. Aucun tarif ni coût en PA modifié.
-- Les trois actes historiques restent le moteur camion ; leur composition rejoint le socle.
DO $corps$
DECLARE f record;s text;a text;b text;
BEGIN
 FOR f IN SELECT * FROM (VALUES
 ('camion_monter(text,text)','camion_monter_corps_interne','p_camion_id text,p_cle text'),
 ('camion_descendre(text)','camion_descendre_corps_interne','p_camion_id text'),
 ('camion_deplacer(text,text,boolean,text)','camion_deplacer_corps_interne','p_camion_id text,p_destination_cle text,p_avec_officier boolean,p_cle text')) t(sig,prive,args) LOOP
  IF EXISTS(SELECT 1 FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname=f.prive) THEN CONTINUE;END IF;
  SELECT prosrc INTO s FROM pg_proc WHERE oid=('public.'||f.sig)::regprocedure;
  IF position('public.mon_personnage()' IN s)=0 THEN RAISE EXCEPTION 'camion_corps_non_examine:%',f.sig;END IF;
  -- Monter/descendre, y compris une éviction, concerne le groupe canonique entier.
  s:=replace(s,'WHERE name = v_moi;','WHERE name IN (SELECT identifiant FROM public.groupe_participants_interne(v_moi) WHERE est_pj);');
  s:=replace(s,'WHERE name = u.nom;','WHERE name IN (SELECT identifiant FROM public.groupe_participants_interne(u.nom) WHERE est_pj);');
  s:=replace(s,'WHERE name = u.chef;','WHERE name IN (SELECT identifiant FROM public.groupe_participants_interne(u.chef) WHERE est_pj);');
  s:=replace(s,'AND personnage = v_moi;','AND personnage IN (SELECT identifiant FROM public.groupe_participants_interne(v_moi) WHERE est_pj);');
  s:=replace(s,'AND personnage = u.nom;','AND personnage IN (SELECT identifiant FROM public.groupe_participants_interne(u.nom) WHERE est_pj);');
  s:=replace(s,'AND personnage = u.chef;','AND personnage IN (SELECT identifiant FROM public.groupe_participants_interne(u.chef) WHERE est_pj);');
  IF f.prive='camion_monter_corps_interne' THEN
   a:=$a$  SELECT 1 + count(*) INTO v_taille FROM public.pnj_membres m
    LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE m.statut = 'actif' AND m.leader_pj = v_moi
     AND COALESCE(sm.en_reserve, false) = false;$a$;
   IF position(a IN s)=0 THEN RAISE EXCEPTION 'camion_composition_non_examinee';END IF;
   s:=replace(s,a,' SELECT count(*) INTO v_taille FROM public.groupe_participants_interne(v_moi);');
   a:='WHERE o.est_pj = true';
   IF position(a IN s)=0 THEN RAISE EXCEPTION 'camion_eviction_non_examinee';END IF;s:=replace(s,a,a||' AND o.ref=o.chef');
   a:='VALUES (c.id, v_moi, now())';
   IF position(a IN s)=0 THEN RAISE EXCEPTION 'camion_embarquements_non_examines';END IF;
   s:=replace(s,a,'SELECT c.id,identifiant,now() FROM public.groupe_participants_interne(v_moi) WHERE est_pj');
  END IF;
  EXECUTE format('CREATE FUNCTION public.%I(%s) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',f.prive,f.args,s);
 END LOOP;
 -- Le lecteur des occupants garde ses critères et rejoint le chef canonique.
 s:=pg_get_functiondef('public.camion_occupants(text)'::regprocedure);
 IF position('-- camion_chef_canonique_v1' IN s)=0 THEN
  a:='pj.pa, pj.name,';IF position(a IN s)=0 THEN RAISE EXCEPTION 'camion_chef_PJ_non_examine';END IF;
  s:=replace(s,a,'pj.pa, coalesce((SELECT chef FROM public.groupes_pj_adhesions WHERE membre=pj.name),pj.name),');
  a:='pnj.pa, pnj.chef,';IF position(a IN s)=0 THEN RAISE EXCEPTION 'camion_chef_PNJ_non_examine';END IF;
  s:=replace(s,a,'pnj.pa, coalesce((SELECT chef FROM public.groupes_pj_adhesions WHERE membre=pnj.chef),pnj.chef),');
  s:=replace(s,'WHERE d.current_city     = c.ville','WHERE d.country=c.pays AND d.current_city     = c.ville');
  s:=replace(s,'AND pe.ville       IS NOT DISTINCT FROM c.ville','AND pe.pays=c.pays AND pe.ville       IS NOT DISTINCT FROM c.ville');
  EXECUTE replace(s,'WITH cam AS','-- camion_chef_canonique_v1'||chr(10)||'WITH cam AS');
 END IF;
END $corps$;
REVOKE ALL ON FUNCTION public.camion_monter_corps_interne(text,text),public.camion_descendre_corps_interne(text),public.camion_deplacer_corps_interne(text,text,boolean,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.camion_commande_groupe_interne(p_action text,p_camion text,p_destination text,p_avec boolean,p_cle text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE moi text;r jsonb;x record;c public.camions_militaires%ROWTYPE;chef_lieu record;rec public.camions_ordres%ROWTYPE;ids text[];pnjs text[];
BEGIN
 moi:=public.mon_personnage();IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_action NOT IN ('monter','descendre','deplacer') OR p_action IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','action_invalide');END IF;
 IF p_action='deplacer' AND p_avec IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT * INTO c FROM public.camions_militaires WHERE id=p_camion FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','camion_introuvable');END IF;
 IF p_action<>'descendre' THEN
  IF coalesce(btrim(p_cle),'')='' THEN RETURN jsonb_build_object('ok',false,'raison','cle_requete_absente');END IF;
  SELECT * INTO rec FROM public.camions_ordres WHERE requete=p_cle;
  IF FOUND THEN
   IF rec.acteur IS DISTINCT FROM moi OR rec.camion_id IS DISTINCT FROM p_camion OR rec.action IS DISTINCT FROM (CASE WHEN p_action='deplacer' THEN CASE WHEN p_avec THEN 'trajet' ELSE 'a_vide' END ELSE p_action END)
    OR (p_action='deplacer' AND (rec.destination IS DISTINCT FROM p_destination OR (rec.resultat->>'avec_officier')::boolean IS DISTINCT FROM p_avec)) THEN
    RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
   RETURN rec.resultat||jsonb_build_object('rejeu',true);
  END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE membre=moi) THEN RETURN jsonb_build_object('ok',false,'raison','chef_de_groupe_requis');END IF;

 -- Tous les occupants sont verrouillés : une priorité d'embarquement peut évincer un autre groupe.
 SELECT array_agg(DISTINCT identifiant) FILTER(WHERE est_pj),array_agg(DISTINCT identifiant) FILTER(WHERE NOT est_pj) INTO ids,pnjs FROM (
  SELECT est_pj,identifiant FROM public.groupe_participants_interne(moi)
  UNION SELECT p.est_pj,p.identifiant FROM (SELECT DISTINCT chef FROM public.camion_occupants(p_camion)) o CROSS JOIN LATERAL public.groupe_participants_interne(o.chef) p) z;
 PERFORM public.pnj_groupes_verrouiller_projections_interne(coalesce(pnjs,'{}'));
 PERFORM name FROM public.personnages_donnees WHERE name=ANY(ids) ORDER BY name FOR UPDATE;
 PERFORM id FROM public.pnj_membres WHERE id=ANY(pnjs) ORDER BY id FOR UPDATE;
 SELECT country,current_city,current_building,current_room,current_street INTO chef_lieu FROM public.personnages_donnees WHERE name=moi;
 FOR x IN SELECT * FROM public.groupe_participants_interne(moi) LOOP
  IF (x.pays,x.ville,x.batiment,x.piece) IS DISTINCT FROM (chef_lieu.country,chef_lieu.current_city,chef_lieu.current_building,chef_lieu.current_room) OR (chef_lieu.current_building IS NULL AND x.rue IS DISTINCT FROM chef_lieu.current_street) THEN RETURN jsonb_build_object('ok',false,'raison','groupe_disperse');END IF;
 END LOOP;
 -- Un autre groupe déjà à bord ne doit pas être scindé au voyage ou à l'éviction.
 IF EXISTS(SELECT 1 FROM (SELECT DISTINCT chef FROM public.camion_occupants(p_camion)) o
  CROSS JOIN LATERAL public.groupe_participants_interne(o.chef) p
  WHERE (p.pays,p.ville,p.batiment,p.piece) IS DISTINCT FROM (c.pays,c.ville,public.camion_batiment_interieur(),c.id)) THEN
  RETURN jsonb_build_object('ok',false,'raison','groupe_disperse');END IF;
 FOREACH moi IN ARRAY coalesce(ids,'{}') LOOP
  r:=public.navigation_disponibilite_interne(moi);IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r;END IF;
 END LOOP;
 moi:=public.mon_personnage();
 r:=public.pnj_confrontation_refus_interne(coalesce(pnjs,'{}'));IF r IS NOT NULL THEN RETURN jsonb_build_object('ok',false)||r;END IF;
 IF EXISTS(SELECT 1 FROM public.pnj_membres WHERE id=ANY(pnjs) AND statut<>'actif') THEN RETURN jsonb_build_object('ok',false,'raison','membre_pnj_indisponible');END IF;
 -- Descente sans coût : un rejeu ne fait qu'attester le groupe déjà au lieu du camion.
 IF p_action='descendre' AND (chef_lieu.current_city,chef_lieu.current_building,chef_lieu.current_room) IS NOT DISTINCT FROM (c.ville,c.building_id,c.room_id) THEN
  RETURN jsonb_build_object('ok',true,'deja_debarque',true,'camion_id',c.id);END IF;
 BEGIN
  r:=CASE p_action WHEN 'monter' THEN public.camion_monter_corps_interne(p_camion,p_cle)
   WHEN 'descendre' THEN public.camion_descendre_corps_interne(p_camion)
   ELSE public.camion_deplacer_corps_interne(p_camion,p_destination,p_avec,p_cle) END;
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION USING ERRCODE='P2197',MESSAGE='camion_acte_refuse';END IF;
  PERFORM public.pnj_groupes_projeter_interne(coalesce(pnjs,'{}'));
 EXCEPTION WHEN SQLSTATE 'P2197' THEN RETURN r;
 END;
 RETURN r;
END $g$;
REVOKE ALL ON FUNCTION public.camion_commande_groupe_interne(text,text,text,boolean,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.camion_monter(p_camion_id text,p_cle text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$ SELECT public.camion_commande_groupe_interne('monter',p_camion_id,NULL,NULL,p_cle);$g$;
CREATE OR REPLACE FUNCTION public.camion_descendre(p_camion_id text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$ SELECT public.camion_commande_groupe_interne('descendre',p_camion_id,NULL,NULL,NULL);$g$;
CREATE OR REPLACE FUNCTION public.camion_deplacer(p_camion_id text,p_destination_cle text,p_avec_officier boolean,p_cle text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$ SELECT public.camion_commande_groupe_interne('deplacer',p_camion_id,p_destination_cle,p_avec_officier,p_cle);$g$;
-- Projections autorisées depuis les trois actes contrôlés, jamais depuis PATCH.
DO $projections$
DECLARE f text;s text;a text;
BEGIN
 FOREACH f IN ARRAY ARRAY['compagnie_ecriture_metier_garder()','effectifs_ecriture_metier_garder()'] LOOP
  s:=pg_get_functiondef(('public.'||f)::regprocedure);
  IF position('''/rpc/camion_monter''' IN s)>0 THEN CONTINUE;END IF;
  a:='''/rpc/rue_position_enregistrer''';
  IF position(a IN s)=0 OR position('current_user NOT IN (''authenticated'',''anon'')' IN s)=0 THEN RAISE EXCEPTION 'camion_projection_garde_non_examinee:%',f;END IF;
  EXECUTE replace(s,a,'''/rpc/camion_monter'',''/rpc/camion_descendre'',''/rpc/camion_deplacer'','||a);
 END LOOP;
END $projections$;
