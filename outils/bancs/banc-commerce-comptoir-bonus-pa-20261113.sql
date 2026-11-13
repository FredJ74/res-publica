-- Banc : bonus de sommeil crédité dans la vente au comptoir (migration 20261113001000), 13/11/2026.
-- Joue la migration dans la transaction puis le scénario ; finit TOUJOURS par une exception : rien ne reste.
-- Coller la migration à l'endroit marqué. Compte de test : Arnie, Grand Hôtel de Novomirsk.
-- >>> MIGRATION 20261113001000_commerce_comptoir_bonus_pa_serveur.sql ICI <<<
DO $banc$
DECLARE U text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c'; A text := 'Arnie'; E text := 'brasserie-soviet-capitale-hotel-republica';
  v jsonb; b integer; rap text := '';
BEGIN
  UPDATE public.personnages_donnees SET bonus_pa_differe = 0, liquide = 5000 WHERE name = A;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', U, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.commerce_vendre_produit(A, E, '[{"produit":"menu_sovarka_imperial","qte":1}]'::jsonb, 'comptoir');
  IF (v->>'ok')::boolean IS NOT TRUE OR (v->>'bonus_pa_differe')::int IS DISTINCT FROM 3 THEN RAISE EXCEPTION 'ECHEC 1 menu %', v; END IF;
  rap := rap || '1 menu +3 OK ; ';
  v := public.commerce_vendre_produit(A, E, '[{"produit":"grand_hotel_zakouski","qte":1}]'::jsonb, 'comptoir');
  IF (v->>'ok')::boolean IS NOT TRUE OR v ? 'bonus_pa_differe' THEN RAISE EXCEPTION 'ECHEC 2 zakouski %', v; END IF;
  rap := rap || '2 zakouski sans bonus OK ; ';
  v := public.commerce_vendre_produit(A, E, '[{"produit":"menu_sovarka_tsars","qte":1}]'::jsonb, 'comptoir');
  IF (v->>'bonus_pa_differe')::int IS DISTINCT FROM 6 THEN RAISE EXCEPTION 'ECHEC 3 cumul %', v; END IF;
  rap := rap || '3 cumul 6 OK ; ';
  v := public.commerce_vendre_produit(A, E, '[{"produit":"menu_sovarka_plan","qte":1}]'::jsonb, 'comptoir', NULL, 0, 0, NULL);
  PERFORM set_config('role', 'postgres', true);
  SELECT bonus_pa_differe INTO b FROM public.personnages_donnees WHERE name = A;
  IF b <> 9 THEN RAISE EXCEPTION 'ECHEC 4 fiche %', b; END IF;
  rap := rap || '4 fiche 9 OK';
  RAISE EXCEPTION 'BANC VERT (annulé) : %', rap;
END $banc$;
