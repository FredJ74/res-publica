-- INCORPORATION : LE MOTIF « DESERTION » EST RETIRE PAR LE SERVEUR (04/11/2026, Claude, suite de 20261104022000).
--
-- L'écran retirait l'avis de recherche pour désertion (retirerRecherche) AVANT d'appeler la porte
-- d'incorporation, quand le PJ était encore détenu (recherche_retirer ne l'admet que pour un détenu
-- ou mobilisation levée). Depuis que la porte décide seule, le retrait se fait dans sa transaction :
-- incorporation immédiate comme différée, même filtre (acte « desertion » de ce pays seulement).

DO $prevol$
BEGIN
  IF position('deserteurs_regles_mobilisation_v1' IN pg_get_functiondef('public.detention_clore_motif_eteint(text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'incorporation : 20261104022000 absente'; END IF;
END $prevol$;

CREATE OR REPLACE FUNCTION public.recherche_retirer_desertion_interne(p_nom text, p_pays text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_avant jsonb; v_apres jsonb;
BEGIN
  SELECT recherche INTO v_avant FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF jsonb_typeof(v_avant) IS DISTINCT FROM 'array' THEN RETURN; END IF;
  SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_apres FROM jsonb_array_elements(v_avant) e
   WHERE NOT (e->>'acte' = 'desertion' AND coalesce(nullif(e->>'country', ''), p_pays) = p_pays);
  IF v_apres IS DISTINCT FROM v_avant THEN
    PERFORM set_config('rp.recherche_interne', 'on', true);
    UPDATE public.personnages_donnees SET recherche = v_apres WHERE name = p_nom;
    PERFORM set_config('rp.recherche_interne', '', true);
  END IF;
END;
$function$;
REVOKE ALL ON FUNCTION public.recherche_retirer_desertion_interne(text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.detention_clore_motif_eteint(p_mode text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_peine jsonb; v_r jsonb; v_pays text; v_req jsonb; v_mobil boolean;
BEGIN
  -- LISTE FERMEE : la porte ne sert que ces deux actes administratifs.
  IF p_mode NOT IN ('poursuites_eteintes','incorporation') THEN
    RAISE EXCEPTION 'detention_clore_motif_eteint : mode inconnu « % »', p_mode;
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT est_emprisonne, coalesce(country, 'republic'), requisition INTO v_peine, v_pays, v_req
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  -- deserteurs_regles_mobilisation_v1
  v_mobil := coalesce((SELECT (b.data->>'mobilisationNationaleActive')::boolean
                         FROM public.budgets_nationaux b WHERE b.id = v_pays), false);
  IF p_mode = 'poursuites_eteintes' AND v_mobil THEN
    RETURN jsonb_build_object('ok',false,'raison','mobilisation_en_cours'); END IF;
  IF p_mode = 'incorporation' THEN
    IF NOT v_mobil THEN RETURN jsonb_build_object('ok',false,'raison','mobilisation_levee'); END IF;
    IF coalesce(v_req->>'statut', '') NOT IN ('deserteur', 'incorpore') THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_deserteur'); END IF;
  END IF;
  -- deserteur_seul_par_motifs_v1 : la détention ne tient qu'à la désertion si tous ses motifs en relèvent.
  IF NOT public.detention_desertion_seule_interne(v_moi) THEN
    IF p_mode = 'incorporation' THEN
      -- incorporation_differee_v1 : actée maintenant, effective à la libération (detention_clore_interne).
      UPDATE public.personnages_donnees
         SET requisition = coalesce(v_req, '{}'::jsonb) || '{"statut":"incorpore","incorporationDifferee":true}'::jsonb
       WHERE name = v_moi;
      PERFORM public.recherche_retirer_desertion_interne(v_moi, v_pays);  -- incorporation_retire_desertion_v1
      RETURN jsonb_build_object('ok', true, 'mode', p_mode, 'differee', true);
    END IF;
    RETURN jsonb_build_object('ok',false,'raison','peine_pas_seulement_desertion');
  END IF;
  v_r := public.detention_clore_interne(v_moi, p_mode);
  -- incorporation_caserne_serveur_v1 : la caserne est une zone déclarée de la navigation.
  IF p_mode = 'incorporation' THEN
    IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles n JOIN public.personnages_donnees d
        ON d.name = v_moi AND n.pays = d.country WHERE n.ville = 'caserne'
        AND n.batiment = 'caserne-militaire' AND n.pieces ? 'corps_garde') THEN
      RAISE EXCEPTION 'caserne_non_referencee'; END IF;
    UPDATE public.personnages_donnees SET current_city = 'caserne', current_building = 'caserne-militaire',
           current_room = 'corps_garde', current_street = NULL,
           requisition = (coalesce(requisition, '{}'::jsonb) - 'incorporationDifferee') || '{"statut":"incorpore"}'::jsonb,
           updated_at = clock_timestamp() WHERE name = v_moi;
    PERFORM public.recherche_retirer_desertion_interne(v_moi, v_pays);  -- incorporation_retire_desertion_v1
  ELSE
    UPDATE public.personnages_donnees
       SET requisition = CASE WHEN requisition->>'statut' = 'deserteur'
                              THEN requisition || '{"statut":"eteinte"}'::jsonb ELSE requisition END
     WHERE name = v_moi AND jsonb_typeof(requisition) = 'object';
  END IF;
  RETURN v_r || jsonb_build_object('ok', true, 'mode', p_mode, 'differee', false);
END; $function$;

NOTIFY pgrst, 'reload schema';
