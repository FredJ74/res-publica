-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261028205317.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261028205317.
-- Eprouvee au role authenticated en transaction annulee : don de tracts : pile diminuée, envoi dans objets_recus.
-- (Preparee par Codex.) PREPAREE NON APPLIQUEE. Don de tracts : meme RPC, meme sas objets_recus, reception existante.
-- Retrait de la pile et emission du don dans UNE transaction, aucune compensation cliente.
CREATE OR REPLACE FUNCTION public.tracts_donner_joueur(p_requete uuid,p_index integer,p_revision bigint,p_destinataire text,p_quantite integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE a public.personnages_donnees; d public.personnages_donnees; o jsonb; v jsonb; params jsonb; total numeric; don text;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR p_quantite IS NULL OR p_quantite NOT BETWEEN 1 AND 1000 THEN RETURN jsonb_build_object('ok',false,'raison','quantite_invalide');END IF;
 params:=jsonb_build_object('index',p_index,'revision',p_revision,'destinataire',p_destinataire,'quantite',p_quantite);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'don_tracts',params);IF v IS NOT NULL THEN RETURN v;END IF;
 SELECT * INTO d FROM public.personnages_donnees WHERE name=p_destinataire;
 IF NOT FOUND OR d.name=a.name THEN RETURN jsonb_build_object('ok',false,'raison','destinataire_invalide');END IF;
 IF (a.country,a.current_city,a.current_building,a.current_room) IS DISTINCT FROM (d.country,d.current_city,d.current_building,d.current_room)
 OR a.current_building IS NULL OR a.current_room IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pas_co_presents');END IF;
 IF p_revision IS DISTINCT FROM a.inventory_revision THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_perime');END IF;
 IF p_index IS NULL OR p_index<0 OR p_index>=jsonb_array_length(a.inventory) THEN RETURN jsonb_build_object('ok',false,'raison','index_invalide');END IF;
 o:=a.inventory->p_index;
 IF coalesce(o->>'type','') NOT IN('tract','tract_calomnieux') OR o->>'origineQuete'='jean_lou'
 OR nullif(btrim(o->>'cible'),'') IS NULL OR jsonb_typeof(o->'quantite') IS DISTINCT FROM 'number' THEN RETURN jsonb_build_object('ok',false,'raison','objet_invalide');END IF;
 total:=(o->>'quantite')::numeric;
 IF total<>trunc(total) OR total<p_quantite THEN RETURN jsonb_build_object('ok',false,'raison','quantite_invalide');END IF;
 UPDATE public.personnages_donnees SET inventory=CASE WHEN total=p_quantite THEN inventory-p_index
  ELSE jsonb_set(inventory,ARRAY[p_index::text,'quantite'],to_jsonb(total-p_quantite)) END WHERE name=a.name;
 o:=o||jsonb_build_object('quantite',p_quantite);
 don:='don-tracts-'||md5(a.name)||'-'||p_requete;
 INSERT INTO public.objets_recus(id,destinataire,expediteur,data) VALUES(don,d.name,a.name,to_jsonb(o::text));
 SELECT jsonb_build_object('ok',true,'inventory',inventory,'revision',inventory_revision,'quantite',p_quantite,'destinataire',d.name,'livraison',don)
 INTO v FROM public.personnages_donnees WHERE name=a.name;
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'don_tracts',params,v,now());RETURN v;
END; $function$;
REVOKE ALL ON FUNCTION public.tracts_donner_joueur(uuid,integer,bigint,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.tracts_donner_joueur(uuid,integer,bigint,text,integer) TO authenticated;
-- (Fermeture de l'ancien contrat : deplacee dans 20261028210000.)
