-- Goulag Sovarka : un juge prononce une peine QHS dans une affaire valide.
-- AUCUN pouvoir de condamnation n'est accordé au ministre de la Justice.
-- La peine est celle que justice_rendre_sentence a validée dans son barème.
-- Cette migration dépend du dépôt interne de Sovarka.
DO $goulag_juge$
DECLARE
  def text;
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
  EXECUTE replace(def,ancien,nouveau);
  IF strpos(pg_get_functiondef('public.justice_rendre_sentence(text,text,text,integer,integer)'::regprocedure),
            'goulag_sovarka_juge_seul_20261116') = 0 THEN
    RAISE EXCEPTION 'goulag_juge_raccordement_non_applique';
  END IF;
END $goulag_juge$;
