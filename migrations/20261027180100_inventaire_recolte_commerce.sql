-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027192416. Eprouvee au role authenticated.
-- ============================================================================
-- INVENTAIRE, LOT 2 : RECOLTE ET PRODUITS DU MARCHE DEPOSES PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- * recolte_effectuer : la recolte (seule source de matiere premiere) ecrivait l'inventaire depuis
--   l'ecran, avec sa limite de 2 par jour tenue par l'ecran. Le serveur verifie que la matiere se
--   recolte dans la ville du joueur (MATIERES_PREMIERES_VILLE), tient la limite par date de Paris,
--   preleve l'ordre, tire 1 ou 2 unites et les depose (empilables pour metal, poisson, charbon,
--   bois ; une unite par objet pour les autres, comme l'ecran).
-- * commerce_vendre_produit_interne depose lui-meme les produits du marche non alimentaires
--   (familleProduitMarche) qu'il vient de vendre, et rend l'inventaire.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.recoltes_journalieres (
  nom  text NOT NULL,
  jour date NOT NULL,
  nb   integer NOT NULL DEFAULT 0,
  PRIMARY KEY (nom, jour)
);
ALTER TABLE public.recoltes_journalieres ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.recoltes_journalieres FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.recolte_effectuer(p_matiere text, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_nb integer; v_paie jsonb;
  v_q integer; v_cle text; v_dep jsonb; k integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT (p_matiere = ANY (CASE m.country || ':' || coalesce(m.current_city, '')
      WHEN 'republic:ville_a' THEN ARRAY['Poisson'] WHEN 'republic:ville_b' THEN ARRAY['Charbon', 'Métal']
      WHEN 'narco:ville_a' THEN ARRAY['Bois', 'Cuir'] WHEN 'narco:ville_b' THEN ARRAY['Bois exotique', 'Caoutchouc']
      WHEN 'soviet:ville_a' THEN ARRAY['Minerai de fer', 'Charbon'] WHEN 'soviet:ville_b' THEN ARRAY['Blé', 'Cuir']
      WHEN 'khalija:ville_a' THEN ARRAY['Épices', 'Coton'] WHEN 'khalija:ville_b' THEN ARRAY['Pétrole', 'Poisson']
      ELSE ARRAY[]::text[] END)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_recolter_ici'); END IF;
  SELECT nb INTO v_nb FROM public.recoltes_journalieres WHERE nom = v_moi AND jour = v_jour FOR UPDATE;
  IF coalesce(v_nb, 0) >= 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'limite_atteinte'); END IF;
  v_q := floor(random() * 2)::integer + 1;
  v_cle := CASE p_matiere WHEN 'Métal' THEN 'metal' WHEN 'Poisson' THEN 'poisson' WHEN 'Charbon' THEN 'charbon' WHEN 'Bois' THEN 'bois' END;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = v_moi) < v_q THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_paie := public.payer_ordre(v_moi, 'recolter_matiere', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  INSERT INTO public.recoltes_journalieres (nom, jour, nb) VALUES (v_moi, v_jour, 1)
  ON CONFLICT (nom, jour) DO UPDATE SET nb = public.recoltes_journalieres.nb + 1;
  IF v_cle IS NOT NULL THEN
    v_dep := public.inventaire_deposer_interne(v_moi, jsonb_build_object('name', p_matiere,
      'icon', CASE v_cle WHEN 'metal' THEN 'ti-bolt' WHEN 'poisson' THEN 'ti-fish' WHEN 'charbon' THEN 'ti-flame' ELSE 'ti-trees' END,
      'stackable', true, 'stackKey', v_cle, 'qty', v_q, 'desc', 'Récolté localement.'));
  ELSE
    FOR k IN 1..v_q LOOP
      v_dep := public.inventaire_deposer_interne(v_moi, jsonb_build_object('type', 'matiere_premiere', 'matiere', p_matiere,
        'name', p_matiere, 'icon', 'ti-package'));
    END LOOP;
  END IF;
  IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'recolte_effectuer: depot refuse %', v_dep; END IF;
  RETURN jsonb_build_object('ok', true, 'quantite', v_q, 'recoltes_jour', coalesce(v_nb, 0) + 1, 'pa', v_paie -> 'pa')
    || (v_dep - 'ok' - 'qte');
END; $function$;

-- Les produits du marche non alimentaires sont deposes par la vente elle-meme.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure);
  IF position('familleProduitMarche deposes' IN v_def) = 0 THEN
    v_def := replace(v_def, E'  RETURN jsonb_build_object(''ok'', true, ''mode'', p_mode,',
      E'  -- Produits du marche non alimentaires (familleProduitMarche deposes par le serveur, 27/10/2026).\n'
      || E'  FOR v_ligne IN SELECT value FROM jsonb_array_elements(v_livraison) LOOP\n'
      || E'    IF coalesce(v_ligne ->> ''familleProduitMarche'', '''') <> '''' THEN\n'
      || E'      FOR v_i IN 1..coalesce((v_ligne ->> ''qte'')::numeric, 1)::integer LOOP\n'
      || E'        v_r := public.inventaire_deposer_interne(p_acteur, jsonb_strip_nulls(jsonb_build_object(\n'
      || E'          ''id'', (v_ligne ->> ''produit'') || ''_'' || replace(gen_random_uuid()::text, ''-'', ''''),\n'
      || E'          ''type'', v_ligne ->> ''produit'', ''name'', v_ligne ->> ''label'', ''icon'', coalesce(v_ligne ->> ''icone'', ''ti-package''),\n'
      || E'          ''imageUrl'', v_ligne ->> ''image'', ''desc'', v_ligne ->> ''description'', ''villeOrigine'', v_ville,\n'
      || E'          ''familleProduitMarche'', v_ligne -> ''familleProduitMarche'', ''bonusIntegrationVille'', v_ligne -> ''bonusIntegrationVille'')), true);\n'
      || E'      END LOOP;\n'
      || E'    END IF;\n'
      || E'  END LOOP;\n'
      || E'  RETURN (SELECT jsonb_build_object(''inventory'', inventory, ''revision'', inventory_revision) FROM public.personnages_donnees WHERE name = p_acteur)\n'
      || E'    || jsonb_build_object(''ok'', true, ''mode'', p_mode,');
    v_def := replace(v_def, E'  v_pa_metier numeric := 0; v_pa_actuel integer;\n', E'  v_pa_metier numeric := 0; v_pa_actuel integer; v_i integer;\n');
    IF position('familleProduitMarche deposes' IN v_def) = 0 OR position('v_i integer' IN v_def) = 0 THEN
      RAISE EXCEPTION 'commerce_vendre_produit_interne : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;

REVOKE ALL ON FUNCTION public.recolte_effectuer(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recolte_effectuer(text, integer, integer) TO authenticated;
