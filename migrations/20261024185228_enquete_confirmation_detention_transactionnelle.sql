-- Précondition de l'acte L09 : verrou et confirmation, mêmes moteurs judiciaires.
-- Comparer le corps vivant avant installation : cette fonction n'était pas dans le prévol à 22 corps.
BEGIN;
DO $g$ DECLARE h text;BEGIN
 SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.plainte_instruire_interne(text,text,text,text,text)');
 IF h IS NULL OR h NOT IN('af584b77132d34dc7049a6289ef04b1a','0a7539ce5fb8cbbe8fdeda96021d6df9') THEN RAISE EXCEPTION 'definition_non_examinee: plainte_instruire_interne';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.plainte_instruire_interne(p_pays text, p_ville text, p_cible text, p_motif text, p_instructeur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acte   public.actions_tracables%ROWTYPE;
  v_jour   integer;
  v_det    jsonb;
  v_motifs jsonb;
  v_ce     jsonb;
BEGIN
  SELECT * INTO v_acte FROM public.actions_tracables a
   WHERE a.country = p_pays AND a.city = p_ville AND a.auteur = p_cible
     AND a.decouvert IS NOT TRUE
   ORDER BY a.jour DESC
   LIMIT 1 FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'decision', 'classee',
                              'motif_decision', 'aucun_element_a_charge');
  END IF;

  UPDATE public.actions_tracables SET decouvert = true WHERE id = v_acte.id;

  -- BRANCHE CONTRE-ESPIONNAGE. L'auteur de la trace est-il la couverture d'un
  -- agent reel ? Si oui, l'instruction produit un DEMASQUAGE, pas une garde a
  -- vue : detention_ouvrir_interne refuserait de toute facon (pas de fiche).
  v_ce := public.contre_espionnage_resoudre(p_pays, p_cible, p_instructeur,
            'actions_tracables:' || v_acte.id);
  IF coalesce((v_ce ->> 'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', true, 'decision', 'contre_espionnage',
      'acte', coalesce(v_acte.type_action, 'acte illegal'),
      'couverture', p_cible, 'enquete', v_ce);
  END IF;

  -- ---- A partir d'ici, comportement historique STRICTEMENT inchange ----
  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = p_cible;
  v_motifs := jsonb_build_array(jsonb_build_object(
    'type', coalesce(v_acte.type_action, 'Acte illegal decouvert par enquete'),
    'cible', v_acte.cible,
    'jour_fait', v_acte.jour,
    'city', p_ville,
    'ref_type', 'action_tracee',
    'ref_id', v_acte.id,
    'jours', 2,
    'source', 'garde_a_vue',
    'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

  v_det := public.detention_ouvrir_interne(
    p_cible, coalesce(v_acte.type_action, 'Acte illegal decouvert par enquete'), 2,
    p_ville, p_pays, v_motifs, p_instructeur, 'garde_a_vue_enquete');

  -- Une décision annoncée ne remplace pas la confirmation de ses écritures.
  IF v_det->>'ok' IS DISTINCT FROM 'true' OR nullif(v_det->>'detention_id','') IS NULL
     OR NOT EXISTS(SELECT 1 FROM public.detentions d WHERE d.id=v_det->>'detention_id' AND d.nom=p_cible AND d.date_fin_effective IS NULL)
     OR (EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.name=p_cible) AND NOT EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.name=p_cible AND d.est_emprisonne->>'detentionId'=v_det->>'detention_id')) THEN
    RAISE EXCEPTION 'instruction_detention_non_confirmee';
  END IF;

  RETURN jsonb_build_object('ok', true, 'decision', 'enquete_ouverte',
                            'acte', coalesce(v_acte.type_action, 'acte illegal'),
                            'detention', v_det);
END;
$function$;
COMMIT;
