-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261027185704.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027185704.
-- Eprouvee au role authenticated (recrutement, plafond, interrogation 1 PA, ecriture directe ignoree, nuits payees/depart, rejeu sans double prelevement).
-- Salaires des informateurs : un rejeu de la passe de nuit le meme jour de Paris ne preleve rien
-- de plus (chaque informateur porte la date de son dernier salaire, payeLe). Idempotente.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.minuit_informateurs()'::regprocedure);
  IF position('payeLe' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'      IF v_liquide + v_solde >= v_cout THEN\n',
      E'      IF i ->> ''payeLe'' = to_char(now() AT TIME ZONE ''Europe/Paris'', ''YYYY-MM-DD'') THEN\n'
      || E'        v_garde := v_garde || jsonb_build_array(i);\n'
      || E'      ELSIF v_liquide + v_solde >= v_cout THEN\n');
    v_def := replace(v_def,
      E'jsonb_build_object(''joursActif'', coalesce((i ->> ''joursActif'')::integer, 0) + 1)',
      E'jsonb_build_object(''joursActif'', coalesce((i ->> ''joursActif'')::integer, 0) + 1, ''payeLe'', to_char(now() AT TIME ZONE ''Europe/Paris'', ''YYYY-MM-DD''))');
    IF (length(v_def) - length(replace(v_def, 'payeLe', ''))) / 6 < 2 THEN RAISE EXCEPTION 'minuit_informateurs : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;
