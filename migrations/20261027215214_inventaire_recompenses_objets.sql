-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261028205306.
-- Eprouvee au role authenticated en transaction annulee : récompense objet remise une seule fois.
-- (Preparee par Codex.) PREPAREE NON APPLIQUEE. Recompenses OBJETS de la quete existante, aucun moteur de quete nouveau.
-- Les recompenses argent/terrain/titre restent dans leurs circuits, hors ce transfert d'objet.
-- La creation/progression de quetes_actives est encore legacy : dependance explicite avant verrou final.
INSERT INTO public.objets_modeles(id,objet) VALUES('quete:dossier','{"icon":"ti-folder-search","type":"kompromat","legal":false}'::jsonb)
 ON CONFLICT(id) DO UPDATE SET objet=excluded.objet;
CREATE OR REPLACE FUNCTION public.quete_objet_reclamer(p_requete uuid,p_quete text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE a public.personnages_donnees; q public.quetes_actives; params jsonb; v jsonb; o jsonb; contenu text; msg text; indice integer;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR nullif(p_quete,'') IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 params:=jsonb_build_object('quete',p_quete);v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'quete_objet',params);IF v IS NOT NULL THEN RETURN v;END IF;
 SELECT * INTO q FROM public.quetes_actives WHERE id=p_quete FOR UPDATE;
 IF NOT FOUND OR q.statut IS DISTINCT FROM 'active' THEN RETURN jsonb_build_object('ok',false,'raison','quete_indisponible');END IF;
 IF q.country IS DISTINCT FROM a.country OR q.building_id IS NULL OR q.room_id IS NULL OR (a.current_building,a.current_room) IS DISTINCT FROM (q.building_id,q.room_id) THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 IF q.etape_actuelle<q.nb_etapes_total THEN RETURN jsonb_build_object('ok',false,'raison','quete_non_terminee');END IF;
 IF EXISTS(SELECT 1 FROM public.inventaire_actions_recus WHERE action='quete_objet' AND parametres=params) THEN RETURN jsonb_build_object('ok',false,'raison','recompense_deja_remise');END IF;
 IF public.inventaire_place_restante(a.inventory)<1 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein');END IF;
 IF q.recompense_type='objet' THEN
  indice:=floor(random()*7)::integer;
  SELECT objet-'origine'-'cible' INTO STRICT o FROM public.objets_modeles WHERE id='objet_trouve:'||indice;
  msg:='Vous obtenez : '||(o->>'name')||'.';
 ELSIF q.recompense_type='dossier_surveillance' AND nullif(q.cible_dossier,'') IS NOT NULL THEN
  SELECT string_agg('- '||type_action||coalesce(' (cible: '||cible||')','')||' — Jour '||jour,E'\n' ORDER BY created_at,id) INTO contenu
   FROM public.actions_tracables WHERE auteur=q.cible_dossier AND country=a.country AND city=a.current_city AND jour_expiration>=public.jour_de_jeu_pays(a.country);
  SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='quete:dossier';
  o:=o||jsonb_build_object('name','Dossier de surveillance — '||q.cible_dossier,'desc','Compilation d''actions réelles concernant '||q.cible_dossier||E' :\n'||coalesce(contenu,'Aucune action notable recensée récemment.'));
  msg:='Vous obtenez un dossier de surveillance complet sur '||q.cible_dossier||' !';
 ELSE RETURN jsonb_build_object('ok',false,'raison','recompense_non_objet');END IF;
 v:=public.inventaire_deposer_interne(a.name,o);
 IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'quete: depot refuse';END IF;
 UPDATE public.quetes_actives SET statut='resolue',resolu_par=a.name,recompense_detail=msg WHERE id=q.id;
 v:=v||jsonb_build_object('message',msg,'titre',q.titre);
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'quete_objet',params,v,now());RETURN v;
END; $function$;
REVOKE ALL ON FUNCTION public.quete_objet_reclamer(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.quete_objet_reclamer(uuid,text) TO authenticated;
