-- ============================================================================
-- INDICE DIPLOMATIQUE : LES ACTIONS NATIONALES QUI LE FONT VARIER PASSENT PAR LE SERVEUR
-- (25 octobre 2026, suite de 20261025120000 ; Fred : « garder toutes les variations existantes »)
-- ============================================================================
-- Chaque variation que le navigateur s'appliquait a lui-meme est desormais decidee ici :
--   * propagande d'Etat (tribune, deja serveur) : -5 pour le pays ;
--   * activation d'un cessez-le-feu (deja serveur) : +10, la premiere fois pour ce camp ;
--   * mobilisation nationale (Ministre de la Defense) : -5 pour chacun des autres pays ;
--   * banquet diplomatique (President) : chaque invite vient 7 fois sur 10, tire ici ;
--     tous venus : +8 ;
--   * reception d'Etat (President) : reussite tiree ici selon la popularite (comme avant) ; +5 ;
--   * reponse a une proposition diplomatique (Ministre AE du pays destinataire) : acceptee,
--     +12 (traite) ou +8 (negociation) pour les deux pays ; refusee, -12 / -8 pour le pays qui
--     refuse. Le serveur verifie la proposition et en change le statut.
-- Les couts PA de ces ordres tels que le navigateur les annonce sont declares ici quand ils
-- manquaient (les francs du banquet et de la reception sortent du budget de la Presidence,
-- comme avant) : sans eux, payer_ordre refusait l'ordre.
-- Le referendum, la signature unilaterale d'un traite, les sanctions, la declaration de guerre
-- et le cessez-le-feu « negocie » du vieux dispatcheur n'ont plus d'ordre dans le jeu : leur code
-- mort ne touche plus a l'indice.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('banquet_diplo', 3, 0), ('reception_etat', 2, 0),
  ('diplomatie_bilaterale', 1, 0), ('diplomatie_bilaterale', 2, 0), ('diplomatie_bilaterale', 3, 0)
ON CONFLICT DO NOTHING;

-- Propagande : -5.
DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'  RETURN jsonb_build_object(''ok'', true, ''topic'', v_topic, ''post'', v_post,';
  v_ajout text := E'  -- Indice Diplomatique (25/10/2026) : la propagande d''Etat coute 5 points au pays.\n  IF p_fn = ''propagande_etat'' THEN\n    PERFORM public.indice_diplomatique_varier_interne(a.pays, -5, ''propagande_etat'', v_moi);\n  END IF;\n\n';
BEGIN
  v_def := pg_get_functiondef('public.communication_officielle_publier(text,text,text,integer,integer,text,text,jsonb,boolean)'::regprocedure);
  IF position('indice_diplomatique_varier_interne' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_ajout || v_frag);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : fragment de communication_officielle_publier introuvable'; END IF;
  EXECUTE v_new;
END $mig$;

-- Cessez-le-feu : +10 la premiere fois que ce camp l'active.
DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'  RETURN jsonb_build_object(''ok'', true, ''pays'', v_pays, ''terminee'', v_tous);';
  v_ajout text := E'  -- Indice Diplomatique (25/10/2026) : +10, une fois par camp.\n  IF NOT (coalesce(v_cf -> ''actifPar'', ''{}''::jsonb) ? v_pays) THEN\n    PERFORM public.indice_diplomatique_varier_interne(v_pays, 10, ''cessez_le_feu'', public.mon_personnage());\n  END IF;\n';
BEGIN
  v_def := pg_get_functiondef('public.guerre_cessez_le_feu_activer(text)'::regprocedure);
  IF position('indice_diplomatique_varier_interne' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_ajout || v_frag);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : fragment de guerre_cessez_le_feu_activer introuvable'; END IF;
  EXECUTE v_new;
END $mig$;

