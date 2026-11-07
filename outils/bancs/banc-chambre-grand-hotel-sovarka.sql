DO $m$
DECLARE d text; ancien text; nouveau text;
BEGIN
  d := pg_get_functiondef('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure);
  ancien := 'IF public.restaurant_luthecia_est_commerce(v_data) AND p_ordre=''reserver_chambre_hotel'' THEN';
  nouveau := 'IF coalesce(v_data->>''buildingId'','''')=''hotel-republica'' AND p_ordre=''reserver_chambre_hotel'' THEN';
  IF position(nouveau in d) > 0 THEN RAISE NOTICE 'déjà appliqué'; RETURN; END IF;
  IF (length(d) - length(replace(d, ancien, ''))) / length(ancien) <> 1 THEN
    RAISE EXCEPTION 'empreinte_inattendue_commerce_vendre_produit_interne';
  END IF;
  EXECUTE replace(d, ancien, nouveau);
END $m$;
DO $b$
DECLARE avant int; apres int; r jsonb; liq_av numeric; liq_ap numeric;
BEGIN
  SELECT count(*) INTO avant FROM hotel_nuitees n JOIN personnages_donnees p ON p.id=n.personnage_id WHERE p.name='Arnie' AND n.consommee_le IS NULL;
  r := to_jsonb(public.commerce_vendre_produit_interne('Arnie','brasserie-soviet-capitale-hotel-republica','[]'::jsonb,'service','reserver_chambre_hotel',0,80,NULL,NULL));
  SELECT count(*) INTO apres FROM hotel_nuitees n JOIN personnages_donnees p ON p.id=n.personnage_id WHERE p.name='Arnie' AND n.consommee_le IS NULL;
  RAISE EXCEPTION 'BANC (annulé) nuitées % -> % ; réponse %', avant, apres, left(r::text,300);
END $b$;
