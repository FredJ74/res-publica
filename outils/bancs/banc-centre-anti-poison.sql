-- A jouer APRES le corps de la migration 20261105101000, dans la meme transaction annulee.
-- BANC (annulé) : un PJ réel empoisonné, placé au dispensaire de Luthécia le temps de la transaction.
DO $$
DECLARE n text; u uuid; r jsonb; i integer; liq0 numeric; liq1 numeric;
BEGIN
  SELECT name, user_id INTO n, u FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0
    AND NOT EXISTS (SELECT 1 FROM public.detention_active(name)) ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale', current_building='bourse-commerce',
    pa = greatest(coalesce(pa,0), 10), liquide = greatest(liquide, 1000), hospitalisation = NULL,
    poison_actif = '{"actif":true,"palier":"partielle","poisonType":"parapluie"}'::jsonb WHERE name = n;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/centre_anti_poison_traiter', true);
  SET LOCAL ROLE authenticated;
  r := public.centre_anti_poison_traiter();
  IF r->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'hors lieu: %', r; END IF;
  RESET ROLE;
  UPDATE public.personnages_donnees SET current_building = 'dispensaire-public' WHERE name = n;
  SELECT liquide INTO liq0 FROM public.personnages_donnees WHERE name = n;
  FOR i IN 1..2 LOOP
    SET LOCAL ROLE authenticated;
    r := public.centre_anti_poison_traiter();
    RESET ROLE;
    IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'taux')::int <> 65 THEN RAISE EXCEPTION 'tentative %: %', i, r; END IF;
    IF (r->>'gueri')::boolean <> ((SELECT poison_actif FROM public.personnages_donnees WHERE name = n) IS NULL) THEN
      RAISE EXCEPTION 'verdict non applique: %', r; END IF;
    -- réempoisonner pour la tentative suivante
    UPDATE public.personnages_donnees SET poison_actif = '{"actif":true}'::jsonb WHERE name = n;
  END LOOP;
  SELECT liquide INTO liq1 FROM public.personnages_donnees WHERE name = n;
  IF liq0 - liq1 <> 120 THEN RAISE EXCEPTION 'cout: % -> %', liq0, liq1; END IF;
  SET LOCAL ROLE authenticated;
  r := public.centre_anti_poison_traiter();
  RESET ROLE;
  IF r->>'raison' IS DISTINCT FROM 'limite_journaliere' THEN RAISE EXCEPTION 'limite: %', r; END IF;
  UPDATE public.personnages_donnees SET poison_actif = NULL WHERE name = n;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (PJ %)', n;
END $$;
