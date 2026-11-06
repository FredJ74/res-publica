-- #379 : grâce présidentielle — paiement, décision, libération, QHS et POP atomiques.
-- Ne pas appliquer tant que la PR #379 / garde POP-INF n'est pas certifiée.
CREATE OR REPLACE FUNCTION public.grace_presidentielle_decider(
  p_demande_id text, p_accepte boolean
) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_president text;
  v_pays text;
  v_dossier public.demandes_grace%ROWTYPE;
  v_condamne text;
  v_detention jsonb;
  v_paiement jsonb;
  v_cloture jsonb := '{}'::jsonb;
  v_pop_avant numeric;
  v_pop_apres numeric;
  v_pop_delta integer := 0;
  v_ressources jsonb;
BEGIN
  IF auth.uid() IS NULL OR public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');
  END IF;
  v_president := public.exiger_poste('president');
  SELECT country INTO v_pays FROM public.personnages_donnees
    WHERE name = v_president;
  IF p_demande_id IS NULL OR btrim(p_demande_id) = '' OR p_accepte IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','decision_invalide');
  END IF;

  SELECT * INTO v_dossier FROM public.demandes_grace
    WHERE id = p_demande_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok',false,'raison','dossier_introuvable');
  END IF;
  IF v_dossier.data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_pays');
  END IF;
  IF v_dossier.statut <> 'attente' THEN
    RETURN jsonb_build_object('ok',true,'rejoue',true,
      'statut',v_dossier.statut,'demande_id',p_demande_id);
  END IF;

  v_condamne := nullif(btrim(v_dossier.data->>'nomCondamne'),'');
  IF v_condamne IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','condamne_introuvable');
  END IF;

  IF p_accepte THEN
    SELECT est_emprisonne INTO v_detention FROM public.personnages_donnees
      WHERE name = v_condamne FOR UPDATE;
    IF v_detention IS NULL OR jsonb_typeof(v_detention) <> 'object' THEN
      RETURN jsonb_build_object('ok',false,'raison','non_detenu');
    END IF;
  END IF;

  -- Le coût réel est celui du registre, jamais une valeur fournie par le navigateur.
  v_paiement := public.payer_ordre_interne(v_president,'gracier',2,0);
  IF coalesce((v_paiement->>'ok')::boolean,false) IS NOT TRUE THEN
    RETURN coalesce(v_paiement,jsonb_build_object('ok',false,'raison','paiement_refuse'));
  END IF;

  IF p_accepte THEN
    -- Clôture canonique, incluant le registre QHS, dans la même transaction.
    v_cloture := public.detention_clore_interne(v_condamne,'grace_presidentielle',NULL);
    SELECT coalesce(resources,'{}'::jsonb) INTO v_ressources
      FROM public.personnages_donnees WHERE name=v_president FOR UPDATE;
    v_pop_avant := least(100,greatest(0,coalesce((v_ressources->>'pop')::numeric,0)));
    v_pop_delta := CASE WHEN v_pop_avant > 50 THEN 5 ELSE -2 END;
    v_pop_apres := least(100,greatest(0,v_pop_avant+v_pop_delta));
    UPDATE public.personnages_donnees
       SET resources = jsonb_set(v_ressources - 'popBase' - 'infBase',
                                 '{pop}',to_jsonb(v_pop_apres),true)
     WHERE name=v_president;
  END IF;

  UPDATE public.demandes_grace
     SET statut = CASE WHEN p_accepte THEN 'acceptee' ELSE 'refusee' END
   WHERE id=p_demande_id AND statut='attente';
  IF NOT FOUND THEN RAISE EXCEPTION 'grace_etat_concurrent: %',p_demande_id; END IF;

  RETURN jsonb_build_object(
    'ok',true,'rejoue',false,'accepte',p_accepte,
    'condamne',v_condamne,'libere',p_accepte,
    'pop_delta',v_pop_delta,'pop',v_pop_apres,
    'demande_id',p_demande_id,'statut',
    CASE WHEN p_accepte THEN 'acceptee' ELSE 'refusee' END
  ) || v_paiement || v_cloture;
END;
$$;
REVOKE ALL ON FUNCTION public.grace_presidentielle_decider(text,boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.grace_presidentielle_decider(text,boolean)
  TO authenticated;

-- L'ancien raccourci libère sans dossier ni paiement. Fermer cette ancienne porte.
REVOKE ALL ON FUNCTION public.presidence_gracier(text,integer)
  FROM PUBLIC, anon, authenticated;
