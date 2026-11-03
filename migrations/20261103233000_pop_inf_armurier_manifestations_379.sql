-- #379, lot 2 (Claude, 03/11/2026) : POP/INF décidées par le serveur pour
--  * la corruption de l'armurier (registre des ventes) : 30 %, 100 FR seulement si réussite,
--    +5 INF +5 POP ou -5 INF -5 POP ;
--  * le traitement d'une demande de manifestation par le ministre de l'Intérieur : 1 PA,
--    statut écrit ici, -8 POP au ministre en cas d'interdiction.
-- Formules d'origine de l'écran conservées. Dépend de 20261103230000.

DO $prevol$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.jauges_ordre_executer(text,uuid,jsonb)')
     AND position('hg379_presidence_v1' in prosrc)>0) THEN
  RAISE EXCEPTION '379_lot2_lot_presidence_absent'; END IF;
 IF to_regclass('public.demandes_manifestation') IS NULL THEN RAISE EXCEPTION '379_lot2_demandes_absentes'; END IF;
END $prevol$;

INSERT INTO public.ordres_couts(fn,pa,cost) VALUES ('corrompre_armurier#reussite',0,100),('traiter_manifestations',1,0)
ON CONFLICT DO NOTHING;

DO $patch$
DECLARE v_def text; v_ancre text; v_ajout text;
BEGIN
 v_def:=pg_get_functiondef('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure);
 IF position('hg379_lot2_v1' in v_def)>0 THEN RETURN; END IF;
 v_ancre:=E'  ELSE RETURN jsonb_build_object(''ok'',false,''raison'',''ordre_non_raccorde'');\n  END CASE;';
 v_ajout:=$a$
  -- hg379_lot2_v1
  WHEN 'corrompre_armurier' THEN
    IF p_contexte<>'{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    -- Mêmes deux comptoirs que l'ordre consulter_registre_armes du catalogue.
    IF a.current_building IS DISTINCT FROM 'armurerie' AND a.current_building IS DISTINCT FROM 'chasse-peche-psm' THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
    v_detecte:=floor(random()*100)::integer+1<=30;
    IF v_detecte THEN
      -- Les 100 FR ne sont pris qu'en cas de réussite, comme à l'origine.
      paiement:=public.payer_ordre(a.name,'corrompre_armurier#reussite',0,100);
      IF coalesce((paiement->>'ok')::boolean,false) IS NOT TRUE THEN RETURN paiement;END IF;
      pop_gain:=5; inf_gain:=5;
    ELSE pop_gain:=-5; inf_gain:=-5; END IF;
    pa_cout:=NULL;
    publication:=jsonb_build_object('corruption_reussie',v_detecte);
  WHEN 'manifestation_traiter' THEN
    IF p_contexte-ARRAY['id','autorise']<>'{}'::jsonb OR jsonb_typeof(p_contexte->'id') IS DISTINCT FROM 'string'
       OR jsonb_typeof(p_contexte->'autorise') IS DISTINCT FROM 'boolean' THEN
      RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    IF a.poste->>'id' IS DISTINCT FROM 'min_int' THEN RETURN jsonb_build_object('ok',false,'raison','poste_requis');END IF;
    -- Verrou sur la demande AVANT de payer : une demande déjà traitée ne coûte rien.
    PERFORM 1 FROM public.demandes_manifestation
     WHERE id=p_contexte->>'id' AND statut='attente' AND coalesce(data->>'pays',a.country)=a.country FOR UPDATE;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','demande_deja_traitee');END IF;
    paiement:=public.payer_ordre(a.name,'traiter_manifestations',1,0);
    IF coalesce((paiement->>'ok')::boolean,false) IS NOT TRUE THEN RETURN paiement;END IF;
    UPDATE public.demandes_manifestation
       SET statut=CASE WHEN (p_contexte->>'autorise')::boolean THEN 'autorisee' ELSE 'interdite' END
     WHERE id=p_contexte->>'id';
    pa_cout:=NULL;
    pop_gain:=CASE WHEN (p_contexte->>'autorise')::boolean THEN 0 ELSE -8 END;
    publication:=jsonb_build_object('statut',CASE WHEN (p_contexte->>'autorise')::boolean THEN 'autorisee' ELSE 'interdite' END);
$a$;
 IF (length(v_def)-length(replace(v_def,v_ancre,'')))/length(v_ancre)<>1 THEN RAISE EXCEPTION '379_lot2_ancre_dispatcher'; END IF;
 EXECUTE replace(v_def,v_ancre,v_ajout||v_ancre);
END $patch$;
NOTIFY pgrst,'reload schema';
