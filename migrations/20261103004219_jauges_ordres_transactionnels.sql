-- #379 : adaptateurs des ordres existants ; aucun delta choisi par le navigateur.
-- Ne ferme PAS encore les sauvegardes : les autres producteurs doivent être raccordés.
CREATE TABLE IF NOT EXISTS public.jauges_actions_recus (
  acteur text NOT NULL,
  requete uuid NOT NULL,
  ordre text NOT NULL,
  contexte jsonb NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur, requete)
);
ALTER TABLE public.jauges_actions_recus ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.jauges_ordre_executer(p_ordre text,p_requete uuid,p_contexte jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp
AS $function$
DECLARE a public.personnages_donnees; rec public.jauges_actions_recus;
  pa_cout integer; argent_cout integer:=0; pop_gain integer:=0; inf_gain integer:=0;
  paiement jsonb; perimetre jsonb; sortie jsonb; ressources jsonb;
BEGIN
  IF p_requete IS NULL OR p_contexte IS NULL OR jsonb_typeof(p_contexte)<>'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','requete_invalide'); END IF;
  SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT * INTO rec FROM public.jauges_actions_recus WHERE acteur=a.name AND requete=p_requete;
  IF FOUND THEN
    IF rec.ordre IS DISTINCT FROM p_ordre OR rec.contexte IS DISTINCT FROM p_contexte THEN
      RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
    -- Le verdict d'action est stable ; la fiche retournée est celle d'aujourd'hui.
    RETURN rec.resultat || jsonb_build_object('rejeu',true,'pop',a.resources->'pop','inf',a.resources->'inf',
      'pa',a.pa,'hp',a.hp,'moral',a.moral,'arg',a.arg,'liquide',a.liquide);
  END IF;
  CASE p_ordre
  WHEN 'observer_debats' THEN
    IF a.current_building IS DISTINCT FROM 'assemblee' THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
    IF p_contexte<>'{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    pa_cout:=1; inf_gain:=CASE WHEN a.career='press' THEN 1 ELSE 0 END;
  WHEN 'consulter_dossiers_gouv' THEN
    IF a.current_building IS DISTINCT FROM 'palais-gouvernement' THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
    IF nullif(a.poste->>'id','') IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','poste_requis'); END IF;
    IF p_contexte<>'{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    pa_cout:=2; inf_gain:=2;
  WHEN 'inspecter_troupes' THEN
    IF p_contexte NOT IN ('{"niveau":"revue"}'::jsonb,'{"niveau":"detaillee"}'::jsonb) THEN
      RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    perimetre:=public.militaire_inspection_perimetre();
    IF coalesce((perimetre->>'ok')::boolean,false) IS NOT TRUE THEN RETURN perimetre; END IF;
    pa_cout:=CASE WHEN p_contexte->>'niveau'='revue' THEN 1 ELSE 2 END;
    inf_gain:=CASE WHEN p_contexte->>'niveau'='revue' THEN 3 ELSE 5 END;
  WHEN 'greve_faim' THEN
    IF a.current_building IS DISTINCT FROM 'qhs-prison' OR jsonb_typeof(a.est_emprisonne) IS DISTINCT FROM 'object'
       OR a.est_emprisonne='{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','detention_requise');END IF;
    IF p_contexte<>'{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    pa_cout:=0;pop_gain:=3;
  ELSE RETURN jsonb_build_object('ok',false,'raison','ordre_non_raccorde');
  END CASE;
  paiement:=public.payer_ordre(a.name,p_ordre,pa_cout,argent_cout);
  IF coalesce((paiement->>'ok')::boolean,false) IS NOT TRUE THEN RETURN paiement;END IF;
  -- Relire après le paiement : aucun snapshot antérieur ne remplace les PA ou soldes.
  SELECT * INTO a FROM public.personnages_donnees WHERE name=a.name FOR UPDATE;
  ressources:=coalesce(a.resources,'{}'::jsonb)-'popBase'-'infBase';
  IF pop_gain<>0 THEN ressources:=jsonb_set(ressources,'{pop}',to_jsonb(least(100,greatest(0,coalesce((ressources->>'pop')::numeric,0)+pop_gain))));END IF;
  IF inf_gain<>0 THEN ressources:=jsonb_set(ressources,'{inf}',to_jsonb(least(100,greatest(0,coalesce((ressources->>'inf')::numeric,0)+inf_gain))));END IF;
  UPDATE public.personnages_donnees SET resources=ressources,
    hp=CASE WHEN p_ordre='greve_faim' THEN greatest(1,hp-5) ELSE hp END
    WHERE name=a.name RETURNING * INTO a;
  sortie:=jsonb_build_object('ok',true,'contrat_jauges',1,'acteur',a.name,'requete',p_requete,'ordre',p_ordre,
    'pop',a.resources->'pop','inf',a.resources->'inf','gain_pop',pop_gain,'gain_inf',inf_gain,
    'pa',a.pa,'hp',a.hp,'moral',a.moral,'arg',a.arg,'liquide',a.liquide,'perimetre',perimetre);
  INSERT INTO public.jauges_actions_recus(acteur,requete,ordre,contexte,resultat)VALUES(a.name,p_requete,p_ordre,p_contexte,sortie);
  RETURN sortie;
END;$function$;
REVOKE ALL ON FUNCTION public.jauges_ordre_executer(text,uuid,jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.jauges_ordre_executer(text,uuid,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
