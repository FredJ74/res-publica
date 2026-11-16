-- Libération régulière : restituer entièrement le dépôt et ramener
-- le détenu de Sovarka au centre multimodal de sa ville de condamnation.
DO $liberation$
DECLARE source text;ancre text;ajout text;
BEGIN
  IF to_regprocedure('public.sovarka_goulag_depot_clore_interne(text,text,text)') IS NULL THEN
    RAISE EXCEPTION 'goulag_depot_absent'; END IF;
  source:=pg_get_functiondef('public.detention_clore_interne(text,text,integer)'::regprocedure);
  IF strpos(source,'goulag_liberation_avec_depot_20261116')>0 THEN RETURN; END IF;
  ancre:=E'  -- incorporation_differee_v1';
  ajout:=E'  -- goulag_liberation_avec_depot_20261116 : libération régulière sans perte ni double restitution.\n'
    ||E'  DECLARE v_goulag_res jsonb; v_goulag_retour text; v_goulag_bat text; v_goulag_piece text;\n'
    ||E'  BEGIN\n'
    ||E'   IF v_qhs AND v_det.country=''soviet'' AND p_mode=''purgee'' THEN\n'
    ||E'     IF EXISTS(SELECT 1 FROM public.sovarka_goulag_depots\n'
    ||E'        WHERE nom=p_nom AND detention_id=v_det.id) THEN\n'
    ||E'       v_goulag_res:=public.sovarka_goulag_depot_clore_interne(p_nom,v_det.id,''liberation'');\n'
    ||E'       IF coalesce((v_goulag_res->>''ok'')::boolean,false) IS NOT TRUE THEN\n'
    ||E'         RAISE EXCEPTION ''goulag_restitution_impossible''; END IF;\n'
    ||E'     END IF;\n'
    ||E'     IF (SELECT current_city FROM public.personnages_donnees WHERE name=p_nom)=''qhs'' THEN\n'
    ||E'       v_goulag_retour:=coalesce(nullif(v_peine->>''retourVille'',''''),v_det.city);\n'
    ||E'       IF v_goulag_retour NOT IN (''capitale'',''ville_a'',''ville_b'') OR v_goulag_retour IS NULL THEN\n'
    ||E'         RAISE EXCEPTION ''goulag_retour_ville_invalide'';END IF;\n'
    ||E'       SELECT batiment,pieces->>0 INTO v_goulag_bat,v_goulag_piece\n'
    ||E'         FROM public.navigation_lieux_regles WHERE pays=''soviet'' AND ville=v_goulag_retour\n'
    ||E'           AND batiment LIKE ''centre-multinodal-%'' ORDER BY batiment LIMIT 1;\n'
    ||E'       IF v_goulag_bat IS NULL THEN RAISE EXCEPTION ''goulag_retour_non_reference''; END IF;\n'
    ||E'       UPDATE public.personnages_donnees SET current_city=v_goulag_retour,\n'
    ||E'         current_building=v_goulag_bat,current_room=v_goulag_piece,current_street=NULL,\n'
    ||E'         updated_at=clock_timestamp() WHERE name=p_nom;\n'
    ||E'     END IF;\n'
    ||E'   END IF;\n'
    ||E'  END;\n'
    ||ancre;
  IF (length(source)-length(replace(source,ancre,'')))<>length(ancre) THEN
    RAISE EXCEPTION 'liberation_ancre_absente';END IF;
  EXECUTE replace(source,ancre,ajout);
END $liberation$;
