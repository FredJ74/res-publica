-- Definition avant commandes versionnees, archivee depuis main d978a76.
-- Les gardes des migrations restent strictes ; seul leur point de depart est fige.
CREATE OR REPLACE FUNCTION public.terrain_chantier_acte(p_terrain_id text, p_acte text, p_matiere text DEFAULT NULL::text, p_quantite integer DEFAULT NULL::integer, p_jour integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_lu jsonb; v_etat jsonb; v_ch jsonb; v_final jsonb;
  v_d double precision; v_total double precision; v_verse double precision; v_prog double precision;
  v_s1 double precision; v_s2 double precision; v_s3 double precision;
  v_requis double precision; v_plafond double precision; v_gain double precision; v_neuf double precision;
  v_stock jsonb; v_dispo integer; v_qte integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_acte NOT IN ('chantier_accelerer', 'chantier_materiaux_voler') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu');
  END IF;
  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi LIMIT 1;

  v_lu := public.terrain_etat_verrouiller_interne(p_terrain_id);
  v_etat := v_lu -> 'etat';
  IF (v_lu ->> 'gele')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;
  v_ch := v_etat -> 'chantier';
  IF v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;

  IF p_acte = 'chantier_accelerer' THEN
    SELECT valeur::double precision INTO v_s1 FROM public.entreprises_constantes WHERE cle = 'seuil_demarrage_pct';
    SELECT valeur::double precision INTO v_s2 FROM public.entreprises_constantes WHERE cle = 'seuil_premier_tiers_pct';
    SELECT valeur::double precision INTO v_s3 FROM public.entreprises_constantes WHERE cle = 'seuil_deux_tiers_pct';
    IF v_s1 IS NULL OR v_s2 IS NULL OR v_s3 IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'seuils_indisponibles');
    END IF;
    v_d     := greatest(0, coalesce((v_ch ->> 'dureeJours')::double precision, 0));
    v_total := greatest(0, coalesce((v_ch ->> 'coutTotal')::double precision, 0));
    v_verse := greatest(0, coalesce((v_ch ->> 'totalVerse')::double precision, 0));
    v_prog  := greatest(0, coalesce((v_ch ->> 'progressionJours')::double precision, 0));

    -- peutProgresser : montantManquant(...) <= 0, avec seuilFinancementRequis par palier de tiers.
    v_requis := ceil(v_total * (CASE WHEN v_d <= 0 THEN v_s3
                                     WHEN v_prog < v_d * 1 / 3 THEN v_s1
                                     WHEN v_prog < v_d * 2 / 3 THEN v_s2
                                     ELSE v_s3 END) / 100);
    IF greatest(0, v_requis - v_verse) > 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'financement_insuffisant',
                                'manquant', greatest(0, v_requis - v_verse));
    END IF;
    IF greatest(0, v_d - v_prog) <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'chantier_a_son_terme');
    END IF;

    -- progressionMaxFinancee, puis progressionAutorisee avec un gain de la MOITIE du travail
    -- restant -- la regle exacte de `doCorrompreChantier`, inchangee.
    v_plafond := CASE WHEN v_d <= 0 THEN 0
                      WHEN v_total <= 0 THEN v_d
                      WHEN v_verse * 100 >= v_s3 * v_total THEN v_d
                      WHEN v_verse * 100 >= v_s2 * v_total THEN v_d * 2 / 3
                      WHEN v_verse * 100 >= v_s1 * v_total THEN v_d * 1 / 3
                      ELSE 0 END;
    v_gain := greatest(0, least(v_prog + greatest(0, (v_d - v_prog) / 2), v_plafond) - v_prog);
    IF v_gain <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'progression_plafonnee', 'plafond', v_plafond);
    END IF;
    v_neuf := least(v_d, v_prog + v_gain);
    v_ch := v_ch || jsonb_build_object('progressionJours', v_neuf);
    -- appliquerVerrouPlan : le plan se fige aux deux tiers, et une seule fois.
    IF coalesce((v_ch ->> 'planVerrouille')::boolean, false) IS NOT TRUE
       AND v_d > 0 AND v_neuf >= v_d * 2 / 3 THEN
      v_ch := v_ch || jsonb_build_object('planVerrouille', true, 'jourVerrouPlan', p_jour);
    END IF;
    v_final := public.terrain_etat_fusionner_interne(p_terrain_id,
                 jsonb_build_object('chantier', v_ch), v_pays);
    RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'etat', v_final, 'chantier', v_ch,
      'progression', v_neuf, 'reste', greatest(0, v_d - v_neuf), 'gain', v_gain);
  END IF;

  -- VOL DE MATERIAUX
  IF p_matiere NOT IN ('bois', 'minerai', 'metal') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_inconnue');
  END IF;
  IF coalesce(p_quantite, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  v_stock := coalesce(v_ch -> 'stockMateriaux', '{}'::jsonb);
  v_dispo := greatest(0, coalesce((v_stock ->> p_matiere)::numeric, 0))::integer;
  IF v_dispo <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_vide', 'matiere', p_matiere);
  END IF;
  -- LE PLAFOND EST LE STOCK REEL, PAS CELUI QUE LE CLIENT AVAIT LU.
  v_qte := least(p_quantite, v_dispo);
  v_ch := v_ch
    || jsonb_build_object('stockMateriaux', v_stock || jsonb_build_object(p_matiere, v_dispo - v_qte))
    || jsonb_build_object('evenements', coalesce(v_ch -> 'evenements', '[]'::jsonb)
         || jsonb_build_array(jsonb_build_object('cle', 'vol_materiaux', 'jour', p_jour,
              'matiere', p_matiere, 'quantite', v_qte)));
  v_final := public.terrain_etat_fusionner_interne(p_terrain_id,
               jsonb_build_object('chantier', v_ch), v_pays);
  RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'etat', v_final, 'chantier', v_ch,
    'matiere', p_matiere, 'quantite', v_qte, 'stock_restant', v_dispo - v_qte);
END; $function$;
