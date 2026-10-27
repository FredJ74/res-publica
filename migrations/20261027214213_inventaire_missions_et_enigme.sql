-- PREPAREE NON APPLIQUEE. Emissions d'objets dans les progressions existantes, pas de moteur de quete nouveau.
-- Les autres etapes de quete restent legacy : leur autorite complete est un prevol avant verrou final.
INSERT INTO public.objets_modeles(id,objet) VALUES
 ('mission:pat','{"type":"colis_secret_pat","name":"Colis secret","icon":"ti-package","desc":"Un colis remis par Pat Hounette. Vous ignorez ce qu''il contient."}'::jsonb),
 ('mission:jean_lou','{"type":"tract","icon":"ti-file-description","tractType":"pour","quantite":3,"legal":true,"origineQuete":"jean_lou"}'::jsonb),
 ('enigme:calepin','{"id":"calepin-enigme1","name":"Calepin de l''enquête","icon":"ti-notebook","imageUrl":"images/calepin-enigme-musee.webp","desc":"Un petit calepin. Chaque page se remplit au fil de ce que vous découvrez.","calepinEnigme1":true}'::jsonb),
 ('enigme:cle','{"id":"cle-debarras-musee","name":"Clé du débarras","icon":"ti-key","desc":"Une vieille clé, retrouvée dans un coffre lié à la succession de Pierre Thibault. Elle semble correspondre à une porte du Musée de la Ville de Luthécia."}'::jsonb)
 ON CONFLICT(id) DO UPDATE SET objet=excluded.objet;
