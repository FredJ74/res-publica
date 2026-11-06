-- A jouer APRES le corps de la migration 20261104023000, dans la meme transaction annulee.
DO $$
DECLARE r jsonb; ua uuid; t text; rech jsonb := '[{"acte":"desertion","country":"republic"},{"acte":"vol","country":"republic"}]';
BEGIN
  UPDATE public.budgets_nationaux SET data = jsonb_set(coalesce(data,'{}'), '{mobilisationNationaleActive}', 'true') WHERE id = 'republic';
  PERFORM set_config('rp.recherche_interne', 'on', true);
  UPDATE public.personnages_donnees SET requisition = '{"statut":"deserteur"}', recherche = rech, est_emprisonne = NULL,
         detention_qhs = NULL, country = 'republic', current_city = 'capitale' WHERE name IN ('Ben','Marsault');
  PERFORM set_config('rp.recherche_interne', '', true);
  UPDATE public.detentions SET mode_fin = 'banc' WHERE nom IN ('Ben','Marsault') AND mode_fin IS NULL;
  FOREACH t IN ARRAY ARRAY['Ben','Marsault'] LOOP PERFORM public.arrestation_flagrant_interne(t, 'desertion', false, 'banc'); END LOOP;
  UPDATE public.detentions SET motifs = motifs || '[{"acte":"vol"}]'::jsonb WHERE nom = 'Marsault' AND mode_fin IS NULL;
  PERFORM set_config('request.path', '/rpc/detention_clore_motif_eteint', true);
  FOREACH t IN ARRAY ARRAY['Ben','Marsault'] LOOP
    SELECT user_id INTO ua FROM public.personnages_donnees WHERE name = t;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    r := public.detention_clore_motif_eteint('incorporation');
    RESET ROLE;
    IF (r->>'ok')::boolean IS NOT TRUE OR (SELECT recherche FROM public.personnages_donnees WHERE name = t) <> '[{"acte":"vol","country":"republic"}]'::jsonb THEN
      RAISE EXCEPTION '% : %', t, r; END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM public.detention_active('Ben')) OR NOT EXISTS (SELECT 1 FROM public.detention_active('Marsault')) THEN
    RAISE EXCEPTION 'detentions'; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste';
END $$;
