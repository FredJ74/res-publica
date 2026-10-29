-- #219 : reçu technique de déplacement, pas une billetterie ni un compte nouveau.
CREATE TABLE IF NOT EXISTS public.navigation_requetes(
 acteur text NOT NULL,requete uuid NOT NULL,arguments jsonb NOT NULL,verdict jsonb NOT NULL,
 cree_le timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(acteur,requete));
ALTER TABLE public.navigation_requetes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.navigation_requetes FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.transport_effectuer(p_mode text,p_pays text,p_ville text,p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text;p public.personnages_donnees%ROWTYPE;n text;ids text[];pnjs text[];args jsonb;v jsonb;
 apres_ids text[];apres_pnjs text[];tarif record;mon_paiement jsonb;paies jsonb:='[]';r jsonb;b text;piece text;positions jsonb;total numeric;
BEGIN
 moi:=public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_absente');END IF;
 args:=jsonb_build_object('mode',p_mode,'pays',p_pays,'ville',p_ville);
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT verdict INTO v FROM public.navigation_requetes WHERE acteur=moi AND requete=p_requete AND arguments=args;
 IF FOUND THEN RETURN v;END IF;
 IF EXISTS(SELECT 1 FROM public.navigation_requetes WHERE acteur=moi AND requete=p_requete) THEN
 RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
 -- Avion/bateau restent fermés tant que le contrôle douanier n'est pas attesté.
 IF p_mode NOT IN ('train','bus') OR p_mode IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','controle_douanier_requis');END IF;
 IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE membre=moi) THEN RETURN jsonb_build_object('ok',false,'raison','chef_de_groupe_requis');END IF;
 SELECT array_agg(identifiant ORDER BY identifiant) FILTER(WHERE est_pj),
 coalesce(array_agg(identifiant ORDER BY identifiant) FILTER(WHERE NOT est_pj),'{}'::text[])
 INTO ids,pnjs FROM public.groupe_participants_interne(moi);
 PERFORM public.pnj_groupes_verrouiller_projections_interne(pnjs);
 PERFORM name FROM public.personnages_donnees WHERE name=ANY(ids) ORDER BY name FOR UPDATE;
 PERFORM id FROM public.pnj_membres WHERE id=ANY(pnjs) ORDER BY id FOR UPDATE;
 SELECT array_agg(identifiant ORDER BY identifiant) FILTER(WHERE est_pj),
 coalesce(array_agg(identifiant ORDER BY identifiant) FILTER(WHERE NOT est_pj),'{}'::text[])
 INTO apres_ids,apres_pnjs FROM public.groupe_participants_interne(moi);
 IF ids IS DISTINCT FROM apres_ids OR pnjs IS DISTINCT FROM apres_pnjs THEN
 RETURN jsonb_build_object('ok',false,'raison','composition_modifiee');END IF;
 IF cardinality(ids)<>(SELECT count(*)+1 FROM public.groupes_pj_adhesions WHERE chef=moi) THEN
 RETURN jsonb_build_object('ok',false,'raison','groupe_incomplet');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 IF NOT coalesce((p.current_building LIKE 'centre-multinodal-%' OR (p_mode='bus' AND p.current_city IN ('caserne','qhs') AND p.current_building IS NULL)),false) THEN
 RETURN jsonb_build_object('ok',false,'raison','pas_au_terminal');END IF;
 IF p.current_building IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles
 WHERE pays=p.country AND ville=p.current_city AND batiment=p.current_building AND pieces ? p.current_room) THEN
 RETURN jsonb_build_object('ok',false,'raison','pas_au_terminal');END IF;
 IF EXISTS(SELECT 1 FROM public.pnj_membres WHERE id=ANY(pnjs) AND (statut<>'actif' OR pays IS DISTINCT FROM p.country)) THEN
 RETURN jsonb_build_object('ok',false,'raison','membre_pnj_indisponible');END IF;
 IF p_pays IS DISTINCT FROM p.country OR p_ville=p.current_city OR NOT EXISTS(SELECT 1 FROM public.villes WHERE pays=p_pays AND ville=p_ville) THEN
 RETURN jsonb_build_object('ok',false,'raison','destination_invalide');END IF;
 SELECT batiment,pieces->>0 INTO b,piece FROM public.navigation_lieux_regles
 WHERE pays=p_pays AND ville=p_ville AND batiment LIKE 'centre-multinodal-%'
 AND NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles autre WHERE autre.pays=p_pays AND autre.ville<>p_ville AND autre.batiment=navigation_lieux_regles.batiment) ORDER BY batiment LIMIT 1;
 IF b IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','arrivee_non_referencee');END IF;
 IF EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE name=ANY(ids) AND (
 (country,current_city,current_building) IS DISTINCT FROM (p.country,p.current_city,p.current_building)
 OR (p.current_building IS NOT NULL AND d.current_room IS DISTINCT FROM p.current_room)
 OR (p.current_building IS NULL AND d.current_street IS DISTINCT FROM p.current_street))) THEN
 RETURN jsonb_build_object('ok',false,'raison','groupe_disperse');END IF;
 IF EXISTS(SELECT 1 FROM public.batailles_engagements e JOIN public.batailles bat ON bat.id=e.bataille_id
 JOIN public.pnj_soldats_metier sm ON sm.compagnie_id=e.compagnie_id AND sm.section_id=e.section_id AND sm.matricule=e.matricule
 WHERE sm.pnj_id=ANY(pnjs) AND e.sorti_round IS NULL AND bat.statut='en_cours') THEN
 RETURN jsonb_build_object('ok',false,'raison','combat_membre_pnj');END IF;
 IF (SELECT count(*) FROM public.ordres_couts WHERE fn=CASE p_mode WHEN 'train' THEN 'prendre_train' ELSE 'prendre_bus_taxi' END)<>1 THEN
 RETURN jsonb_build_object('ok',false,'raison','tarif_ambigu');END IF;
 SELECT * INTO tarif FROM public.ordres_couts WHERE fn=CASE p_mode WHEN 'train' THEN 'prendre_train' ELSE 'prendre_bus_taxi' END;
 FOREACH n IN ARRAY ids LOOP
 r:=public.navigation_disponibilite_interne(n);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r||jsonb_build_object('membre',n);END IF;
 -- Même décompte que la garde de déplacement existante. Le transport ne
 -- dispense aucun passager de la surcharge, même s'il ne paie pas lui-même.
 SELECT coalesce(sum(coalesce(nullif(x->>'qty','')::numeric,nullif(x->>'encombrement','')::numeric,1)),0)
 INTO total FROM public.personnages_donnees d CROSS JOIN LATERAL
 jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory)='array' THEN d.inventory ELSE '[]'::jsonb END) x WHERE name=n;
 IF total>100 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_surcharge','membre',n);END IF;
 END LOOP;
 BEGIN
 n:=moi;
 r:=public.payer_ordre_interne(moi,tarif.fn,tarif.pa,tarif.cost,cardinality(ids)+cardinality(pnjs));
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION USING ERRCODE='P2191',MESSAGE='transport_refuse';END IF;
 mon_paiement:=r;
 paies:=jsonb_build_array(jsonb_build_object('personnage',moi,'voyageurs',cardinality(ids)+cardinality(pnjs),'pa',r->'pa_preleves','montant',r->'montant_preleve'));
 UPDATE public.personnages_donnees SET current_city=p_ville,current_building=b,current_room=piece,current_street=NULL,updated_at=clock_timestamp() WHERE name=ANY(ids);
 PERFORM public.pnj_groupes_projeter_interne(pnjs);
 EXCEPTION WHEN SQLSTATE 'P2191' THEN RETURN r||jsonb_build_object('membre',n);END;
 SELECT jsonb_agg(jsonb_build_object('name',name,'country',country,'city',current_city,'building',current_building,'room',current_room,'street',current_street,'updated_at',updated_at) ORDER BY name)
 INTO positions FROM public.personnages_donnees WHERE name=ANY(ids);
 v:=jsonb_build_object('ok',true,'membres',to_jsonb(ids),'positions',positions,'voyageurs',cardinality(ids)+cardinality(pnjs),'paiements',paies,'paie',mon_paiement,'pays',p_pays,'ville',p_ville,'building',b,'room',piece);
 INSERT INTO public.navigation_requetes(acteur,requete,arguments,verdict) VALUES(moi,p_requete,args,v);
 RETURN v;
END $g$;
REVOKE ALL ON FUNCTION public.transport_effectuer(text,text,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.transport_effectuer(text,text,text,uuid) TO authenticated;
