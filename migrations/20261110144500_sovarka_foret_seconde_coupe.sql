-- Foret profonde de Krasnov : precisions de Fred du 10/11/2026 (14 h 40 - 14 h 42), GAME-DESIGN-NOVOMIRSK.md.
--   1. La premiere coupe est acquise : « Fuir » ne retire plus aucun bois ; on ne perd que la seconde coupe, jamais livree.
--   2. Victoire totale sur la vue 3 : le leader recoit le bois de la seconde coupe (2 a 4) en plus du butin.
--   3. Olga (vue 4) : la seconde coupe rapporte aussi son bois (2 a 4) en plus du repas (place d'inventaire exigee).
-- Patchs en place sur les definitions vivantes, ancres verifies (une occurrence exactement), rejouable.
BEGIN;
DO $raccord$
DECLARE d text; avant text; apres text;
BEGIN
  -- 1. Fuite : plus de retrait de bois.
  d := pg_get_functiondef('public.sovarka_foret_rencontre(uuid, text)'::regprocedure);
  IF position('premiere coupe est acquise' IN d) = 0 THEN
    avant := E'IF v_perdu > 0 THEN PERFORM public.sovarka_inventaire_retirer_interne(a, l, v_perdu); END IF;';
    apres := E'v_perdu := 0;  -- la premiere coupe est acquise (Fred, 10/11) : la fuite ne fait perdre que la seconde, jamais livree';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'sovarka_foret_rencontre : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;

  -- 2. Victoire : bois de la seconde coupe ajoute au butin, et mentionne dans le mail.
  d := pg_get_functiondef('public.sovarka_foret_issue_combat_interne(text, text, text)'::regprocedure);
  IF position('seconde coupe' IN d) = 0 THEN
    avant := E'             UNION ALL\n             SELECT jsonb_build_object(''name'', ''Dent d''''ours''';
    apres := E'             UNION ALL\n             SELECT public.sovarka_matiere_objet_interne(''bois'', (floor(random() * 2)::integer + 1) * 2, ''Seconde coupe dans la forêt profonde de Krasnov.'')\n'
          || avant;
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'sovarka_foret_issue : ancrage butin introuvable'; END IF;
    d := replace(d, avant, apres);
    avant := E'''. Le butin (peaux, viande''';
    apres := E'''. Le bois de la seconde coupe et le butin (peaux, viande''';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'sovarka_foret_issue : ancrage mail introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;

  -- 3. Olga : place d'inventaire exigee et bois depose.
  d := pg_get_functiondef('public.sovarka_foret_couper(uuid)'::regprocedure);
  IF position('Olga donne aussi' IN d) = 0 THEN
    avant := E'IF NOT (v_vue IN (3, 4) AND v_k = 2)';
    apres := E'IF NOT (v_vue = 3 AND v_k = 2)';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'sovarka_foret_couper : ancrage place introuvable'; END IF;
    d := replace(d, avant, apres);
    avant := E'    r := jsonb_build_object(''ok'', true, ''rencontre'', ''olga'', ''nourris'', v_nourris, ''bonus'', v_bonus);';
    apres := E'    -- Olga donne aussi le bois de la seconde coupe (Fred, 10/11).\n'
          || E'    v_q := (floor(random() * 2)::integer + 1) * 2;\n'
          || E'    v_dep := public.inventaire_deposer_interne(a, public.sovarka_matiere_objet_interne(''bois'', v_q, ''Coupé dans la forêt profonde de Krasnov.''));\n'
          || E'    IF coalesce((v_dep->>''ok'')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION ''sovarka_foret_couper: depot refuse %'', v_dep; END IF;\n'
          || E'    UPDATE public.sovarka_foret_visites SET bois = bois + v_q WHERE bucheron = a;\n'
          || E'    r := jsonb_build_object(''ok'', true, ''rencontre'', ''olga'', ''nourris'', v_nourris, ''bonus'', v_bonus, ''quantite'', v_q);';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'sovarka_foret_couper : ancrage olga introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;

  IF position('premiere coupe est acquise' IN pg_get_functiondef('public.sovarka_foret_rencontre(uuid, text)'::regprocedure)) = 0
     OR position('seconde coupe' IN pg_get_functiondef('public.sovarka_foret_issue_combat_interne(text, text, text)'::regprocedure)) = 0
     OR position('Olga donne aussi' IN pg_get_functiondef('public.sovarka_foret_couper(uuid)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'sovarka_foret_seconde_coupe : patch incomplet';
  END IF;
END $raccord$;
COMMIT;
