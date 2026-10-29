-- À APPLIQUER JUSTE APRÈS LA LIVRAISON de l'écran qui appelle `local_louer`
-- (branche claude/centres-villes-20261029). NON APPLIQUÉE.
-- Le navigateur ne peut plus CRÉER un bail de local à loyer fixe signé par le serveur
-- (centres des trois villes, suites, coffre) : il passe par `local_louer`. Les mises à jour
-- (organisation, visibilité) et la résiliation restent ouvertes ; le box portuaire aussi.
CREATE OR REPLACE FUNCTION public.location_local_creation_serveur()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ref public.locaux_loyers_referentiel;
BEGIN
  IF public.est_appel_serveur() OR NEW.data IS NULL THEN RETURN NEW; END IF;
  ref := public.local_referentiel_interne(NEW.data->>'buildingId', NEW.data->>'roomId', NEW.data->>'city');
  IF ref.batiment IS NOT NULL AND ref.signature_serveur THEN
    RAISE EXCEPTION 'bail_signe_par_le_serveur' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS location_local_creation_serveur ON public.locations_actives;
CREATE TRIGGER location_local_creation_serveur BEFORE INSERT ON public.locations_actives
  FOR EACH ROW EXECUTE FUNCTION public.location_local_creation_serveur();
