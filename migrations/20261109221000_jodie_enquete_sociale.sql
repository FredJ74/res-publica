-- Jodie Moitout : invitation au Musee de la Ville de Luthecia et memoire partagee.
-- Migration additive : pas de remise a zero des enigmes ou inventaires existants.
-- La regle sociale inatteignable permet les compteurs et la relation sans interpellation automatique.
INSERT INTO public.pnj_social_jalons_regles (pnj_id, jalon, min_rencontres, max_conversations, rang)
VALUES ('jodie_moitout','jodie_sans_interpellation_automatique',2147483647,NULL,999)
ON CONFLICT DO NOTHING;

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
  v_eligible:=extract(epoch FROM (now()-(d.created_at AT TIME ZONE 'UTC'))) >= 3*86400
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
