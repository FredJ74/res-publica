-- Banc annule (rien ne reste) : migration 20261114220000 puis une vente reelle a un PJ de test.
-- A jouer en bloc : la migration (sans BEGIN/COMMIT) est inseree a la place de \i ci-dessous.
DO $banc$
DECLARE v jsonb; v_inv jsonb; v_carte jsonb; v_revue jsonb; v_pj text := 'Arnie';
BEGIN
  PERFORM set_config('request.path', '/rpc/commerce_vendre_produit', true);
  UPDATE public.personnages_donnees SET country='soviet', current_city='ville_b', current_building='tabac-presse-krasnov',
         liquide = coalesce(liquide,0) + 100 WHERE name = v_pj;
  v := public.commerce_vendre_produit_interne(v_pj, 'tabac-presse-soviet-ville_b-tabac-presse-krasnov',
         '[{"produit":"carte_krasnov_place_ours","qte":1},{"produit":"revue_chasse_peche_tracteurs","qte":1},{"produit":"krasnov_papirossy","qte":1}]'::jsonb, 'comptoir');
  IF (v->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'banc : vente refusee %', v; END IF;
  IF (v->>'total')::numeric <> 9 THEN RAISE EXCEPTION 'banc : total % au lieu de 9', v->>'total'; END IF;
  SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name = v_pj;
  SELECT e INTO v_carte FROM jsonb_array_elements(v_inv) e WHERE e->>'type' = 'carte_krasnov_place_ours' LIMIT 1;
  SELECT e INTO v_revue FROM jsonb_array_elements(v_inv) e WHERE e->>'type' = 'revue_chasse_peche_tracteurs' LIMIT 1;
  IF v_carte IS NULL OR v_carte->>'etatCarte' <> 'vierge' OR v_carte->>'familleProduitMarche' <> 'carte_postale' THEN
    RAISE EXCEPTION 'banc : carte non deposee %', v_carte; END IF;
  IF v_revue IS NULL OR v_revue->>'bonusIntegrationVille' <> 'soviet.ville_b' THEN RAISE EXCEPTION 'banc : revue non deposee %', v_revue; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) e WHERE e->>'type' = 'krasnov_papirossy') THEN
    RAISE EXCEPTION 'banc : les papirossy se fument au comptoir, pas en inventaire'; END IF;
  IF jsonb_typeof(v->'inventory') <> 'array' THEN RAISE EXCEPTION 'banc : inventaire non rendu'; END IF;
  RAISE EXCEPTION 'banc OK : rien ne doit rester (carte %, revue %)', v_carte->>'id', v_revue->>'id';
END $banc$;
