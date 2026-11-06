-- #379 : mêmes effets, commande organisation et reçus existants.
-- Anathème : cible explicite (Fred, 03/11, GAME-DESIGN-JAUGES-379.md).
-- Additif, aucune fermeture globale des sauvegardes ni donnée PJ modifiée.
CREATE OR REPLACE FUNCTION public.organisation_jauges_fiche_interne(p_acteur text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO public,pg_temp AS $f$
 SELECT jsonb_build_object('contrat_jauges',1,'acteur',name,'pop',resources->'pop','inf',resources->'inf',
  'pa',pa,'hp',hp,'moral',moral,'arg',arg,'liquide',liquide,
  'paiement',jsonb_build_object('ok',true,'pa',pa,'arg',arg,'liquide',liquide))
 FROM public.personnages_donnees WHERE name=p_acteur
$f$;
REVOKE ALL ON FUNCTION public.organisation_jauges_fiche_interne(text)FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.organisation_jauges_interne(p_acteur text,p_organisation text,p_params jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $f$
DECLARE a public.personnages_donnees;d jsonb;pays text;r record;paiement jsonb;g_pop integer;ressources jsonb;
 cible text;victime public.personnages_donnees;effets_cible jsonb;
BEGIN
 IF p_acteur IS DISTINCT FROM public.mon_personnage()THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_params IS NULL OR jsonb_typeof(p_params)<>'object' OR p_params-(CASE WHEN p_params->>'fn'='orga_anatheme'THEN ARRAY['fn','cible']ELSE ARRAY['fn']END)<>'{}'::jsonb THEN
  RETURN jsonb_build_object('ok',false,'raison','champs_interdits');END IF;
 SELECT * INTO r FROM(VALUES
 ('orga_petition','politique',2,0,0,0,0),
 ('orga_meeting','politique',3,500,5,3,0),
 ('orga_benediction','religieuse',2,200,5,0,10),
 ('orga_anatheme','religieuse',2,200,0,0,0),
 ('orga_pelerinage','religieuse',3,1000,8,0,0),
 ('orga_cooptation','loge',2,1000,0,5,0),
 ('orga_rituel','loge',2,500,0,6,0),
 ('orga_reseau','loge',2,300,0,8,0),
 ('orga_campagne_presse','mediatique',2,500,6,5,0),
 ('orga_scoop','mediatique',2,0,0,10,0)
 )AS regle(fn,type,pa,cout,pop,inf,moral)WHERE fn=p_params->>'fn';
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','ordre_non_raccorde');END IF;
 IF p_params->>'fn'='orga_anatheme'THEN
  cible:=p_params->>'cible';
  IF jsonb_typeof(p_params->'cible')IS DISTINCT FROM 'string'OR cible IS NULL OR btrim(cible)=''OR cible=p_acteur THEN
   RETURN jsonb_build_object('ok',false,'raison','autre_joueur_requis');END IF;
  PERFORM name FROM public.personnages_donnees WHERE name=ANY(ARRAY[p_acteur,cible])ORDER BY name FOR UPDATE;
 ELSE
  PERFORM 1 FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
 END IF;
 SELECT * INTO a FROM public.personnages_donnees WHERE name=p_acteur;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable');END IF;
 SELECT data::jsonb, country_origine INTO d,pays FROM public.organisations WHERE id=p_organisation FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','organisation_absente');END IF;
 IF coalesce((d->>'dissoute')::boolean,false)THEN RETURN jsonb_build_object('ok',false,'raison','organisation_dissoute');END IF;
 IF coalesce(d->>'country',pays)IS DISTINCT FROM a.country THEN RETURN jsonb_build_object('ok',false,'raison','territoire_invalide');END IF;
 IF d->>'type'IS DISTINCT FROM r.type THEN RETURN jsonb_build_object('ok',false,'raison','type_invalide');END IF;
 IF d->>'chef'IS DISTINCT FROM p_acteur AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(
  CASE WHEN jsonb_typeof(d->'membres')='array'THEN d->'membres'ELSE '[]'::jsonb END)m WHERE m->>'nom'=p_acteur)THEN
  RETURN jsonb_build_object('ok',false,'raison','membre_requis');END IF;
 IF cible IS NOT NULL THEN
  SELECT * INTO victime FROM public.personnages_donnees WHERE name=cible;
  IF NOT FOUND OR victime.user_id IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','autre_joueur_requis');END IF;
  -- Périmètre du sélecteur de citoyens existant, domiciliés ou présents au pays.
  IF victime.country IS DISTINCT FROM a.country AND coalesce(victime.domicile->>'country',victime.country)IS DISTINCT FROM a.country THEN
   RETURN jsonb_build_object('ok',false,'raison','territoire_invalide');END IF;
 END IF;
 paiement:=public.payer_ordre(p_acteur,r.fn,r.pa,r.cout);
 IF NOT coalesce((paiement->>'ok')::boolean,false)THEN RETURN paiement;END IF;
 SELECT * INTO a FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
 g_pop:=CASE WHEN r.fn='orga_petition'THEN floor(random()*8)::integer+3 ELSE r.pop END;
 ressources:=coalesce(a.resources,'{}'::jsonb)-'popBase'-'infBase';
 ressources:=jsonb_set(ressources,'{pop}',to_jsonb(least(100,greatest(0,coalesce((ressources->>'pop')::numeric,0)+g_pop))));
 ressources:=jsonb_set(ressources,'{inf}',to_jsonb(least(100,greatest(0,coalesce((ressources->>'inf')::numeric,0)+r.inf))));
 UPDATE public.personnages_donnees SET resources=ressources,moral=least(100,greatest(0,coalesce(moral,50)+r.moral))WHERE name=p_acteur;
 IF cible IS NOT NULL THEN
  UPDATE public.personnages_donnees SET
   resources=jsonb_set(coalesce(resources,'{}'::jsonb)-'popBase'-'infBase','{pop}',to_jsonb(greatest(0,least(100,coalesce((resources->>'pop')::numeric,0)-10)))),
   moral=greatest(0,coalesce(moral,50)-15)WHERE name=cible;
  effets_cible:=jsonb_build_object('nom',cible,'pop',-10,'moral',-15);
 END IF;
 RETURN public.organisation_jauges_fiche_interne(p_acteur)||jsonb_build_object('ok',true,'ordre',r.fn,'organisation_nom',d->>'nom','gain_pop',g_pop,'gain_inf',r.inf,'gain_moral',r.moral,'effets_cible',effets_cible);
END;$f$;
REVOKE ALL ON FUNCTION public.organisation_jauges_interne(text,text,jsonb)FROM PUBLIC,anon,authenticated,service_role;
-- Préserve le corps courant de fondation/grèves/dockers ; aucun remplacement aveugle.
DO $patch$
DECLARE corps text;definition text;
BEGIN
 SELECT prosrc,pg_get_functiondef(oid)INTO corps,definition FROM pg_proc
  WHERE oid=to_regprocedure('public.organisation_vie_commande(text,text,text,jsonb)');
 IF corps IS NULL THEN RAISE EXCEPTION 'organisation_vie_definition_a_reexaminer';END IF;
 IF position('ordre_jauges' in corps)>0 THEN RETURN;END IF;
 -- Corps examinés : jetable (298da…) et production du 03/11 (e3fe89…, réécrit par main).
 IF md5(corps) NOT IN('298da01bbbe4a19db5acb203e88e8d99','e3fe89bed456a4f84776b9dfd423db1d')THEN RAISE EXCEPTION 'organisation_vie_definition_a_reexaminer';END IF;
 IF (length(corps)-length(replace(corps,$a1$  SELECT country, current_city, current_building, current_room, arg,$a1$,'')))<>length($a1$  SELECT country, current_city, current_building, current_room, arg,$a1$)
  OR (length(corps)-length(replace(corps,$a2$    RETURN v_rec.resultat || jsonb_build_object('rejeu', true);$a2$,'')))<>length($a2$    RETURN v_rec.resultat || jsonb_build_object('rejeu', true);$a2$)
 THEN RAISE EXCEPTION 'organisation_vie_ancres_absentes';END IF;
 corps:=replace(corps,$avant1$  SELECT country, current_city, current_building, current_room, arg,$avant1$,$apres1$  IF p_action = 'ordre_jauges' THEN
    v_res := public.organisation_jauges_interne(v_moi,p_organisation,p_parametres);
    IF NOT coalesce((v_res->>'ok')::boolean,false) THEN RETURN v_res;END IF;
    v_res := v_res || jsonb_build_object('organisation',p_organisation,'action',p_action);
    INSERT INTO public.organisation_commandes_recus(requete,acteur,organisation,commande,resultat)
      VALUES(p_requete,v_moi,p_organisation,v_cmd,v_res);
    RETURN v_res;
  END IF;
  SELECT country, current_city, current_building, current_room, arg,$apres1$);
 corps:=replace(corps,$avant2$    RETURN v_rec.resultat || jsonb_build_object('rejeu', true);$avant2$,$apres2$    IF p_action='ordre_jauges' THEN
      IF v_rec.organisation IS DISTINCT FROM p_organisation THEN
        RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
      RETURN v_rec.resultat || public.organisation_jauges_fiche_interne(v_moi) || jsonb_build_object('rejeu',true);
    END IF;
    RETURN v_rec.resultat || jsonb_build_object('rejeu', true);$apres2$);
 IF position('organisation_jauges_interne' in corps)=0 OR position('organisation_jauges_fiche_interne' in corps)=0 THEN RAISE EXCEPTION 'organisation_vie_patch_incomplet';END IF;
 EXECUTE replace(definition,(SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.organisation_vie_commande(text,text,text,jsonb)')),corps);
END;$patch$;
NOTIFY pgrst,'reload schema';
