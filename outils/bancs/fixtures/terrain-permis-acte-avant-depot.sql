-- Version avant migration de depot, archivee depuis main d978a76.
-- Un banc de migration doit partir de cet etat, et non du baseline vivant apres migration.
CREATE OR REPLACE FUNCTION public.terrain_permis_acte(p_terrain_id text, p_acte text, p_patch jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_poste text; v_poste_ville text;
  v_lu jsonb; v_etat jsonb; v_patch jsonb; v_final jsonb; v_permis jsonb;
  v_ville text; v_ville_inconnue boolean := false; v_cles text[]; v_k text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_acte NOT IN ('permis_deposer', 'permis_prevenir_maire', 'permis_decider',
                    'permis_accelerer', 'permis_plan_modifier') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu');
  END IF;
  v_patch := coalesce(p_patch, '{}'::jsonb);
  IF jsonb_typeof(v_patch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'patch_invalide');
  END IF;

  -- LISTE DE CLES PAR ACTE. Seule la decision touche `constructionAutorisee` ; aucun acte de ce
  -- mecanisme ne touche `chantier`, `subdivisions`, `proprietaire` ni le compromis.
  v_cles := CASE WHEN p_acte = 'permis_decider' THEN ARRAY['permis', 'constructionAutorisee']
                 ELSE ARRAY['permis'] END;
  FOR v_k IN SELECT jsonb_object_keys(v_patch) LOOP
    IF NOT (v_k = ANY (v_cles)) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cle_hors_acte', 'cle', v_k);
    END IF;
  END LOOP;

  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_moi, v_poste, v_poste_ville, v_pays FROM public.acteur_poste_courant() a;

  v_lu := public.terrain_etat_verrouiller_interne(p_terrain_id);
  v_etat := v_lu -> 'etat';
  IF (v_lu ->> 'gele')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;
  v_permis := v_etat -> 'permis';
  v_ville := nullif(btrim(coalesce(v_etat ->> 'city', '')), '');
  v_ville_inconnue := (v_ville IS NULL);

  IF p_acte = 'permis_deposer' THEN
    IF NOT public.titulaire_est_moi(v_etat ->> 'proprietaire') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
    END IF;
    IF jsonb_typeof(v_patch -> 'permis') <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'permis_absent');
    END IF;
    -- LE DEMANDEUR N'EST PLUS DICTE PAR LE NAVIGATEUR.
    v_patch := jsonb_set(v_patch, '{permis,demandeur}', to_jsonb(v_moi));

  ELSIF p_acte = 'permis_prevenir_maire' THEN
    -- ACTE PASSIF : il se declenche a l'entree dans la piece, pour N'IMPORTE QUEL joueur. Il n'a
    -- donc aucune autorite a verifier -- mais il ne doit poser QUE ce drapeau, et la porte le pose
    -- elle-meme plutot que de recopier un patch. Les trois conditions sont celles du client :
    --   if (!instructionAchevee(ts.permis) || ts.permis.mairePrevenu) return;
    IF v_permis IS NULL OR (v_permis ->> 'statut') IS DISTINCT FROM 'instruction'
       OR coalesce((v_permis ->> 'dureeInstruction')::numeric, 0) <= 0
       OR coalesce((v_permis ->> 'joursInstructionFaits')::numeric, 0)
          < coalesce((v_permis ->> 'dureeInstruction')::numeric, 0)
       OR coalesce((v_permis ->> 'mairePrevenu')::boolean, false) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_signaler');
    END IF;
    v_patch := jsonb_build_object('permis', v_permis || '{"mairePrevenu": true}'::jsonb);

  ELSIF p_acte = 'permis_decider' THEN
    IF v_poste IS DISTINCT FROM 'maire_adjoint' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee');
    END IF;
    IF NOT v_ville_inconnue AND v_poste_ville IS DISTINCT FROM v_ville THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction',
                                'ville_terrain', v_ville, 'ville_poste', v_poste_ville);
    END IF;
    -- LA MEME REGLE QUE `verdictDecisionPermis` : un dossier deja tranche ne se retranche pas.
    IF v_permis IS NULL OR (v_permis ->> 'statut') IS DISTINCT FROM 'instruction' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'dossier_deja_decide',
                                'statut', v_permis ->> 'statut');
    END IF;
    IF (v_patch -> 'permis' ->> 'statut') NOT IN ('valide', 'refuse') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide');
    END IF;
    IF (v_patch -> 'permis' ->> 'statut') = 'refuse'
       AND length(btrim(coalesce(v_patch -> 'permis' ->> 'motifRefus', ''))) < 10 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'motif_requis');
    END IF;

  ELSIF p_acte = 'permis_accelerer' THEN
    -- REGLE RECOPIEE DU CLIENT : if (!ts.permis || ts.permis.statut !== 'instruction')
    IF v_permis IS NULL OR (v_permis ->> 'statut') IS DISTINCT FROM 'instruction' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'aucune_instruction');
    END IF;

  ELSIF p_acte = 'permis_plan_modifier' THEN
    -- PREMIERE REGLE DE `verdictOuvertureModificationPlan`, et la seule qui soit une AUTORITE :
    --   if (!estTitulaire(ts && ts.proprietaire)) return { ok:false, ... }
    -- Les autres (chantier present, deux tiers non franchis, palier divisible, surface connue)
    -- restent au verdict unique du client : les porter ici en ferait une SECONDE version.
    IF NOT public.titulaire_est_moi(v_etat ->> 'proprietaire') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
    END IF;
    IF v_permis IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'aucun_permis');
    END IF;
  END IF;

  v_final := public.terrain_etat_fusionner_interne(p_terrain_id, v_patch, v_pays);
  RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'etat', v_final,
                            'ville_inconnue', v_ville_inconnue);
END; $function$;
