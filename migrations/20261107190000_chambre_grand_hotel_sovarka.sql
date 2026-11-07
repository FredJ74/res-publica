-- Grand Hôtel de Sovarka (Novomirsk) : la réservation de chambre était payée sans créer de nuitée
-- (Fred, 07/11/2026). commerce_vendre_produit_interne ne créait le droit que pour le commerce de
-- La Républia (restaurant_luthecia_est_commerce : republic/capitale). Désormais : tout commerce
-- dont le bâtiment est 'hotel-republica', quel que soit le pays. hotel_nuitee_ajouter_interne
-- garde ses propres contrôles (PJ dans l'hôtel) et prend pays et ville du personnage.
-- Patch en place, sous empreinte : refus si le fragment attendu n'est pas présent une fois.
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
