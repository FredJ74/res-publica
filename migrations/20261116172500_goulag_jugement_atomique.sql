-- Entrée judiciaire exclusivement réservée au juge de l'affaire.
-- Débit 2 PA et sentence dans UNE transaction ; refus = aucun débit.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_juger(
  p_affaire_id text,p_infraction text,p_jours integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_moi text:=public.mon_personnage(); v_j record; v_a record;
  v_calc jsonb; v_paiement jsonb; v_res jsonb; v_erreur jsonb;
  v_jours integer;
BEGIN
  IF auth.uid() IS NULL OR v_moi IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF coalesce(btrim(p_affaire_id),'')='' OR coalesce(btrim(p_infraction),'')='' THEN
    RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration c
      WHERE c.singleton AND c.active AND c.champignons_malus IS NOT NULL
        AND c.formule_arrestation IS NOT NULL AND c.camp_bucherons_noeud IS NOT NULL) THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  SELECT data,city,country INTO v_a FROM public.plaintes_en_cours WHERE id=p_affaire_id FOR UPDATE;
  IF NOT FOUND OR v_a.country<>'soviet' THEN
    RETURN jsonb_build_object('ok',false,'raison','affaire_hors_sovarka'); END IF;
  SELECT * INTO v_j FROM public.juge_de_la_ville(v_a.city);
  IF NOT FOUND OR v_j.nom IS DISTINCT FROM v_moi OR v_j.pays IS DISTINCT FROM 'soviet'
    OR NOT public.sovarka_est_titulaire_interne(v_moi,'juge') THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_juge_sovarka'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=v_moi AND country='soviet'
      AND user_id=auth.uid()) THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_juge_sovarka'); END IF;
  v_calc:=public.justice_peine_proposer(p_affaire_id,p_infraction,'qhs');
  IF coalesce((v_calc->>'ok')::boolean,false) IS NOT TRUE THEN RETURN v_calc; END IF;
  v_jours:=p_jours;
  -- Le juge choisit dans le barème ; ne jamais imposer le minimum à sa place.
  IF v_jours IS NULL OR v_jours<(v_calc->>'jours_min')::integer
    OR v_jours>(v_calc->>'jours_max')::integer THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_hors_bornes'); END IF;
  IF v_jours IS NULL OR v_jours<1 THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_invalide'); END IF;
  BEGIN
    v_paiement:=public.payer_ordre_interne(v_moi,'rendre_sentence',2,0,1);
    IF coalesce((v_paiement->>'ok')::boolean,false) IS NOT TRUE THEN
      v_erreur:=v_paiement;RAISE EXCEPTION USING ERRCODE='P2288',MESSAGE='paiement_refuse'; END IF;
    PERFORM set_config('rp.goulag_jugement_interne','valide',true);
    v_res:=public.justice_rendre_sentence(p_affaire_id,p_infraction,'qhs',v_jours,0);
    PERFORM set_config('rp.goulag_jugement_interne','',true);
    IF coalesce((v_res->>'ok')::boolean,false) IS NOT TRUE THEN
      v_erreur:=v_res;RAISE EXCEPTION USING ERRCODE='P2288',MESSAGE='sentence_refusee'; END IF;
  EXCEPTION WHEN SQLSTATE 'P2288' THEN
    RETURN v_erreur;
  END;
  RETURN v_res||jsonb_build_object('paiement',v_paiement,'lieu_detention','goulag');
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_juger(text,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_juger(text,text,integer) TO authenticated;
