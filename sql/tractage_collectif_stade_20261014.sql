-- Version exacte des fonctions installees dans Supabase, 14 octobre 2026.
-- Tentative: 1 PA + 1 tract; echec consomme; cibles PNJ de toute l'enceinte.
-- Bonus collectif de persuasion x1,5, plafonne a 100 %.
CREATE OR REPLACE FUNCTION public.tracts_electoraux_distribuer_collectif_interne(p_requete text, p_joueur text, p_cycle_id text, p_candidat text, p_sens text, p_pnj_nom text, p_vol_pnj integer, p_instant timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej     jsonb;
  v_p       record;
  v_c       record;
  v_d       jsonb;
  v_ms      bigint;
  v_tour    bigint;
  v_ville   text;
  v_nom     text;
  v_cle     text;
  v_taux    integer;
  v_jet     integer;
  v_sens    smallint;
  v_effet   smallint;
  v_score   numeric;
  v_vol_pnj integer;
  v_inv     jsonb;
  v_new_inv jsonb; v_tract_pos integer; v_qty integer; v_pa_after integer;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'tract_electoral');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF p_sens NOT IN ('pour', 'contre') OR COALESCE(btrim(p_candidat), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;
  v_sens := CASE WHEN p_sens = 'pour' THEN 1 ELSE -1 END;

  SELECT country, current_city, stats, resources, inventory, pa INTO v_p FROM public.personnages_donnees WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  SELECT id, country, city, poste_id, data INTO v_c FROM public.cycles_electoraux WHERE id = p_cycle_id;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'));
  END IF;
  BEGIN v_d := v_c.data::jsonb; EXCEPTION WHEN OTHERS THEN v_d := NULL; END;
  IF v_d IS NULL OR jsonb_typeof(v_d) <> 'object' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_illisible'));
  END IF;
  IF COALESCE(v_c.poste_id, v_d ->> 'posteId', '') NOT IN ('president', 'maire', 'depute') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_non_concerne'));
  END IF;

  IF v_c.country IS DISTINCT FROM v_p.country THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_pays'));
  END IF;

  v_ms := floor(extract(epoch FROM p_instant) * 1000)::bigint;
  v_tour := CASE WHEN jsonb_typeof(v_d -> 'dateVote') = 'number' THEN (v_d ->> 'dateVote')::numeric::bigint END;
  IF v_tour IS NULL OR jsonb_typeof(v_d -> 'dateResultats') <> 'number'
     OR COALESCE((v_d ->> 'resultatsTraites')::boolean, false)
     OR v_ms < v_tour OR v_ms >= (v_d ->> 'dateResultats')::numeric::bigint THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_phase_vote'));
  END IF;

  IF extract(isodow FROM (p_instant AT TIME ZONE 'Europe/Paris')) <> 7 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pas_dimanche'));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(v_d -> 'candidats', '[]'::jsonb)) c WHERE c ->> 'nom' = p_candidat) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'candidat_hors_scrutin'));
  END IF;

  v_ville := NULLIF(COALESCE(v_c.city, v_d ->> 'city'), '');
  IF v_ville IS NOT NULL THEN
    IF v_p.current_city IS DISTINCT FROM v_ville THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_ville', 'ville_scrutin', v_ville));
    END IF;
  ELSIF COALESCE(v_p.current_city, '') NOT IN ('capitale', 'ville_a', 'ville_b', 'caserne', 'qhs') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_territoire'));
  END IF;

  v_inv := CASE WHEN jsonb_typeof(v_p.inventory) = 'array' THEN v_p.inventory ELSE '[]'::jsonb END;
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_inv) i
     WHERE i ->> 'type' = 'tract' AND i ->> 'cible' = p_candidat
       AND COALESCE(i ->> 'tractType', 'pour') = p_sens
       AND COALESCE(i ->> 'origineQuete', '') <> 'jean_lou'
       AND jsonb_typeof(i -> 'quantite') = 'number' AND (i ->> 'quantite')::numeric >= 1
  ) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'tract_absent'));
  END IF;

  IF COALESCE(v_p.pa, 0) < 1 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;

  v_nom := public.tracts_electoraux_nom_pnj(p_pnj_nom);
  IF v_nom = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pnj_invalide'));
  END IF;
  v_cle := v_c.country || ':' || COALESCE(v_p.current_city, '') || ':' || v_nom;

  PERFORM pg_advisory_xact_lock(hashtext('tract_pnj|' || p_cycle_id || '|' || v_tour || '|' || v_cle));
  IF EXISTS (SELECT 1 FROM public.elections_tracts_pnj WHERE cycle_id = p_cycle_id AND tour = v_tour AND pnj_cle = v_cle)
     OR (jsonb_typeof(v_d -> 'votesPNJ') = 'object' AND ((v_d -> 'votesPNJ') ? p_pnj_nom
         OR (v_d -> 'votesPNJ') ? replace(p_pnj_nom, '''', ''))) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_vote'));
  END IF;


  -- PNJ dynamiques connus de la base : la cible doit etre dans la meme piece.
  -- Les PNJ de decor non enregistres demandent un catalogue serveur avant validation.
  SELECT pm.car_vol INTO v_vol_pnj FROM public.pnj_membres pm
    WHERE lower(btrim(pm.nom))=lower(btrim(p_pnj_nom))
      AND pm.pays=v_c.country AND pm.ville=v_p.current_city
      AND pm.building_id=(SELECT current_building FROM public.personnages_donnees WHERE name=p_joueur)
      
      AND pm.statut='actif' LIMIT 1;
  IF NOT FOUND THEN
    SELECT c.car_vol INTO v_vol_pnj FROM public.tracts_pnj_catalogue c
    WHERE lower(btrim(c.nom))=lower(btrim(split_part(p_pnj_nom, ' (PNJ)', 1)))
      AND c.pays=v_c.country AND c.ville=v_p.current_city
      AND c.building_id=(SELECT current_building FROM public.personnages_donnees WHERE name=p_joueur)
      
    LIMIT 1;
    IF NOT FOUND THEN
      RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','pnj_absent_ou_non_verifiable'));
    END IF;
  END IF;
  -- Debiter PA et tract dans la meme transaction que le jet et la voix.
  SELECT (ord-1)::integer,(item->>'quantite')::integer
    INTO v_tract_pos,v_qty
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY t(item,ord)
   WHERE item->>'type'='tract' AND item->>'cible'=p_candidat
     AND coalesce(item->>'tractType','pour')=p_sens
     AND coalesce(item->>'origineQuete','')<>'jean_lou'
     AND (item->>'quantite') ~ '^[0-9]+$' AND (item->>'quantite')::integer>0
   ORDER BY ord LIMIT 1;
  IF v_tract_pos IS NULL THEN
    RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','tract_absent'));
  END IF;
  IF v_qty=1 THEN
    v_new_inv:=v_inv - v_tract_pos;
  ELSE
    v_new_inv:=jsonb_set(v_inv,ARRAY[v_tract_pos::text,'quantite'],to_jsonb(v_qty-1));
  END IF;
  UPDATE public.personnages_donnees SET inventory=v_new_inv,pa=pa-1 WHERE name=p_joueur AND pa>=1 RETURNING pa INTO v_pa_after;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','pa_insuffisants'));
  END IF;


  v_taux := public.tracts_electoraux_taux(
    public.assemblee_stat_base(v_p.stats, 'CHA'),
    CASE WHEN jsonb_typeof(v_p.resources -> 'inf') = 'number' THEN (v_p.resources ->> 'inf')::numeric ELSE 0 END,
    LEAST(30, GREATEST(0, COALESCE(v_vol_pnj, 10))));
  v_taux := least(100,ceil(v_taux * 1.5)::integer); v_jet := floor(random() * 100)::integer + 1;
  IF v_jet > v_taux THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'consomme', 1, 'pa', v_pa_after, 'inventory', v_new_inv, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens));
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('tract_cand|' || p_cycle_id || '|' || v_tour || '|' || p_candidat));
  IF v_sens = 1 THEN
    v_effet := 1;
  ELSE
    SELECT
      (SELECT count(*) FROM jsonb_each_text(CASE WHEN jsonb_typeof(v_d -> 'votes') = 'object' THEN v_d -> 'votes' ELSE '{}'::jsonb END) e WHERE e.value = p_candidat)
    + (SELECT count(*) FROM jsonb_each_text(CASE WHEN jsonb_typeof(v_d -> 'votesPNJ') = 'object' THEN v_d -> 'votesPNJ' ELSE '{}'::jsonb END) e WHERE e.value = p_candidat)
    + COALESCE((SELECT sum(effet) FROM public.elections_tracts_pnj WHERE cycle_id = p_cycle_id AND tour = v_tour AND candidat = p_candidat), 0)
    INTO v_score;
    v_effet := CASE WHEN v_score >= 1 THEN -1 ELSE 0 END;
  END IF;

  INSERT INTO public.elections_tracts_pnj (cycle_id, tour, pnj_cle, pnj_nom, candidat, sens, effet, joueur)
  VALUES (p_cycle_id, v_tour, v_cle, p_pnj_nom, p_candidat, v_sens, v_effet, p_joueur);

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'reussi', true, 'consomme', 1, 'pa', v_pa_after, 'inventory', v_new_inv, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens,
    'effet', v_effet, 'tour', v_tour));
END;
$function$


CREATE OR REPLACE FUNCTION public.tracts_electoraux_distribuer_collectif(p_requete text, p_joueur text, p_cycle_id text, p_candidat text, p_sens text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_prev jsonb;v_p record;v_max integer;v_n text;v_r jsonb;
v_list text[];v_attempts integer:=0;v_success integer:=0;v_qty integer;
v_inv jsonb;v_pa integer;
BEGIN
 PERFORM public.exiger_acteur(p_joueur);
 v_prev:=public.assemblee_requete_ouvrir(p_requete,p_joueur,'tract_electoral_collectif');
 IF v_prev IS NOT NULL THEN RETURN v_prev; END IF;
 SELECT country,current_city,current_building,current_room,inventory,pa INTO v_p
 FROM public.personnages_donnees WHERE name=p_joueur FOR UPDATE;
 IF NOT FOUND OR v_p.current_building IS DISTINCT FROM 'stade' THEN
  RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','hors_stade'));
 END IF;
 SELECT coalesce(sum((i->>'quantite')::integer),0) INTO v_qty
 FROM jsonb_array_elements(coalesce(v_p.inventory,'[]'::jsonb)) i
 WHERE i->>'type'='tract' AND i->>'cible'=p_candidat
 AND coalesce(i->>'tractType','pour')=p_sens
 AND coalesce(i->>'origineQuete','')<>'jean_lou'
 AND (i->>'quantite')~'^[0-9]+$';
 v_max:=least(coalesce(v_p.pa,0),coalesce(v_qty,0));
 IF v_max<1 THEN
  RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison',CASE WHEN v_qty<1 THEN 'tract_absent' ELSE 'pa_insuffisants' END));
 END IF;
 SELECT array_agg(nom ORDER BY nom) INTO v_list FROM (
 SELECT c.nom FROM public.tracts_pnj_catalogue c WHERE c.pays=v_p.country
 AND c.ville=v_p.current_city AND c.building_id='stade'
 UNION
 SELECT m.nom FROM public.pnj_membres m WHERE m.pays=v_p.country
 AND m.ville=v_p.current_city AND m.building_id='stade'
 AND m.statut='actif') x;
 IF coalesce(array_length(v_list,1),0)=0 THEN
  RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','aucune_cible'));
 END IF;
 IF coalesce(v_p.pa,0) < least(v_qty,coalesce(array_length(v_list,1),0)) THEN
  RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','pa_insuffisants'));
 END IF;
 FOREACH v_n IN ARRAY v_list LOOP
  EXIT WHEN v_attempts>=v_max;
  v_r:=public.tracts_electoraux_distribuer_collectif_interne(
   md5(p_requete || ':' || v_n || ':' || v_attempts::text),
   p_joueur,p_cycle_id,p_candidat,p_sens,v_n,NULL,now());
  IF coalesce((v_r->>'ok')::boolean,false) THEN
   v_attempts:=v_attempts+1;
   IF coalesce((v_r->>'reussi')::boolean,false) THEN v_success:=v_success+1; END IF;
   v_inv:=v_r->'inventory';v_pa:=(v_r->>'pa')::integer;
  ELSIF v_r->>'raison' NOT IN ('deja_vote','pnj_absent_ou_non_verifiable') THEN
   IF v_attempts=0 THEN RETURN public.assemblee_requete_clore(p_requete,v_r); END IF;
   EXIT;
  END IF;
 END LOOP;
 RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object(
 'ok',true,'essais',v_attempts,'reussites',v_success,
 'inventory',coalesce(v_inv,v_p.inventory),'pa',coalesce(v_pa,v_p.pa)));
END $function$


REVOKE ALL ON FUNCTION public.tracts_electoraux_distribuer_collectif_interne(text,text,text,text,text,text,integer,timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tracts_electoraux_distribuer_collectif(text,text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.tracts_electoraux_distribuer_collectif(text,text,text,text,text) TO authenticated;
