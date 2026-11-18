-- Goulag Sovarka : un juge prononce une peine QHS dans une affaire valide.
-- AUCUN pouvoir de condamnation n'est accordé au ministre de la Justice.
-- La peine est celle que justice_rendre_sentence a validée dans son barème.
-- Cette migration dépend du dépôt interne de Sovarka.
DO $goulag_juge$
DECLARE
  def text;
  ancre_auth text := E'  v_a := v_brut::jsonb;';
  garde_auth text := E'  v_a := v_brut::jsonb;\n'
    || E'  -- goulag_sovarka_jugement_auth_20261116 : aucune condamnation inopinée tant que le circuit n est pas actif.\n'
    || E'  IF v_pays = ''soviet'' AND p_genre = ''qhs'' THEN\n'
    || E'    IF NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration c WHERE c.singleton AND c.active)\n'
    || E'       OR current_setting(''rp.goulag_jugement_interne'',true) IS DISTINCT FROM ''valide'' THEN\n'
    || E'      RETURN jsonb_build_object(''ok'',false,''raison'',''goulag_non_active''); END IF;\n'
    || E'  END IF;';
  ancre_suite text := E'  UPDATE public.plaintes_en_cours';
  suite text := E'  -- goulag_sovarka_detention_existante_20261116 : le transfert suit une condamnation réelle.\n'
    || E'  IF v_pays=''soviet'' AND p_genre=''qhs'' AND v_det.id IS NOT NULL THEN\n'
    || E'    v_exec:=public.justice_prolonger_peine(v_a->>''cible'',v_motifs,true);\n'
    || E'    IF coalesce((v_exec->>''ok'')::boolean,false) IS NOT TRUE THEN\n'
    || E'      RAISE EXCEPTION ''goulag_peine_non_prolongee''; END IF;\n'
    || E'    SELECT * INTO v_det FROM public.detention_active(v_a->>''cible'');\n'
    || E'    IF v_det.id IS NULL OR NOT v_det.qhs THEN RAISE EXCEPTION ''goulag_transfert_absent''; END IF;\n'
    || E'    IF coalesce((public.sovarka_goulag_confisquer_interne(v_a->>''cible'',v_det.id)->>''ok'')::boolean,false) IS NOT TRUE THEN\n'
    || E'      RAISE EXCEPTION ''goulag_confiscation_impossible''; END IF;\n'
    || E'    UPDATE public.jugements SET executee=true WHERE id=v_jug;\n'
    || E'    v_executee:=true; v_exec:=v_exec||jsonb_build_object(''detention_id'',v_det.id);\n'
    || E'  END IF;\n'
    || E'  UPDATE public.plaintes_en_cours';
  ancien text := E'        UPDATE public.jugements SET executee = true WHERE id = v_jug;\n        v_executee := true;';
  nouveau text := E'        -- goulag_sovarka_juge_seul_20261116 : même jugement, aucun bouton ministériel.\n'
    || E'        IF v_pays = ''soviet'' AND p_genre = ''qhs'' THEN\n'
    || E'          PERFORM public.detention_qhs_poser_interne(v_a ->> ''cible'',\n'
    || E'            v_exec ->> ''detention_id'', ''Condamnation au goulag de Sovarka'');\n'
    || E'          IF NOT coalesce((public.sovarka_goulag_confisquer_interne(\n'
    || E'               v_a ->> ''cible'', v_exec ->> ''detention_id'') ->> ''ok'')::boolean, false)\n'
    || E'          THEN RAISE EXCEPTION ''goulag_confiscation_impossible''; END IF;\n'
    || E'        END IF;\n'
    || E'        UPDATE public.jugements SET executee = true WHERE id = v_jug;\n'
    || E'        v_executee := true;';
BEGIN
  IF to_regprocedure('public.sovarka_goulag_confisquer_interne(text,text)') IS NULL THEN
    RAISE EXCEPTION 'depot_goulag_non_installe';
  END IF;
  def := pg_get_functiondef('public.justice_rendre_sentence(text,text,text,integer,integer)'::regprocedure);
  IF strpos(def,'goulag_sovarka_juge_seul_20261116') > 0 THEN RETURN; END IF;
  IF (length(def)-length(replace(def,ancien,''))) <> length(ancien) THEN
    RAISE EXCEPTION 'justice_rendre_sentence_signature_non_examinee';
  END IF;
  IF strpos(def,ancre_auth)=0 OR strpos(def,ancre_suite)=0 THEN
    RAISE EXCEPTION 'justice_rendre_sentence_ancre_absente';END IF;
  EXECUTE replace(replace(replace(def,ancien,nouveau),ancre_auth,garde_auth),ancre_suite,suite);
  IF strpos(pg_get_functiondef('public.justice_rendre_sentence(text,text,text,integer,integer)'::regprocedure),
            'goulag_sovarka_juge_seul_20261116') = 0 THEN
    RAISE EXCEPTION 'goulag_juge_raccordement_non_applique';
  END IF;
END $goulag_juge$;
