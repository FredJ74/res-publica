-- ANCIENS ACTES D'ACCÉLÉRATION NEUTRALISÉS EN ATTENDANT LA LIVRAISON (29/10/2026, Claude).
-- `achat_direct_accelerer` (rendez-vous chez le notaire) et `permis_accelerer` (corruption du
-- fonctionnaire) restent appelés par l'écran en ligne, qui paie d'abord par `payer_ordre` : les
-- fermer maintenant ferait perdre 800 FR au joueur. On les RACCORDE donc à la règle serveur :
-- l'écran n'apporte plus aucune date ni aucun dossier ; le serveur divise par deux le délai
-- ENREGISTRÉ (rendez-vous ou instruction), une seule fois par dossier, et refuse un rendez-vous
-- d'un autre joueur ou un dossier d'un autre demandeur. Plus de permis « valide » posé par
-- l'écran, plus de date arbitraire. Les nouvelles portes (terrain_rdv_notaire_accelerer,
-- terrain_permis_corrompre) sont inchangées. Fermeture définitive après livraison : 20261029160000.
DO $mig$
DECLARE v_def text; v_new text; v_frag text :=
$a$    v_patch := jsonb_set(v_patch, '{achatDirect,demandeur}', to_jsonb(v_moi));
  END IF;$a$;
BEGIN
  v_def := pg_get_functiondef('public.terrain_compromis_acte(text,text,jsonb)'::regprocedure);
  IF strpos(v_def, 'accelereAncienCircuit') > 0 THEN RETURN; END IF;
  IF (length(v_def) - length(replace(v_def, v_frag, ''))) / length(v_frag) <> 1 THEN RAISE EXCEPTION 'fragment notaire non unique'; END IF;
  v_new := replace(v_def, v_frag, $n$    DECLARE ms numeric := floor(extract(epoch FROM clock_timestamp())*1000); reste numeric; nd numeric;
    BEGIN
      IF (v_etat->'achatDirect'->>'accelereAncienCircuit') IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'deja_accelere'); END IF;
      reste := (v_etat->'achatDirect'->>'dateAchat')::numeric - ms;
      IF reste IS NULL OR reste <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'rendez_vous_deja_arrive'); END IF;
      nd := ms + floor(reste / 2);
      v_patch := jsonb_build_object('achatDirect', (v_etat->'achatDirect') || jsonb_build_object(
        'dateAchat', nd, 'dateLimite', nd + 86400000, 'accelereAncienCircuit', true));
    END;
  END IF;$n$);
  EXECUTE v_new;
END $mig$;

DO $mig$
DECLARE v_def text; v_new text; v_frag text :=
$a$      RETURN jsonb_build_object('ok', false, 'raison', 'aucune_instruction');
    END IF;

  ELSIF p_acte = 'permis_plan_modifier' THEN$a$;
BEGIN
  v_def := pg_get_functiondef('public.terrain_permis_acte(text,text,jsonb)'::regprocedure);
  IF strpos(v_def, 'accelereAncienCircuit') > 0 THEN RETURN; END IF;
  IF (length(v_def) - length(replace(v_def, v_frag, ''))) / length(v_frag) <> 1 THEN RAISE EXCEPTION 'fragment permis non unique'; END IF;
  v_new := replace(v_def, v_frag, $n$      RETURN jsonb_build_object('ok', false, 'raison', 'aucune_instruction');
    END IF;
    IF (v_permis->>'demandeur') IS DISTINCT FROM public.mon_personnage() THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_dossier'); END IF;
    IF (v_permis->>'accelereAncienCircuit') IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'deja_accelere'); END IF;
    v_patch := jsonb_build_object('permis', v_permis || jsonb_build_object(
      'dureeInstruction', greatest(1, floor(coalesce((v_permis->>'dureeInstruction')::numeric, 1) / 2)),
      'dateInstructionTerminee', coalesce((v_permis->>'dateDepot')::integer, 0)
                                 + greatest(1, floor(coalesce((v_permis->>'dureeInstruction')::numeric, 1) / 2)),
      'accelereAncienCircuit', true));

  ELSIF p_acte = 'permis_plan_modifier' THEN$n$);
  EXECUTE v_new;
END $mig$;
