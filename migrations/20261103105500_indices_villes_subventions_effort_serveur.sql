-- =============================================================================================
-- INDICES DE VILLE ÉCRITS PAR LE SERVEUR SEUL (Claude, 03/11/2026)
-- =============================================================================================
-- Suite de 20261103104907 (relevé du 03/11, point 4, table `indices_villes`). Derniers écrivains
-- de l'écran, portés au serveur, barème d'origine conservé :
--   . subvention du Ministre des Finances : Social +3 dans la ville où se trouve le ministre,
--     posé par les trois portes de versement (citoyen, entreprise, club/organisation) quand le
--     versement réussit (subvention_effet_social_interne) ;
--   . renouveler l'Effort de guerre (Président, 2 PA) : effort_guerre_renouveler() reprend le
--     verdict et le renouvellement de l'écran (actif, 2 périodes préventives au plus hors guerre,
--     échéance repoussée de 3 jours réels) et applique la pénalité d'origine hors guerre :
--     Social −2 dans chacune des villes du pays.
-- La piété n'est pas concernée : elle est imposée par le registre (déclencheur de indices_villes).
-- Puis INSERT/UPDATE de `indices_villes` sont fermés au rôle authenticated (lecture conservée) ;
-- la passe de minuit écrit avec la clé de service.
-- =============================================================================================

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('renouveler_effort_guerre', 2, 0)
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.subvention_effet_social_interne()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text; v_ville text;
BEGIN
  SELECT country, coalesce(current_city, 'capitale') INTO v_pays, v_ville
    FROM public.personnages_donnees WHERE name = public.mon_personnage();
  IF v_pays IS NOT NULL THEN PERFORM public.indice_ville_ajuster_interne(v_pays, v_ville, 'social', 3); END IF;
