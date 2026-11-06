-- A jouer APRES la migration 20261107010000, dans la meme transaction annulee.
-- Demande de location au bureau B, attribution (porte interne du maire), signature chez le notaire,
-- guichet ferme, bail cree avec le bon libelle et le loyer de 150 PSK.
DO $$
DECLARE n text; u uuid; r jsonb; v_dem text; v_bail jsonb;
BEGIN
  SELECT name, user_id INTO n, u FROM public.personnages_donnees
   WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0
     AND NOT EXISTS (SELECT 1 FROM public.sovarka_demandes d WHERE d.demandeur = name AND d.statut IN ('en_attente','acceptee','attribuee'))
   ORDER BY name LIMIT 1;
  UPDATE public.personnages_donnees SET country='soviet', current_city='capitale', current_building='centre-affaires',
    current_room='bureau_prestige_b', pa = greatest(coalesce(pa,0),10), hospitalisation=NULL WHERE name = n;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.local_louer(gen_random_uuid(), 'bureau_prestige_b');
  IF r->>'raison' IS DISTINCT FROM 'attribution_municipale' THEN RAISE EXCEPTION 'guichet non ferme: %', r; END IF;
  r := public.sovarka_demande_location('centre-affaires', 'bureau_prestige_b', 'Siège d''association');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'demande: %', r; END IF;
  RESET ROLE;
  SELECT id INTO v_dem FROM public.sovarka_demandes WHERE demandeur = n AND statut = 'en_attente';
  r := public.sovarka_reserver_local_interne(v_dem, 'centre-affaires', 'bureau_prestige_b', 'Banc');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'attribution: %', r; END IF;
  UPDATE public.personnages_donnees SET current_building='office-notarial' WHERE name = n;
  SET LOCAL ROLE authenticated;
  r := public.sovarka_attribution_signer(v_dem);
  RESET ROLE;
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'signature: %', r; END IF;
  SELECT data INTO v_bail FROM public.locations_actives WHERE id = public.sovarka_bail_id('capitale','centre-affaires','bureau_prestige_b');
  IF v_bail->>'locataire' IS DISTINCT FROM n OR (v_bail->>'prix')::int <> 150
     OR v_bail->>'batimentLabel' IS DISTINCT FROM 'Centre d''affaires' THEN
    RAISE EXCEPTION 'bail: %', v_bail; END IF;
  RAISE EXCEPTION 'BANC_OK % : guichet ferme, demande, attribution, signature, bail % a % PSK', n, v_bail->>'localLabel', v_bail->>'prix';
END $$;
