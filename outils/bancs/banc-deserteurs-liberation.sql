-- A jouer APRES le corps de la migration 20261104022000, dans la meme transaction annulee.
-- BANC (annulé) : mobilisation posée en Républia ; Lee (seule désertion), Marsault (désertion + autre
-- motif), Phileas (recherché, libre), Ben (incorporation directe), Jean Népa (non réquisitionné).
-- Arnie (min_def) démobilise.
DO $$
DECLARE r jsonb; u_arnie uuid; ua uuid; t text; deserteur jsonb := '{"statut":"deserteur","compagnieId":"banc"}';
  rech jsonb := '[{"acte":"desertion","country":"republic"},{"acte":"vol","country":"republic"}]';
BEGIN
  UPDATE public.budgets_nationaux SET data = jsonb_set(coalesce(data,'{}'), '{mobilisationNationaleActive}', 'true') WHERE id = 'republic';
  PERFORM set_config('rp.recherche_interne', 'on', true);
  UPDATE public.personnages_donnees SET requisition = deserteur, recherche = rech, est_emprisonne = NULL, detention_qhs = NULL,
         country = 'republic', current_city = 'capitale'
   WHERE name IN ('Lee Capene','Marsault','Phileas Frogg','Ben');
  UPDATE public.personnages_donnees SET requisition = NULL, est_emprisonne = NULL, country = 'republic', current_city = 'capitale' WHERE name = 'Jean Népa';
  PERFORM set_config('rp.recherche_interne', '', true);
  UPDATE public.detentions SET mode_fin = 'banc' WHERE nom IN ('Lee Capene','Marsault','Phileas Frogg','Ben','Jean Népa') AND mode_fin IS NULL;
  FOREACH t IN ARRAY ARRAY['Lee Capene','Marsault','Ben','Jean Népa'] LOOP
    r := public.arrestation_flagrant_interne(t, 'desertion', false, 'banc');
    IF NOT coalesce((r->>'ok')::boolean, false) THEN RAISE EXCEPTION 'arrestation %: %', t, r; END IF;
  END LOOP;
  UPDATE public.detentions SET motifs = motifs || '[{"acte":"vol"}]'::jsonb WHERE nom = 'Marsault' AND mode_fin IS NULL;
  PERFORM set_config('request.path', '/rpc/detention_clore_motif_eteint', true);

  -- 1. Mobilisation en cours : le détenu ne peut pas éteindre lui-même ses poursuites.
  SELECT user_id INTO ua FROM public.personnages_donnees WHERE name = 'Lee Capene';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.detention_clore_motif_eteint('poursuites_eteintes');
  RESET ROLE;
  IF r->>'raison' IS DISTINCT FROM 'mobilisation_en_cours' THEN RAISE EXCEPTION '1: %', r; END IF;

  -- 2. Désertion + autre motif : incorporation actée, différée.
  SELECT user_id INTO ua FROM public.personnages_donnees WHERE name = 'Marsault';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.detention_clore_motif_eteint('incorporation');
  RESET ROLE;
  IF (r->>'differee')::boolean IS NOT TRUE OR NOT EXISTS (SELECT 1 FROM public.detention_active('Marsault'))
     OR (SELECT requisition->>'incorporationDifferee' FROM public.personnages_donnees WHERE name='Marsault') IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION '2: %', r; END IF;

  -- 3. Non réquisitionné : pas d'incorporation.
  SELECT user_id INTO ua FROM public.personnages_donnees WHERE name = 'Jean Népa';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.detention_clore_motif_eteint('incorporation');
  RESET ROLE;
  IF r->>'raison' IS DISTINCT FROM 'pas_deserteur' THEN RAISE EXCEPTION '3: %', r; END IF;

  -- 4. Seule désertion, mobilisation en cours : incorporation immédiate, conduit au corps de garde.
  SELECT user_id INTO ua FROM public.personnages_donnees WHERE name = 'Ben';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.detention_clore_motif_eteint('incorporation');
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'differee')::boolean OR EXISTS (SELECT 1 FROM public.detention_active('Ben'))
     OR (SELECT current_room || '/' || (requisition->>'statut') FROM public.personnages_donnees WHERE name='Ben') <> 'corps_garde/incorpore' THEN
    RAISE EXCEPTION '4: %', r; END IF;

  -- 5. Démobilisation par le ministre : tout le pays, pas lui seul.
  SELECT user_id INTO u_arnie FROM public.personnages_donnees WHERE name = 'Arnie';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u_arnie, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/militaire_mobilisation_fixer', true);
  SET LOCAL ROLE authenticated;
  r := public.militaire_mobilisation_fixer(false);
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE OR NOT (r->'extinction'->'liberes' @> '["Lee Capene"]')
     OR r->'extinction'->'liberes' @> '["Marsault"]' THEN RAISE EXCEPTION '5: %', r; END IF;
  IF EXISTS (SELECT 1 FROM public.detention_active('Lee Capene'))
     OR (SELECT est_emprisonne FROM public.personnages_donnees WHERE name='Lee Capene') IS NOT NULL
     OR (SELECT mode_fin FROM public.detentions WHERE nom='Lee Capene' ORDER BY created_at DESC LIMIT 1) <> 'poursuites_eteintes' THEN
    RAISE EXCEPTION '5 Lee detention'; END IF;
  IF (SELECT requisition->>'statut' FROM public.personnages_donnees WHERE name='Phileas Frogg') <> 'eteinte'
     OR (SELECT recherche FROM public.personnages_donnees WHERE name='Phileas Frogg') <> '[{"acte":"vol","country":"republic"}]'::jsonb
     OR (SELECT recherche FROM public.personnages_donnees WHERE name='Lee Capene') <> '[{"acte":"vol","country":"republic"}]'::jsonb THEN
    RAISE EXCEPTION '5 recherche/requisition'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.detention_active('Marsault'))
     OR (SELECT requisition ? 'incorporationDifferee' FROM public.personnages_donnees WHERE name='Marsault') THEN
    RAISE EXCEPTION '5 Marsault'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.mails WHERE to_player='Lee Capene' AND from_player='Caserne' AND subject='Poursuites éteintes') THEN
    RAISE EXCEPTION '5 courrier'; END IF;

  -- 6. Mobilisation levée : la porte du détenu accepte l'extinction, refuse l'incorporation.
  SELECT user_id INTO ua FROM public.personnages_donnees WHERE name = 'Marsault';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/detention_clore_motif_eteint', true);
  SET LOCAL ROLE authenticated;
  r := public.detention_clore_motif_eteint('incorporation');
  RESET ROLE;
  IF r->>'raison' IS DISTINCT FROM 'mobilisation_levee' THEN RAISE EXCEPTION '6: %', r; END IF;

  -- 7. Incorporation différée effective à la fin de peine (mobilisation rétablie).
  UPDATE public.budgets_nationaux SET data = jsonb_set(data, '{mobilisationNationaleActive}', 'true') WHERE id = 'republic';
  UPDATE public.personnages_donnees SET requisition = deserteur WHERE name = 'Marsault';
  SET LOCAL ROLE authenticated;
  r := public.detention_clore_motif_eteint('incorporation');
  RESET ROLE;
  IF (r->>'differee')::boolean IS NOT TRUE THEN RAISE EXCEPTION '7a: %', r; END IF;
  PERFORM public.detention_clore_interne('Marsault', 'purgee');
  IF (SELECT current_room FROM public.personnages_donnees WHERE name='Marsault') <> 'corps_garde'
     OR (SELECT requisition ? 'incorporationDifferee' FROM public.personnages_donnees WHERE name='Marsault')
     OR NOT EXISTS (SELECT 1 FROM public.mails WHERE to_player='Marsault' AND from_player='Caserne' AND subject='Incorporation') THEN
    RAISE EXCEPTION '7b'; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste';
END $$;