END $function$;
REVOKE ALL ON FUNCTION public.subvention_effet_social_interne() FROM PUBLIC, anon, authenticated;

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.subvention_citoyen_verser(text,integer)'::regprocedure);
  v_new := replace(v_def, $a$  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'beneficiaire', p_beneficiaire,$a$,
                          $n$  PERFORM public.subvention_effet_social_interne();
  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'beneficiaire', p_beneficiaire,$n$);
  IF v_new = v_def AND position('subvention_effet_social_interne' IN v_def) = 0 THEN
    RAISE EXCEPTION 'patch subvention_citoyen_verser non appliqué';
  END IF;
  IF v_new <> v_def THEN EXECUTE v_new; END IF;

  v_def := pg_get_functiondef('public.subvention_collective_verser(text,text,text,integer)'::regprocedure);
  v_new := replace(v_def, $a$  v_res := jsonb_build_object('ok', true, 'verse', v_verse, 'caisse', v_nouveau, 'beneficiaire', p_id);$a$,
                          $n$  PERFORM public.subvention_effet_social_interne();
  v_res := jsonb_build_object('ok', true, 'verse', v_verse, 'caisse', v_nouveau, 'beneficiaire', p_id);$n$);
  IF v_new = v_def AND position('subvention_effet_social_interne' IN v_def) = 0 THEN
    RAISE EXCEPTION 'patch subvention_collective_verser non appliqué';
  END IF;
  IF v_new <> v_def THEN EXECUTE v_new; END IF;

  v_def := pg_get_functiondef('public.subvention_entreprise_verser(text,integer,text)'::regprocedure);
  v_new := replace(v_def, $a$  RETURN jsonb_build_object('ok',true,'rejeu',false,'verse',v_verse,$a$,
                          $n$  PERFORM public.subvention_effet_social_interne();
  RETURN jsonb_build_object('ok',true,'rejeu',false,'verse',v_verse,$n$);
  IF v_new = v_def AND position('subvention_effet_social_interne' IN v_def) = 0 THEN
    RAISE EXCEPTION 'patch subvention_entreprise_verser non appliqué';
  END IF;
  IF v_new <> v_def THEN EXECUTE v_new; END IF;
END $mig$;

CREATE OR REPLACE FUNCTION public.effort_guerre_renouveler()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_data jsonb; v_effort jsonb; v_maint bigint; v_guerre boolean;
        v_prev integer; v_paie jsonb; v_nouveau jsonb; v_ville record; v_penalite boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('president', v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_president');
  END IF;
  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  v_effort := v_data->'effortGuerre';
  v_maint := (extract(epoch FROM now()) * 1000)::bigint;
  IF v_effort IS NULL OR jsonb_typeof(v_effort) <> 'object' OR NOT coalesce((v_effort->>'actif')::boolean, false)
     OR (jsonb_typeof(v_effort->'expireA') = 'number' AND (v_effort->>'expireA')::numeric <= v_maint) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_actif');
  END IF;
  v_guerre := EXISTS (SELECT 1 FROM public.guerres g WHERE g.statut IS DISTINCT FROM 'terminee'
                        AND (g.data->>'attaquant' = v_pays OR g.data->>'attaque' = v_pays));
  v_prev := greatest(0, floor(coalesce(CASE WHEN jsonb_typeof(v_effort->'periodesPreventives') = 'number'
                                             THEN (v_effort->>'periodesPreventives')::numeric END, 0))::integer);
  IF NOT v_guerre AND v_prev >= 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prolongation_preventive_epuisee', 'maximum', 2);
  END IF;

  v_paie := public.payer_ordre(v_moi, 'renouveler_effort_guerre', 2, 0);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;

  v_nouveau := v_effort || jsonb_build_object('actif', true, 'expireA', v_maint + 3 * 24 * 60 * 60 * 1000,
    'finA', NULL,
    'periodes', greatest(1, floor(coalesce(CASE WHEN jsonb_typeof(v_effort->'periodes') = 'number'
                                                 THEN (v_effort->>'periodes')::numeric END, 1))::integer) + 1,
    'periodesPreventives', CASE WHEN v_guerre THEN 0 ELSE v_prev + 1 END);
  UPDATE public.budgets_nationaux SET data = jsonb_set(coalesce(data, '{}'::jsonb), '{effortGuerre}', v_nouveau),
         updated_at = now() WHERE id = v_pays;

  v_penalite := NOT v_guerre;
  IF v_penalite THEN
    FOR v_ville IN SELECT substr(id, length(v_pays) + 2) AS ville
                     FROM public.indices_villes WHERE id LIKE v_pays || '\_%' LOOP
      PERFORM public.indice_ville_ajuster_interne(v_pays, v_ville.ville, 'social', -2);
    END LOOP;
  END IF;
  RETURN jsonb_build_object('ok', true, 'paiement', v_paie, 'effort', v_nouveau, 'penalite_is', v_penalite,
    'indices', (SELECT jsonb_object_agg(id, data) FROM public.indices_villes WHERE id LIKE v_pays || '\_%'));
END $function$;
REVOKE ALL ON FUNCTION public.effort_guerre_renouveler() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.effort_guerre_renouveler() TO authenticated;

-- Fermeture : plus aucune écriture de l'écran sur indices_villes.
REVOKE INSERT, UPDATE, DELETE ON public.indices_villes FROM authenticated, anon;
DROP POLICY IF EXISTS indices_villes_ecriture_acteur ON public.indices_villes;
DROP POLICY IF EXISTS indices_villes_maj_acteur ON public.indices_villes;

DO $$
BEGIN
  IF has_table_privilege('authenticated', 'public.indices_villes', 'INSERT')
     OR has_table_privilege('authenticated', 'public.indices_villes', 'UPDATE') THEN
    RAISE EXCEPTION 'indices_villes encore écrivable par l''écran';
  END IF;
  IF NOT has_table_privilege('authenticated', 'public.indices_villes', 'SELECT') THEN
    RAISE EXCEPTION 'lecture de indices_villes perdue';
  END IF;
  IF has_function_privilege('authenticated', 'public.subvention_effet_social_interne()', 'EXECUTE') THEN
    RAISE EXCEPTION 'moteur de subvention exécutable par l''écran';
  END IF;
  IF has_function_privilege('anon', 'public.effort_guerre_renouveler()', 'EXECUTE') THEN
    RAISE EXCEPTION 'effort_guerre_renouveler ouvert à anon';
  END IF;
END $$;