-- Mobilisation, banquet, reception d'Etat : le serveur preleve les PA et fait varier l'indice.
CREATE OR REPLACE FUNCTION public.indice_diplomatique_ordre(p_fn text, p_pa integer, p_invites integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_paie jsonb; v_venus integer := 0; v_pop numeric; v_taux integer;
  v_reussi boolean := false; v_indice integer; i integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic'),
         coalesce(CASE WHEN jsonb_typeof(resources -> 'pop') = 'number' THEN (resources ->> 'pop')::numeric END, 50)
    INTO v_pays, v_pop FROM public.personnages_donnees WHERE name = v_moi;

  IF p_fn = 'mobilisation_nationale' THEN
    IF NOT public.mon_poste_est_dans('min_def', v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_defense'); END IF;
  ELSIF p_fn IN ('banquet_diplo', 'reception_etat') THEN
    IF NOT public.mon_poste_est_dans('president', v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_president'); END IF;
    IF p_fn = 'banquet_diplo' AND (coalesce(p_invites, 0) < 1 OR p_invites > 50) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'aucun_invite'); END IF;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_inconnu');
  END IF;

  v_paie := public.payer_ordre(v_moi, p_fn, p_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  IF p_fn = 'mobilisation_nationale' THEN
    PERFORM public.indice_diplomatique_varier_interne(d.pays, -5, 'mobilisation_' || v_pays, v_moi)
       FROM public.indices_diplomatiques d WHERE d.pays <> v_pays;
    v_reussi := true;
  ELSIF p_fn = 'banquet_diplo' THEN
    FOR i IN 1 .. p_invites LOOP
      IF random() < 0.7 THEN v_venus := v_venus + 1; END IF;
    END LOOP;
    v_reussi := v_venus = p_invites;
    IF v_reussi THEN PERFORM public.indice_diplomatique_varier_interne(v_pays, 8, 'banquet_diplomatique', v_moi); END IF;
  ELSE
    -- Meme formule qu'avant (doReceptionAvecBonus) : 80 % ajuste par la popularite, borne 5..95.
    v_taux := least(95, greatest(5, 80 + floor((CASE WHEN v_pop > 20 THEN floor(v_pop - 20) ELSE -floor(20 - v_pop) END) / 2)::integer));
    v_reussi := floor(random() * 100) + 1 <= v_taux;
    IF v_reussi THEN PERFORM public.indice_diplomatique_varier_interne(v_pays, 5, 'reception_etat', v_moi); END IF;
  END IF;

  SELECT valeur INTO v_indice FROM public.indices_diplomatiques WHERE pays = v_pays;
  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'venus', v_venus, 'invites', coalesce(p_invites, 0),
                            'indice', v_indice, 'paie', v_paie);
END; $function$;
REVOKE ALL ON FUNCTION public.indice_diplomatique_ordre(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.indice_diplomatique_ordre(text, integer, integer) TO authenticated;

-- Reponse a une proposition diplomatique : Ministre AE du pays destinataire, 1 PA.
CREATE OR REPLACE FUNCTION public.diplomatie_repondre(p_id text, p_accepte boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; r record; v_type text; v_gain integer; v_paie jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('min_ae', v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_ae'); END IF;
  SELECT * INTO r FROM public.propositions_diplomatiques WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR r.data ->> 'empireCible' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_introuvable'); END IF;
  IF r.statut <> 'en_attente' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_repondue'); END IF;
  v_type := r.data ->> 'type';
  v_gain := CASE v_type WHEN 'traite' THEN 12 WHEN 'negociation' THEN 8 ELSE 0 END;
  v_paie := public.payer_ordre(v_moi, 'diplomatie_bilaterale', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  UPDATE public.propositions_diplomatiques
     SET statut = CASE WHEN p_accepte THEN 'acceptee' ELSE 'refusee' END,
         data = data || jsonb_build_object('statut', CASE WHEN p_accepte THEN 'acceptee' ELSE 'refusee' END,
                                           'reponduPar', v_moi, 'reponduLe', now())
   WHERE id = p_id;
  IF p_accepte THEN
    PERFORM public.indice_diplomatique_varier_interne(r.data ->> 'empireProposeur', v_gain, 'accord_' || coalesce(v_type, '?'), v_moi);
    PERFORM public.indice_diplomatique_varier_interne(v_pays, v_gain, 'accord_' || coalesce(v_type, '?'), v_moi);
  ELSE
    PERFORM public.indice_diplomatique_varier_interne(v_pays, -v_gain, 'refus_' || coalesce(v_type, '?'), v_moi);
  END IF;
  RETURN jsonb_build_object('ok', true, 'statut', CASE WHEN p_accepte THEN 'acceptee' ELSE 'refusee' END,
                            'variation', CASE WHEN p_accepte THEN v_gain ELSE -v_gain END, 'paie', v_paie,
                            'proposition', r.data);
END; $function$;
REVOKE ALL ON FUNCTION public.diplomatie_repondre(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.diplomatie_repondre(text, boolean) TO authenticated;
