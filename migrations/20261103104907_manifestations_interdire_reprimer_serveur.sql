-- =============================================================================================
-- INTERDIRE ET RÉPRIMER UNE MANIFESTATION : PORTES SERVEUR (Claude, 03/11/2026)
-- =============================================================================================
-- Relevé du 03/11 (RELAIS.md, point 4, table `indices_villes`) : tout joueur identifié pouvait
-- réécrire le blob d'indices d'une ville (Sécurité, Social, Moral…) par upsert. Les deux ordres
-- du Ministre de l'Intérieur passaient par là, et « Réprimer » écrivait en plus PV et VOL des
-- autres joueurs par la vue `personnages` (refusé depuis le chantier B : seul le ministre était
-- réellement touché).
--
-- Deux portes, barème d'origine conservé (aucune décision de game design nouvelle) :
--   . manifestation_interdire(p_ville, p_sujet) — 2 PA : Social −5 dans la ville ciblée,
--     interdiction inscrite au budget municipal pour 3 jours (manifestationInterdite) ;
--   . manifestation_reprimer(p_ville, p_sujet) — 3 PA, impossible si un syndicat de policiers
--     du pays est en grève : Social −5 / Sécurité +5 (−8 / +8 si une interdiction y court
--     encore, qui est alors levée) ; chaque PJ présent dans la ville : PV −10 et VOL −10
--     (planchers 1).
-- Autorité : titulaire du poste min_int du pays (mon_poste_est_dans). Ville : une des villes
-- suivies par indices_villes. Les coûts n'étaient pas déclarés (payer_ordre les refusait) :
-- ils le sont, aux valeurs de l'écran.
-- =============================================================================================

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('interdire_manif', 2, 0), ('reprimer_manif', 3, 0)
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.manifestation_interdire(p_ville text, p_sujet text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_jour integer; v_paie jsonb; v_sujet text; v_cle text; v_indices jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, coalesce(day, 1) INTO v_pays, v_jour FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('min_int', v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_interieur');
  END IF;
  v_cle := v_pays || '_' || coalesce(p_ville, '');
  IF NOT EXISTS (SELECT 1 FROM public.indices_villes WHERE id = v_cle) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ville_inconnue');
  END IF;
  v_sujet := left(coalesce(nullif(btrim(p_sujet), ''), 'Manifestation non precisee'), 200);

  v_paie := public.payer_ordre(v_moi, 'interdire_manif', 2, 0);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;

  PERFORM public.indice_ville_ajuster_interne(v_pays, p_ville, 'social', -5);
  INSERT INTO public.budgets_municipaux (id, data, updated_at)
  VALUES (v_cle, jsonb_build_object('key', v_cle, 'tauxFoncier', 0.05), now())
  ON CONFLICT (id) DO NOTHING;
  UPDATE public.budgets_municipaux
     SET data = coalesce(data, '{}'::jsonb) || jsonb_build_object('manifestationInterdite',
                  jsonb_build_object('sujet', v_sujet, 'jour', v_jour, 'expireJour', v_jour + 3, 'par', v_moi)),
         updated_at = now()
   WHERE id = v_cle;

  SELECT data INTO v_indices FROM public.indices_villes WHERE id = v_cle;
  RETURN jsonb_build_object('ok', true, 'paiement', v_paie, 'ville', p_ville, 'sujet', v_sujet,
                            'indices', v_indices, 'expire_jour', v_jour + 3);
END $function$;

CREATE OR REPLACE FUNCTION public.manifestation_reprimer(p_ville text, p_sujet text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_jour integer; v_paie jsonb; v_sujet text; v_cle text; v_indices jsonb;
        v_interdite jsonb; v_recente boolean; v_delta integer; v_touches integer := 0; v_fiche record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, coalesce(day, 1) INTO v_pays, v_jour FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('min_int', v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_interieur');
  END IF;
  v_cle := v_pays || '_' || coalesce(p_ville, '');
  IF NOT EXISTS (SELECT 1 FROM public.indices_villes WHERE id = v_cle) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ville_inconnue');
  END IF;
  -- Règle « Grèves » (§9, 3 septembre 2026) : syndicat de policiers en grève = pas de répression.
  IF EXISTS (SELECT 1 FROM public.organisations o
              WHERE o.data::jsonb->>'type' = 'syndicale' AND o.country_origine = v_pays
                AND o.data::jsonb->>'corpsMetier' = 'police'
                AND (coalesce((o.data::jsonb->'greve'->>'actif')::boolean, false)
                     OR o.data::jsonb->>'greveGeneraleStatut' = 'actif')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'police_en_greve');
  END IF;
  v_sujet := left(coalesce(nullif(btrim(p_sujet), ''), 'Rassemblement non precise'), 200);

  v_paie := public.payer_ordre(v_moi, 'reprimer_manif', 3, 0);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;

  SELECT data->'manifestationInterdite' INTO v_interdite FROM public.budgets_municipaux WHERE id = v_cle FOR UPDATE;
  v_recente := v_interdite IS NOT NULL AND jsonb_typeof(v_interdite) = 'object'
               AND coalesce((v_interdite->>'expireJour')::integer, 0) >= v_jour;
  v_delta := CASE WHEN v_recente THEN 8 ELSE 5 END;
  PERFORM public.indice_ville_ajuster_interne(v_pays, p_ville, 'social', -v_delta);
  PERFORM public.indice_ville_ajuster_interne(v_pays, p_ville, 'isn', v_delta);
  IF v_recente THEN
    UPDATE public.budgets_municipaux SET data = data - 'manifestationInterdite', updated_at = now() WHERE id = v_cle;
  END IF;

  FOR v_fiche IN SELECT name FROM public.personnages_donnees
                  WHERE country = v_pays AND coalesce(current_city, 'capitale') = p_ville FOR UPDATE LOOP
    UPDATE public.personnages_donnees
       SET hp = greatest(1, coalesce(hp, 100) - 10),
           stats = coalesce(stats, '{}'::jsonb) || jsonb_build_object('VOL',
                     greatest(1, coalesce(CASE WHEN jsonb_typeof(stats->'VOL') = 'number' THEN (stats->>'VOL')::integer END, 6) - 10))
     WHERE name = v_fiche.name;
    v_touches := v_touches + 1;
  END LOOP;

  SELECT data INTO v_indices FROM public.indices_villes WHERE id = v_cle;
  RETURN jsonb_build_object('ok', true, 'paiement', v_paie, 'ville', p_ville, 'sujet', v_sujet,
    'interdiction_recente', v_recente, 'baisse_social', v_delta, 'hausse_securite', v_delta,
    'touches', v_touches, 'indices', v_indices,
    'moi', (SELECT jsonb_build_object('hp', hp, 'vol', stats->'VOL') FROM public.personnages_donnees WHERE name = v_moi));
END $function$;

REVOKE ALL ON FUNCTION public.manifestation_interdire(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.manifestation_reprimer(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.manifestation_interdire(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.manifestation_reprimer(text, text) TO authenticated;

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.manifestation_interdire(text,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.manifestation_reprimer(text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'portes de manifestation ouvertes à anon';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'reprimer_manif' AND pa = 3 AND cost = 0) THEN
    RAISE EXCEPTION 'coût de reprimer_manif non déclaré';
  END IF;
END $$;
