-- #379 : écouter une trace vraie, même tarif et mêmes probabilités qu'à l'écran.
-- Aucune rumeur fabriquée, aucune identité réelle d'un agent ajoutée à la trace.
CREATE OR REPLACE FUNCTION public.rumeur_ecoute_jauges_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $f$
DECLARE a public.personnages_donnees;taux integer;cout_pa integer;source text;trace record;fait jsonb;gain integer:=0;
BEGIN
 IF p_acteur IS DISTINCT FROM public.mon_personnage()THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 SELECT * INTO a FROM public.personnages_donnees WHERE name=p_acteur;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable');END IF;
 IF NOT EXISTS(SELECT 1 FROM public.villes WHERE pays=a.country AND ville=a.current_city)THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 -- Déclarations effectives de data.js : hôtels des capitales, Assemblées,
 -- bar des Pêcheurs et Capitaine Sauvage. Aucun nouveau lieu n'est activé.
 IF a.current_city='capitale'AND a.current_building='hotel-republica'AND a.current_room='restaurant'THEN taux:=95;cout_pa:=0;
 ELSIF a.current_city='capitale'AND a.current_building='hotel-republica'AND a.current_room='bar'THEN taux:=90;cout_pa:=0;source:='Marco';
 ELSIF a.current_city='capitale'AND a.current_building='assemblee'AND a.current_room='couloirs'THEN taux:=70;cout_pa:=1;
 ELSIF a.country='republic'AND a.current_city='ville_a'AND a.current_building='bar-des-pecheurs'AND a.current_room='salle_bar'THEN taux:=85;cout_pa:=0;source:='Marin Dulac';
 ELSIF a.country='republic'AND a.current_city='ville_a'AND a.current_building='capitaine-sauvage'AND a.current_room='salle_principale'THEN taux:=95;cout_pa:=0;
 ELSE RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 IF random()*100<taux THEN
  -- Même population de tirage, y compris les types sans formulation : ne pas
  -- augmenter subrepticement la chance de gain en filtrant ces types avant le jet.
  SELECT t.type_action,t.auteur,t.cible INTO trace FROM public.actions_tracables t
   WHERE t.country=a.country AND t.city=a.current_city AND t.auteur<>a.name
     AND t.jour_expiration>=public.jour_de_jeu_pays(a.country)ORDER BY random()LIMIT 1;
  IF FOUND AND trace.type_action=ANY(ARRAY['consommation_estadine','consommation_drogue','achat_drogue','don','don_objet','vol','assassinat','corruption','escort','achat_arme_illegal','acheter_bombe_illegale','incendier','utiliser_explosifs','empoisonnement','hooliganisme','torture_qhs','diner_affaires_accepte','diner_affaires_refuse','boire_verre_accepte','boire_verre_refuse','nuit_escort','plainte_sans_suite','plainte_enquete','plainte_confirmee','cellules_fragilisees','fausse_rumeur','presence_suspecte'])THEN
   fait:=jsonb_build_object('type_action',trace.type_action,'auteur',trace.auteur,'cible',trace.cible);gain:=1;
  END IF;
 END IF;
 source:=coalesce(source,(ARRAY['Le Commissaire','Un député','Un journaliste','Un commerçant','Un inconnu'])[floor(random()*5)::integer+1]);
 RETURN jsonb_build_object('ok',true,'pa_cout',cout_pa,'gain_inf',gain,'rumeur',fait,'source_rumeur',source);
END;$f$;
REVOKE ALL ON FUNCTION public.rumeur_ecoute_jauges_interne(text)FROM PUBLIC,anon,authenticated,service_role;
