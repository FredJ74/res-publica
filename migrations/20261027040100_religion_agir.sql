-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027101940.
-- Eprouvee avant application en transaction annulee (refus hors eglise et au mauvais prix, grade, conquete stricte de la charge et du Grand Pretre, piete forcee remise au registre, excommunie sans piete). Baseline NON reextrait.
-- ============================================================================
-- LA CARRIERE RELIGIEUSE DE REPUBLIA PAR LE SERVEUR, 2e partie (27 octobre 2026)
-- ============================================================================
-- religion_agir(fn, pa, cost) : prier ou donner dans une eglise de Republia. Voir l'en-tete de
-- 20261027040000_religion_par_le_serveur.sql. Fermeture des ecritures des joueurs sur
-- contributions_piete et titulaires_pnj. Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.religion_agir(p_fn text, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; v_eglise text; v_paie jsonb; v_excom boolean; v_qte integer := 0;
  v_moral integer; v_res jsonb; v_total numeric; v_grade_avant text; v_grade_apres text;
  v_score numeric; v_tit text; v_score_tit numeric; v_gp text; v_score_gp numeric; v_v text;
  v_nom_ville text; v_charge boolean := false; v_gp_conquis boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_fn NOT IN ('prier', 'faire_don') THEN RETURN jsonb_build_object('ok', false, 'raison', 'ordre_indisponible'); END IF;
  SELECT country, current_city, current_building, excommunie INTO d FROM public.personnages_donnees WHERE name = v_moi;
  IF d.country IS DISTINCT FROM 'republic' THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_republia'); END IF;
  v_eglise := CASE d.current_city WHEN 'capitale' THEN 'tabernacle-impots' WHEN 'ville_a' THEN 'notre-dame-mer'
                                  WHEN 'ville_b' THEN 'eglise-montrouge' END;
  IF v_eglise IS NULL OR d.current_building IS DISTINCT FROM v_eglise THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_nom_ville := CASE d.current_city WHEN 'capitale' THEN 'Luthécia' WHEN 'ville_a' THEN 'Port-Sainte-Marie' ELSE 'Montrouge' END;
  v_excom := d.excommunie IS NOT NULL AND jsonb_typeof(d.excommunie) <> 'null' AND d.excommunie <> 'false'::jsonb;

  IF p_fn = 'prier' THEN
    v_paie := public.payer_ordre(v_moi, p_fn, p_pa, p_cost);
  ELSE
    v_paie := public.vente_structure_encaisser(p_fn, p_pa, p_cost, 'republic_' || v_eglise, d.current_city);
  END IF;
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  SELECT coalesce(moral, 75), CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END
    INTO v_moral, v_res FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF p_fn = 'prier' THEN
    v_moral := least(100, v_moral + 2);
    v_qte := CASE WHEN v_excom THEN 0 ELSE 3 END;
  ELSE
    v_res := jsonb_set(v_res, '{pop}', to_jsonb(least(100, coalesce(CASE WHEN jsonb_typeof(v_res -> 'pop') = 'number'
                                                                        THEN (v_res ->> 'pop')::numeric END, 50) + 3)));
    v_qte := 5;
  END IF;
  UPDATE public.personnages_donnees SET moral = v_moral, resources = v_res WHERE name = v_moi;

  IF v_qte > 0 THEN
    SELECT coalesce(sum(quantite), 0) INTO v_total FROM public.contributions_piete WHERE pays = 'republic' AND auteur = v_moi;
    v_grade_avant := public.religion_grade_interne(v_total);
    INSERT INTO public.contributions_piete (pays, ville, auteur, quantite, created_at)
      VALUES ('republic', d.current_city, v_moi, v_qte, now());
    v_grade_apres := public.religion_grade_interne(v_total + v_qte);
    UPDATE public.indices_villes SET updated_at = now() WHERE id = 'republic_' || d.current_city;
    IF NOT FOUND THEN PERFORM public.piete_villes_actualiser(); END IF;

    -- Conquete : seul un pretre, et seulement par son propre acte.
    IF v_grade_apres = 'pretre' THEN
      v_score := public.piete_score_actif_interne(v_moi, d.current_city);
      v_tit := public.religion_titulaire_interne('pretre', d.current_city);
      IF v_tit IS DISTINCT FROM v_moi THEN
        v_score_tit := CASE WHEN EXISTS (SELECT 1 FROM public.personnages_donnees WHERE country = 'republic' AND name = v_tit)
                            THEN public.piete_score_actif_interne(v_tit, d.current_city)
                            ELSE CASE WHEN d.current_city = 'capitale' THEN 50 ELSE 40 END END;
        IF v_score > v_score_tit THEN
          PERFORM public.religion_titulaire_poser_interne('pretre', d.current_city, v_moi);
          PERFORM public.annonce_publique_interne('republic', '⛪ ' || v_moi || ' devient Prêtre titulaire de ' || v_nom_ville || '.');
          v_charge := true; v_tit := v_moi;
        END IF;
      END IF;
      IF v_tit = v_moi THEN
        v_gp := public.religion_titulaire_interne('grand_pretre', NULL);
        IF v_gp IS DISTINCT FROM v_moi THEN
          IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE country = 'republic' AND name = v_gp) THEN
            v_score_gp := NULL;
            FOREACH v_v IN ARRAY ARRAY['capitale', 'ville_a', 'ville_b'] LOOP
              IF v_score_gp IS NULL AND public.religion_titulaire_interne('pretre', v_v) = v_gp THEN
                v_score_gp := public.piete_score_actif_interne(v_gp, v_v);
              END IF;
            END LOOP;
          ELSE
            v_score_gp := 50;
          END IF;
          IF v_score_gp IS NULL OR v_score > v_score_gp THEN
            PERFORM public.religion_titulaire_poser_interne('grand_pretre', NULL, v_moi);
            PERFORM public.annonce_publique_interne('republic', '⛪ ' || v_moi || ' devient le nouveau Grand Prêtre national de Républia.');
            v_gp_conquis := true;
          END IF;
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'fn', p_fn, 'piete_ajoutee', v_qte, 'excommunie', v_excom,
    'moral', v_moral, 'pop', v_res -> 'pop',
    'grade_avant', v_grade_avant, 'grade', v_grade_apres,
    'charge_conquise', v_charge, 'grand_pretre_conquis', v_gp_conquis, 'ville', d.current_city, 'nom_ville', v_nom_ville,
    'piete_ville', public.piete_ville_calculee_interne(d.current_city),
    'pa', v_paie -> 'pa', 'liquide', v_paie -> 'liquide', 'arg', v_paie -> 'arg', 'solde_national', v_paie -> 'solde_national');
END; $function$;

REVOKE ALL ON FUNCTION public.religion_agir(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.religion_agir(text, integer, integer) TO authenticated;

-- Les joueurs n'ecrivent plus le registre de piete ni les titulaires.
DROP POLICY IF EXISTS contributions_piete_ecriture_acteur ON public.contributions_piete;
REVOKE INSERT, UPDATE, DELETE ON public.contributions_piete FROM anon, authenticated;
DROP POLICY IF EXISTS titulaires_pnj_ecriture_non_politique ON public.titulaires_pnj;
DROP POLICY IF EXISTS titulaires_pnj_maj_non_politique ON public.titulaires_pnj;
DROP POLICY IF EXISTS titulaires_pnj_suppression_non_politique ON public.titulaires_pnj;
REVOKE INSERT, UPDATE, DELETE ON public.titulaires_pnj FROM anon, authenticated;

-- Remet la piete des trois villes d'accord avec le registre.
UPDATE public.indices_villes SET updated_at = now() WHERE id IN ('republic_capitale', 'republic_ville_a', 'republic_ville_b');
