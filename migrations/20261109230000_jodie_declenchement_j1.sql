-- L'enquete du musee demarre a J+1 (24h) apres la creation et apres la quete d'accueil.
-- Compatibilite : ne touche ni aux inventaires, ni aux dossiers etat existants ;
-- le rappel de Jodie reste calcule trois jours APRES son premier appel.
-- La condition d'accueil est limitee au PREMIER declenchement : une enquete deja ouverte reste jouable.
CREATE OR REPLACE FUNCTION public.enigme_objet_recevoir(p_requete uuid, p_action text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET "TimeZone" TO 'UTC'
AS $function$
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
  IF e->>'etape'='non_commencee' AND extract(epoch FROM now()-(a.created_at AT TIME ZONE 'UTC')) >=1*86400
   AND coalesce(a.quete_accueil->>'etape','') IN ('carriere_terminee','quete_terminee_sans_aide','refusee','presentation_en_cours','presentation_publiee')
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
 IF changement OR p_action='coffre' THEN INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'enigme_objet',params,v,now());END IF;
 RETURN v;
END; $function$;

CREATE OR REPLACE FUNCTION public.jodie_enquete_contact(p_action text, p_reponse text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp SET TimeZone TO 'UTC'
AS $$
DECLARE
  d public.personnages_donnees;
  e jsonb;
  c jsonb;
  m jsonb;
  v_type text:='aucun';
  v_lieu text;
  v_joueur text;
  v_dossier jsonb;
  v_paroles jsonb;
  v_eligible boolean;
BEGIN
  v_joueur:=public.mon_personnage();
  IF v_joueur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_action NOT IN ('etat','choix','rencontre','memoriser','conclusion') THEN
    RETURN jsonb_build_object('ok',false,'raison','action_inconnue'); END IF;
  SELECT * INTO d FROM public.personnages_donnees WHERE name=v_joueur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable'); END IF;
  e:=CASE WHEN jsonb_typeof(d.enigme1)='object' THEN d.enigme1 ELSE '{}'::jsonb END;
  c:=CASE WHEN jsonb_typeof(e->'jodie')='object' THEN e->'jodie' ELSE '{}'::jsonb END;
  v_dossier:=CASE WHEN jsonb_typeof(e->'dossier')='object' THEN e->'dossier' ELSE '{}'::jsonb END;
  SELECT memoire INTO m FROM public.pnj_social_relations WHERE pnj_id='jodie_moitout' AND joueur=v_joueur;
  v_lieu:=m->>'premier_echange_lieu';
  v_eligible:=extract(epoch FROM (now()-(d.created_at AT TIME ZONE 'UTC')))  >= 1*86400
    AND e->>'etape' IN ('declenchee','relancee','resolue');

  IF p_action='rencontre' THEN
    IF (d.country,d.current_city) IS DISTINCT FROM ('republic','capitale')
      OR d.current_building NOT IN ('marche','la-tribune') THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
    v_lieu:=CASE WHEN d.current_building='marche' THEN 'marche' ELSE 'autruche' END;
    INSERT INTO public.pnj_social_relations(pnj_id,joueur,rencontres,memoire)
      VALUES ('jodie_moitout',v_joueur,1,jsonb_build_object('premier_echange_lieu',v_lieu))
    ON CONFLICT (pnj_id,joueur) DO UPDATE SET
      memoire=CASE WHEN public.pnj_social_relations.memoire ? 'premier_echange_lieu'
        THEN public.pnj_social_relations.memoire
        ELSE public.pnj_social_relations.memoire || jsonb_build_object('premier_echange_lieu',v_lieu) END,
      derniere_le=now();
  END IF;

  IF p_action='memoriser' THEN
    IF p_reponse IS NULL OR length(btrim(p_reponse))<1 OR length(p_reponse)>500 THEN
      RETURN jsonb_build_object('ok',false,'raison','texte_invalide'); END IF;
    IF NOT v_eligible AND NOT ((d.country,d.current_city) = ('republic','capitale')
      AND d.current_building IN ('marche','la-tribune')) THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_de_conversation'); END IF;
    -- On conserve seulement des propos du PJ, et non des faits avérés ou des paroles inventées.
    INSERT INTO public.pnj_social_relations(pnj_id,joueur,rencontres)
      VALUES ('jodie_moitout',v_joueur,1) ON CONFLICT (pnj_id,joueur) DO NOTHING;
    SELECT memoire INTO m FROM public.pnj_social_relations
      WHERE pnj_id='jodie_moitout' AND joueur=v_joueur FOR UPDATE;
    v_paroles:=CASE WHEN jsonb_typeof(m->'paroles_pj')='array' THEN m->'paroles_pj' ELSE '[]'::jsonb END;
    v_paroles:=v_paroles || jsonb_build_array(left(btrim(p_reponse),350));
    IF jsonb_array_length(v_paroles)>6 THEN
      SELECT jsonb_agg(t.val ORDER BY t.n) INTO v_paroles
        FROM jsonb_array_elements(v_paroles) WITH ORDINALITY AS t(val,n)
        WHERE t.n > jsonb_array_length(v_paroles)-6;
    END IF;
    UPDATE public.pnj_social_relations SET
      memoire=jsonb_set(coalesce(memoire,'{}'::jsonb),'{paroles_pj}',v_paroles,true),
      derniere_le=now()
      WHERE pnj_id='jodie_moitout' AND joueur=v_joueur;
  END IF;

  IF v_eligible AND e->>'etape'='resolue' AND NOT (c ? 'conclusion') THEN
    v_type:='conclusion';
  ELSIF v_eligible AND e->>'etape' IN ('declenchee','relancee') THEN
    IF NOT (c ? 'premierLe') THEN
      v_type:='premier';
    ELSIF NOT (c ? 'rappelLe')
      AND v_dossier = '{}'::jsonb
      AND extract(epoch FROM now()-(c->>'premierLe')::timestamptz)>=3*86400 THEN
      v_type:='rappel';
    END IF;
  END IF;

  IF p_action='choix' THEN
    IF p_reponse NOT IN ('accepte','refuse') OR v_type NOT IN ('premier','rappel') THEN
      RETURN jsonb_build_object('ok',false,'raison','choix_invalide'); END IF;
    IF v_type='premier' THEN
      c:=c||jsonb_build_object('premierLe',now(),'choix',p_reponse);
    ELSE
      c:=c||jsonb_build_object('rappelLe',now(),'rappelChoix',p_reponse);
    END IF;
  ELSIF p_action='conclusion' THEN
    IF v_type<>'conclusion' OR p_reponse NOT IN ('informer','garder') THEN
      RETURN jsonb_build_object('ok',false,'raison','conclusion_invalide'); END IF;
    c:=c||jsonb_build_object('conclusion',p_reponse,'conclusionLe',now());
  END IF;

  IF p_action IN ('choix','conclusion') THEN
    e:=jsonb_set(e,'{jodie}',c,true);
    UPDATE public.personnages_donnees SET enigme1=e WHERE name=v_joueur;
    v_type:='aucun';
  END IF;
  RETURN jsonb_build_object('ok',true,'type',v_type,'contact',c,
    'lieu_precedent',(SELECT memoire->>'premier_echange_lieu' FROM public.pnj_social_relations
      WHERE pnj_id='jodie_moitout' AND joueur=v_joueur),
    'etape',e->>'etape');
END $$;
REVOKE ALL ON FUNCTION public.jodie_enquete_contact(text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.jodie_enquete_contact(text,text) TO authenticated;
