-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027192446. Eprouvee au role authenticated.
-- Produits du marche deposes par le serveur : reprend les deux metadonnees que l'ecran posait a
-- l'achat -- dateAchat (horodatage reel en millisecondes) pour un aliment, etatCarte « vierge »
-- pour une carte postale. Idempotente.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure);
  IF position('etatCarte' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'''bonusIntegrationVille'', v_ligne -> ''bonusIntegrationVille'')), true);',
      E'''bonusIntegrationVille'', v_ligne -> ''bonusIntegrationVille''))\n'
      || E'          || CASE v_ligne ->> ''familleProduitMarche''\n'
      || E'               WHEN ''aliment'' THEN jsonb_build_object(''dateAchat'', (extract(epoch FROM clock_timestamp()) * 1000)::bigint)\n'
      || E'               WHEN ''carte_postale'' THEN jsonb_build_object(''etatCarte'', ''vierge'') ELSE ''{}''::jsonb END, true);');
    IF position('etatCarte' IN v_def) = 0 THEN RAISE EXCEPTION 'commerce_vendre_produit_interne : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;
