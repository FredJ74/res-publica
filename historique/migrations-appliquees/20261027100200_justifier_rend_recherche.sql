-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261027112350.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027112350.
-- Eprouvee avant application en transaction annulee, au role authenticated (patch du retour). Baseline NON reextrait.
-- convocation_se_justifier rend aussi l'avis de recherche arrete par le serveur, que l'ecran
-- recopie au lieu de le recalculer (27 octobre 2026). Idempotente. Aucun acte de joueur.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.convocation_se_justifier(integer,integer)'::regprocedure);
  IF position('''recherche'', (SELECT' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'''issue'', ''classee'', ''motif'', v_c ->> ''motif'', ''taux'', v_taux)',
      E'''issue'', ''classee'', ''motif'', v_c ->> ''motif'', ''taux'', v_taux,\n'
      || E'      ''recherche'', (SELECT coalesce(recherche, ''[]''::jsonb) FROM public.personnages_donnees WHERE name = v_moi))');
    IF position('''recherche'', (SELECT' IN v_def) = 0 THEN RAISE EXCEPTION 'convocation_se_justifier : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;
