-- Banc annulé de 20261103153000_controles_entree_zone_serveur : à jouer APRÈS la migration, dans la
-- même transaction ; l'exception finale annule tout. Angie Porcelana, rue PSM tribunal-banque.
DO $banc$
DECLARE u uuid; n text := 'Angie Porcelana'; v jsonb;
BEGIN
  PERFORM set_config('request.path', '/rpc/navigation_interieure', true);
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;
  -- 1. Sans détachement ni couvre-feu : déplacement ordinaire, aucune arrestation.
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  v := public.navigation_interieure('banque-locale', 'guichet');
  RESET ROLE;
  IF NOT coalesce((v ->> 'ok')::boolean, false) OR v ? 'arrestation' THEN RAISE EXCEPTION 'banc 1: %', v; END IF;
  -- 2. Détachement simulé (contrôle remplacé dans la transaction) : l'arrestation part avec le déplacement.
  EXECUTE $f$CREATE OR REPLACE FUNCTION public.controle_detachement_interne(p_nom text) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $b$
    SELECT public.arrestation_flagrant_interne(p_nom, 'intrusion_zone_militaire', false, 'banc') || '{"controle":"detachement"}'::jsonb $b$$f$;
  SET LOCAL ROLE authenticated;
  v := public.navigation_interieure('banque-locale', 'bureau_directeur');
  RESET ROLE;
  IF NOT coalesce((v #>> '{arrestation,ok}')::boolean, false) OR (v #>> '{arrestation,jours}')::int <> 2
     OR (SELECT est_emprisonne FROM public.personnages_donnees WHERE name = n) IS NULL THEN
    RAISE EXCEPTION 'banc 2: %', v;
  END IF;
  -- 3. Les portes appelées par l'écran sont fermées.
  SET LOCAL ROLE authenticated;
  BEGIN PERFORM public.couvre_feu_patrouille(); RAISE EXCEPTION 'banc 3a'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM public.militaire_detachement_arrestation(); RAISE EXCEPTION 'banc 3b'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM public.controle_couvre_feu_interne(n); RAISE EXCEPTION 'banc 3c'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RESET ROLE;
  RAISE EXCEPTION 'BANC OK : déplacement ordinaire, arrestation jointe au déplacement (% j), portes écran fermées', v #>> '{arrestation,jours}';
END $banc$;