CREATE OR REPLACE FUNCTION public.mission_carriere_recevoir(p_requete uuid,p_mission text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp SET TimeZone TO 'UTC' AS $function$
DECLARE a public.personnages_donnees; qc jsonb; o jsonb; v jsonb; params jsonb; ambition text; batiment text; piece text;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR p_mission IS NULL OR p_mission NOT IN('pat','jean_lou') THEN RETURN jsonb_build_object('ok',false,'raison','mission_inconnue');END IF;
 params:=jsonb_build_object('mission',p_mission);v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'mission_carriere',params);
 IF v IS NOT NULL THEN RETURN v||jsonb_build_object('quete_carriere',a.quete_carriere);END IF;
 ambition:=CASE p_mission WHEN 'pat' THEN 'criminel' ELSE 'politique' END;
 batiment:=CASE p_mission WHEN 'pat' THEN 'place-formulaire-liberte' ELSE 'bureau-national-emploi' END;
 piece:=CASE p_mission WHEN 'pat' THEN 'place' ELSE 'accueil' END;
 IF (a.country,a.current_city,a.current_building,a.current_room) IS DISTINCT FROM ('republic','capitale',batiment,piece) THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 qc:=a.quete_carriere;
 IF qc->>'ambition' IS DISTINCT FROM ambition OR qc->>'etape' IS DISTINCT FROM 'a_rencontrer' THEN RETURN jsonb_build_object('ok',false,'raison','etape_non_conforme');END IF;
 -- Meme si une ancienne sauvegarde remet l'etape en arriere, l'emission ne se repete pas.
 IF EXISTS(SELECT 1 FROM public.inventaire_actions_recus WHERE acteur=a.name AND action='mission_carriere' AND parametres=params) THEN RETURN jsonb_build_object('ok',false,'raison','objet_deja_remis');END IF;
 IF public.inventaire_place_restante(a.inventory)<1 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein');END IF;
 SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='mission:'||p_mission;
 IF p_mission='pat' THEN qc:=qc||jsonb_build_object('etape','colis_recu');
 ELSE qc:=qc||jsonb_build_object('etape','tracts_recus','electionCible',null,'ciblesJeanLou','[]'::jsonb,'resultatsJeanLou','[]'::jsonb);
  o:=o||jsonb_build_object('name','Tracts POUR '||a.name,'cible',a.name);
 END IF;
 v:=public.inventaire_deposer_interne(a.name,o);
 IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'mission: depot refuse';END IF;
 UPDATE public.personnages_donnees SET quete_carriere=qc WHERE name=a.name;
 IF p_mission='pat' THEN
  INSERT INTO public.actions_tracables(id,auteur,cible,type_action,country,city,jour,jour_expiration)
  VALUES('action-'||gen_random_uuid(),a.name,'Pat Hounette','colis_recu_pat_hounette',a.country,a.current_city,public.jour_de_jeu_pays(a.country),public.jour_de_jeu_pays(a.country)+7);
 END IF;
 v:=v||jsonb_build_object('quete_carriere',qc);
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'mission_carriere',params,v,now());RETURN v;
END; $function$;
REVOKE ALL ON FUNCTION public.mission_carriere_recevoir(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.mission_carriere_recevoir(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.enigme_objet_recevoir(p_requete uuid,p_action text,p_pa integer,p_cost integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp SET TimeZone TO 'UTC' AS $function$
DECLARE a public.personnages_donnees; e jsonb; o jsonb; v jsonb; paiement jsonb; params jsonb;
 changement boolean:=false; statut text:='inchange'; variante text;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR p_action IS NULL OR p_action NOT IN('verifier','coffre') THEN RETURN jsonb_build_object('ok',false,'raison','commande_invalide');END IF;
 params:=jsonb_build_object('action',p_action,'pa',p_pa,'cost',p_cost);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'enigme_objet',params);
 IF v IS NOT NULL THEN RETURN v||jsonb_build_object('enigme',a.enigme1,'changement',false);END IF;
 e:=CASE WHEN jsonb_typeof(a.enigme1)='object' THEN a.enigme1 ELSE '{"etape":"non_commencee","variante":null}'::jsonb END;
 IF p_action='verifier' THEN
  IF p_pa IS DISTINCT FROM 0 OR p_cost IS DISTINCT FROM 0 THEN RETURN jsonb_build_object('ok',false,'raison','cout_non_declare');END IF;
  IF e->>'etape'='non_commencee' AND extract(epoch FROM now()-(a.created_at AT TIME ZONE 'UTC'))>=3*86400
   AND NOT EXISTS(SELECT 1 FROM public.inventaire_actions_recus WHERE acteur=a.name AND action='enigme_objet' AND resultat->>'statut'='declenchee') THEN
   variante:=(ARRAY['maire','criminel','entrepreneur','plume'])[floor(random()*4)::integer+1];
   e:=jsonb_build_object('etape','declenchee','variante',variante,'dateDeclenchement',now());
   IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(a.inventory) i WHERE i->>'calepinEnigme1'='true') THEN
    SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='enigme:calepin';
   END IF;
   changement:=true;statut:='declenchee';
  ELSIF e->>'etape'='declenchee' AND extract(epoch FROM now()-(a.created_at AT TIME ZONE 'UTC'))>=6*86400 THEN
   e:=e||jsonb_build_object('etape','relancee');changement:=true;statut:='relancee';
  END IF;
 ELSE
  IF (a.country,a.current_city,a.current_building,a.current_room) IS DISTINCT FROM ('republic','capitale','banque-nationale','accueil_banque') THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
  paiement:=public.payer_ordre(a.name,'presenter_autorisation_coffre',p_pa,p_cost);
  IF (paiement->>'ok')::boolean IS DISTINCT FROM true THEN RETURN paiement;END IF;
  -- Cout historique de presentation conserve meme si sans autorisation ou coffre deja vide.
  IF coalesce((e->>'autorisationCoffre')::boolean,false) IS NOT TRUE THEN statut:='sans_autorisation';
  ELSIF coalesce((e->>'coffreOuvert')::boolean,false) OR EXISTS(SELECT 1 FROM public.inventaire_actions_recus WHERE acteur=a.name AND action='enigme_objet' AND resultat->>'statut'='cle_remise') THEN statut:='deja_ouvert';
  ELSE
   SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='enigme:cle';
   e:=e||jsonb_build_object('coffreOuvert',true);changement:=true;statut:='cle_remise';
  END IF;
 END IF;
 IF o IS NOT NULL THEN
  v:=public.inventaire_deposer_interne(a.name,o,true);
  IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'enigme: depot refuse';END IF;
 ELSE SELECT jsonb_build_object('ok',true,'inventory',inventory,'revision',inventory_revision) INTO v FROM public.personnages_donnees WHERE name=a.name;END IF;
 IF changement THEN UPDATE public.personnages_donnees SET enigme1=e WHERE name=a.name;END IF;
 v:=v||jsonb_build_object('enigme',e,'changement',changement,'statut',statut,'paie',paiement);
 -- Ne pas grossir le registre pour chaque consultation sans changement ; un coffre paye
 -- conserve en revanche TOUJOURS son recu, quel que soit le resultat.
 IF changement OR p_action='coffre' THEN INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'enigme_objet',params,v,now());END IF;
 RETURN v;
END; $function$;
REVOKE ALL ON FUNCTION public.enigme_objet_recevoir(uuid,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.enigme_objet_recevoir(uuid,text,integer,integer) TO authenticated;
