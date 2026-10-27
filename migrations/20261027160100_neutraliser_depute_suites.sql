-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027190142.
-- Compilation eprouvee en transaction annulee.
-- Neutraliser un depute PNJ : le jet et la mise en sommeil etaient deja serveur, mais les suites
-- (trace « assassinat », detection, avis de recherche sur un echec) restaient a l'ecran.
-- assemblee_neutraliser_depute les fait desormais, comme crime_neutraliser. Idempotente.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.assemblee_neutraliser_depute(text,text,text,text)'::regprocedure);
  IF position('v_repere' IN v_def) = 0 THEN
    v_def := replace(v_def, E'  v_reussi  boolean;\n', E'  v_reussi  boolean;\n  v_repere  boolean := false;\n');
    v_def := replace(v_def,
      E'  RETURN public.assemblee_requete_clore(p_requete, v_debit || jsonb_build_object(\n    ''ok'', true, ''reussi'', v_reussi,',
      E'  -- SUITES PAR LE SERVEUR (27/10/2026) : trace, detection et avis de recherche.\n'
      || E'  IF v_reussi THEN\n'
      || E'    PERFORM public.crime_tracer_interne(p_nom, ''assassinat'', coalesce(to_jsonb(v_siege) ->> ''nom'', p_siege_id));\n'
      || E'    PERFORM public.crime_trace_rumeur_interne(p_nom, ''assassinat'', coalesce(to_jsonb(v_siege) ->> ''nom'', p_siege_id));\n'
      || E'    v_repere := public.crime_detecter_interne(p_nom, ''assassiner_'' || p_mode, true);\n'
      || E'  ELSE\n'
      || E'    PERFORM public.crime_rechercher_interne(p_nom, ''tentative_assassinat'', ''crime'');\n'
      || E'    v_repere := true;\n'
      || E'  END IF;\n'
      || E'  RETURN public.assemblee_requete_clore(p_requete, v_debit || jsonb_build_object(\n'
      || E'    ''ok'', true, ''reussi'', v_reussi, ''repere'', v_repere,\n'
      || E'    ''recherche'', (SELECT recherche FROM public.personnages_donnees WHERE name = p_nom),');
    IF position('v_repere := public.crime_detecter_interne' IN v_def) = 0 THEN RAISE EXCEPTION 'assemblee_neutraliser_depute : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;
