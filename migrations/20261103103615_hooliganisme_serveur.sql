-- =============================================================================================
-- HOOLIGANISME DÉCIDÉ PAR LE SERVEUR (Claude, 03/11/2026)
-- =============================================================================================
-- Relevé du 03/11 (RELAIS.md, point 3) : la découverte différée des crimes avait deux moteurs.
-- Le serveur (minuit_decouverte_crimes) examine les traces « serveur » ; le navigateur tirait
-- lui-même (Math.random) la découverte des autres traces, puis arrêtait le joueur. Seul acte
-- découvrable dont la trace était encore posée par l'écran : « Organiser des échauffourées »
-- (orga_hooliganisme). Une trace écrite par l'écran est aussi effaçable par l'écran : le risque
-- pénal n'existait que si le joueur le voulait bien.
--
-- Une porte fait désormais tout : organisation_hooliganisme(p_orga)
--   . autorité : membre de l'organisation de supporters, au grade de Meneur (gradeIdx 3,
--     ORGA_ORDRE_RANG_MIN de l'écran) ;
--   . paiement : payer_ordre au tarif déclaré (3 PA) ;
--   . effet d'origine : −5 Sécurité et −5 Social, appliqués à la ville où se trouve le PJ
--     (indices_villes, moteur indice_ville_ajuster_interne). Écart technique assumé : l'écran
--     retirait 5 à INDICES_NATIONAUX, une copie locale jamais enregistrée ; l'ordre annonçait
--     déjà « Impact sur la sécurité locale » ;
--   . trace pénale posée par crime_tracer_interne (8 jours, origine serveur), donc soumise à la
--     découverte de minuit comme les autres actes.
-- L'écran ne tire plus aucune découverte (verifierDecouverteCrimesPasses supprimée).
-- =============================================================================================

CREATE OR REPLACE FUNCTION public.organisation_hooliganisme(p_orga text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_json jsonb; v_membre jsonb; v_cout record; v_paie jsonb;
        v_pays text; v_ville text; v_indices jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT data::jsonb INTO v_json FROM public.organisations WHERE id = p_orga;
  IF v_json IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'organisation_introuvable'); END IF;
  IF v_json->>'type' IS DISTINCT FROM 'supporters' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_hors_type');
  END IF;
  SELECT m INTO v_membre FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_json->'membres') = 'array'
                                                        THEN v_json->'membres' ELSE '[]'::jsonb END) m
   WHERE m->>'nom' = v_moi LIMIT 1;
  IF v_membre IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_membre'); END IF;
  IF coalesce(CASE WHEN jsonb_typeof(v_membre->'gradeIdx') = 'number' THEN (v_membre->>'gradeIdx')::integer END, 0) < 3 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'grade_insuffisant');
  END IF;

  SELECT pa, cost INTO v_cout FROM public.ordres_couts WHERE fn = 'orga_hooliganisme' ORDER BY pa, cost LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare'); END IF;
  v_paie := public.payer_ordre(v_moi, 'orga_hooliganisme', v_cout.pa, v_cout.cost);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;

  SELECT country, coalesce(current_city, 'capitale') INTO v_pays, v_ville
    FROM public.personnages_donnees WHERE name = v_moi;
  PERFORM public.indice_ville_ajuster_interne(v_pays, v_ville, 'isn', -5);
  PERFORM public.indice_ville_ajuster_interne(v_pays, v_ville, 'social', -5);
  PERFORM public.crime_tracer_interne(v_moi, 'hooliganisme', NULL);

  SELECT data INTO v_indices FROM public.indices_villes WHERE id = v_pays || '_' || v_ville;
  RETURN jsonb_build_object('ok', true, 'paiement', v_paie, 'pays', v_pays, 'ville', v_ville,
                            'indices', v_indices);
END $function$;

REVOKE ALL ON FUNCTION public.organisation_hooliganisme(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.organisation_hooliganisme(text) TO authenticated;

-- Preuve structurelle : porte fermée à anon, ouverte à authenticated, trace par le moteur serveur.
DO $$
BEGIN
  IF has_function_privilege('anon', 'public.organisation_hooliganisme(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'organisation_hooliganisme ne doit pas être exécutable par anon';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.organisation_hooliganisme(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'organisation_hooliganisme doit être exécutable par authenticated';
  END IF;
  IF pg_get_functiondef('public.organisation_hooliganisme(text)'::regprocedure) NOT LIKE '%crime_tracer_interne%' THEN
    RAISE EXCEPTION 'organisation_hooliganisme doit tracer par crime_tracer_interne';
  END IF;
END $$;
