-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261025204410.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025204410.
-- Eprouvee avant application en transaction annulee. Baseline NON reextrait.
-- ============================================================================
-- BUREAU NATIONAL DE L'EMPLOI : LES HEURES DE CHANTIER ANNONCEES PAR LE SERVEUR (B8, 25/10/2026)
-- ============================================================================
-- Le Bureau annonce les heures de travail des chantiers de la ville (decision du 6 septembre
-- 2026). Elles etaient recalculees par l'ecran avec ses propres formules : deux realites
-- possibles. bne_heures_chantiers les calcule avec EXACTEMENT les bornes de chantier_travailler
-- (heures utiles du jour, fraction de materiaux, plafond de versement, tresorerie au taux du
-- chantier), sans les PA de l'ouvrier, qui ne regardent que lui. Lecture seule.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.bne_heures_chantiers()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_ville text; t record; v_data jsonb; v_ch jsonb; v_besoin record;
  v_jour_num integer; v_fraction numeric; v_capacite numeric; v_plafond numeric; v_utiles numeric;
  v_restantes numeric; v_taux numeric; v_min numeric; v_taux_paye numeric; v_payables numeric;
  v_stock jsonb; v_m text; v_req numeric; v_dispo numeric; v_res jsonb := '[]'::jsonb; v_heures numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic'), coalesce(current_city, 'capitale') INTO v_pays, v_ville
    FROM public.personnages_donnees WHERE name = v_moi;
  SELECT valeur INTO v_taux FROM public.entreprises_constantes WHERE cle = 'chantier_taux_horaire';
  SELECT valeur INTO v_min FROM public.entreprises_constantes WHERE cle = 'chantier_salaire_minimum';
  IF coalesce(v_taux, 0) <= 0 THEN RETURN jsonb_build_object('ok', true, 'chantiers', '[]'::jsonb); END IF;

  FOR t IN SELECT id, building_id, data FROM public.terrains_etat WHERE country = v_pays LOOP
    v_data := public.terrain_etat_lire(t.data);
    CONTINUE WHEN v_data IS NULL OR coalesce(v_data ->> 'city', 'capitale') <> v_ville
              OR coalesce(v_data ->> 'succession_gel', '') <> '';
    v_ch := CASE WHEN jsonb_typeof(v_data -> 'chantier') = 'object' THEN v_data -> 'chantier'
                 ELSE v_data -> 'chantierReamenagement' END;
    CONTINUE WHEN v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object'
              OR coalesce(v_ch ->> 'type', '') NOT IN ('construction', 'reamenagement')
              OR v_ch ->> 'arrete' = 'financement';
    v_jour_num := floor(GREATEST(0, COALESCE((v_ch ->> 'progressionJours')::numeric, 0)))::integer + 1;
    SELECT (x ->> 'bois')::numeric AS bois, (x ->> 'minerai')::numeric AS minerai, (x ->> 'metal')::numeric AS metal
      INTO v_besoin FROM (SELECT public.chantier_besoin_jour_interne(v_ch, v_jour_num) AS x) b;
    CONTINUE WHEN NOT FOUND;
    v_fraction := 1;
    v_stock := COALESCE(v_ch -> 'stockMateriaux', '{}'::jsonb);
    FOR v_m, v_req IN SELECT * FROM (VALUES ('bois', v_besoin.bois), ('minerai', v_besoin.minerai),
                                            ('metal', v_besoin.metal)) AS z(m, r) LOOP
      IF v_req > 0 THEN
        v_dispo := GREATEST(0, COALESCE((v_stock ->> v_m)::numeric, 0));
        v_fraction := LEAST(v_fraction, LEAST(1, GREATEST(0, v_dispo / v_req)));
      END IF;
    END LOOP;
    v_capacite := CASE WHEN COALESCE((v_ch ->> 'dureeJours')::numeric, 0) > 0
                       THEN (COALESCE((v_ch ->> 'coutTravail')::numeric, 0) / v_taux) / (v_ch ->> 'dureeJours')::numeric
                       ELSE 0 END;
    v_plafond := CASE WHEN (v_ch ->> 'totalVerse')::numeric >= (v_ch ->> 'coutTotal')::numeric THEN (v_ch ->> 'dureeJours')::numeric
                      WHEN (v_ch ->> 'totalVerse')::numeric >= ceil((v_ch ->> 'coutTotal')::numeric * .7) THEN (v_ch ->> 'dureeJours')::numeric * 2 / 3
                      WHEN (v_ch ->> 'totalVerse')::numeric >= ceil((v_ch ->> 'coutTotal')::numeric * .35) THEN (v_ch ->> 'dureeJours')::numeric / 3
                      ELSE 0 END;
    v_utiles := floor(v_capacite * least(v_fraction, greatest(0, v_plafond - coalesce((v_ch ->> 'progressionJours')::numeric, 0))));
    v_restantes := GREATEST(0, v_utiles - GREATEST(0, COALESCE((v_ch ->> 'heuresFaites')::numeric, 0)));
    v_taux_paye := GREATEST(COALESCE((v_ch ->> 'tauxHoraire')::numeric, v_taux), COALESCE(v_min, 50));
    v_payables := floor(GREATEST(0, COALESCE((v_ch ->> 'tresorerie')::numeric, 0)) / v_taux_paye);
    v_heures := LEAST(v_restantes, v_payables);
    CONTINUE WHEN v_heures <= 0;
    v_res := v_res || jsonb_build_array(jsonb_build_object(
      'terrain', t.building_id, 'type', v_ch ->> 'type', 'niveau', v_ch ->> 'niveau',
      'taux', v_taux_paye, 'heures', v_heures));
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'ville', v_ville, 'chantiers', v_res);
END; $function$;
REVOKE ALL ON FUNCTION public.bne_heures_chantiers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bne_heures_chantiers() TO authenticated;
