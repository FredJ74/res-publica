-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027102825.
-- Eprouvee avant application en transaction annulee, au role authenticated (refus hors gouvernement et au mauvais prix, echec double, reussite rendue et rumeur resolue, qhs_pouvoir patche). Baseline NON reextrait.
-- ============================================================================
-- DEMENTI OFFICIEL ET RUMEURS POLITIQUES PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite » §1.1 (rumeurs_actives). Le « Dementi officiel » etait decide par
-- l'ecran : il tirait le jet (80 %), choisissait l'ampleur de la popularite rendue ou perdue
-- (jusqu'a 100 points, sur n'importe quel joueur), et marquait la rumeur resolue. La table etait
-- modifiable en entier par tout membre du gouvernement. La seule rumeur politique creee par le
-- jeu (torture au QHS) l'etait aussi par l'ecran.
--   * dementi_executer(rumeur, pa, cost) : poste du gouvernement, rumeur active visant soi-meme
--     ou un membre du gouvernement, paiement, jet, effet et annonce par le serveur. Regles
--     d'avant : reussite -> rumeur effacee et popularite perdue rendue ; echec -> perte doublee.
--   * qhs_pouvoir('torturer') pose aussi la sanction du Ministre (popularite et influence a 10)
--     et la rumeur ; l'ecran ne les ecrit plus.
--   * Les joueurs n'ecrivent plus rumeurs_actives.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.dementi_executer(p_rumeur_id text, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_poste text; v_pays text; v_rum jsonb; v_cible text; v_poste_cible text;
  v_perdu integer; v_paie jsonb; v_roll integer; v_reussi boolean; v_delta integer; v_res jsonb; v_pop numeric;
  c_gouv text[] := ARRAY['president','pm','min_int','min_fin','min_just','min_def','min_info','min_ae'];
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT poste ->> 'id', country INTO v_poste, v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF v_poste IS NULL OR NOT (v_poste = ANY (c_gouv)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_gouvernement'); END IF;
  SELECT data INTO v_rum FROM public.rumeurs_actives WHERE id = p_rumeur_id AND resolu = false FOR UPDATE;
  IF v_rum IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'rumeur_introuvable'); END IF;
  v_cible := v_rum ->> 'cible';
  SELECT poste ->> 'id' INTO v_poste_cible FROM public.personnages_donnees WHERE name = v_cible AND country = v_pays;
  IF NOT FOUND OR (v_cible IS DISTINCT FROM v_moi AND NOT (coalesce(v_poste_cible, '') = ANY (c_gouv))) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_hors_gouvernement'); END IF;

  v_paie := public.payer_ordre(v_moi, 'dementi', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_perdu := least(100, greatest(1, coalesce(CASE WHEN jsonb_typeof(v_rum -> 'popPerdu') = 'number'
                                                  THEN (v_rum ->> 'popPerdu')::numeric END, 15)::integer));
  v_roll := floor(random() * 100)::integer + 1;
  v_reussi := v_roll <= 80;
  v_delta := CASE WHEN v_reussi THEN v_perdu ELSE -least(100, v_perdu * 2) END;

  SELECT CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END
    INTO v_res FROM public.personnages_donnees WHERE name = v_cible FOR UPDATE;
  v_pop := least(100, greatest(0, coalesce(CASE WHEN jsonb_typeof(v_res -> 'pop') = 'number'
                                                 THEN (v_res ->> 'pop')::numeric END, 50) + v_delta));
  UPDATE public.personnages_donnees SET resources = jsonb_set(v_res, '{pop}', to_jsonb(v_pop)) WHERE name = v_cible;

  IF v_reussi THEN
    UPDATE public.rumeurs_actives SET resolu = true WHERE id = p_rumeur_id;
    PERFORM public.annonce_publique_interne(v_pays, '📢 La présidence dément officiellement les rumeurs concernant ' || v_cible || '.');
  ELSE
    PERFORM public.annonce_publique_interne(v_pays, '📢 Le démenti officiel de la présidence échoue, aggravant les soupçons sur ' || v_cible || '.');
  END IF;

  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'jet', v_roll, 'cible', v_cible, 'pop_cible', v_pop,
    'pa', v_paie -> 'pa', 'liquide', v_paie -> 'liquide', 'arg', v_paie -> 'arg', 'solde_national', v_paie -> 'solde_national');
END; $function$;
REVOKE ALL ON FUNCTION public.dementi_executer(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dementi_executer(text, integer, integer) TO authenticated;

-- Torture au QHS : la sanction du Ministre et la rumeur, ecrites par le serveur.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.qhs_pouvoir'::regproc);
  IF position('rumeurs_actives' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'  RETURN jsonb_build_object(''ok'', true, ''acte'', p_acte, ''cible'', v_nom);\nEND;',
      E'  -- Le Ministre en paie le prix : popularite et influence a 10, et une rumeur court (27/10/2026).\n'
      || E'  UPDATE public.personnages_donnees\n'
      || E'     SET resources = CASE WHEN jsonb_typeof(resources) = ''object'' THEN resources ELSE ''{}''::jsonb END\n'
      || E'                     || jsonb_build_object(''pop'', 10, ''inf'', 10)\n'
      || E'   WHERE name = v_acteur;\n'
      || E'  INSERT INTO public.rumeurs_actives (id, resolu, data)\n'
      || E'  VALUES (''rumeur-'' || replace(gen_random_uuid()::text, ''-'', ''''), false,\n'
      || E'          jsonb_build_object(''cible'', v_acteur, ''contenu'', ''Le Ministre de la Justice ferait torturer des détenus au QHS.'',\n'
      || E'                             ''auteur'', ''Anonyme'', ''jour'', public.jour_de_jeu_pays(v_pays), ''popPerdu'', 40));\n'
      || E'  RETURN jsonb_build_object(''ok'', true, ''acte'', p_acte, ''cible'', v_nom, ''pop_ministre'', 10, ''inf_ministre'', 10);\nEND;');
    IF position('rumeurs_actives' IN v_def) = 0 THEN
      RAISE EXCEPTION 'qhs_pouvoir : motif introuvable';
    END IF;
    EXECUTE v_def;
  END IF;
END $do$;

DROP POLICY IF EXISTS "dementi par un membre du gouvernement" ON public.rumeurs_actives;
DROP POLICY IF EXISTS "rumeur creee sur soi-meme" ON public.rumeurs_actives;
REVOKE INSERT, UPDATE, DELETE ON public.rumeurs_actives FROM anon, authenticated;
