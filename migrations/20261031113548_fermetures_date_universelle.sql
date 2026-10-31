-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261017190000_fermetures_date_universelle.sql ; aucun changement de règle.
-- Préparation rétrocompatible : les fermetures possèdent désormais une échéance civile.
-- Aucune fermeture historique n'existe au moment de l'audit du 17 octobre 2026.
ALTER TABLE public.batiments_fermes
  ADD COLUMN IF NOT EXISTS date_fin_universelle date;

-- Les nouvelles fermetures doivent porter une date commune, indépendante du PJ.
-- Le champ jour_fin est conservé provisoirement pour compatibilité avec les anciens producteurs.
COMMENT ON COLUMN public.batiments_fermes.date_fin_universelle IS
  'Premier jour civil Europe/Paris de réouverture, indépendant des compteurs de PJ.';

ALTER TABLE public.batiments_fermes
  ADD COLUMN IF NOT EXISTS duree_jours integer;

CREATE OR REPLACE FUNCTION public.fermeture_definir_date_universelle()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.duree_jours IS NULL OR NEW.duree_jours < 1 OR NEW.duree_jours > 36500 THEN
    RAISE EXCEPTION 'Fermeture : duree_jours obligatoire (1..36500)';
  END IF;
  -- La base décide de la date, pas le navigateur ni le compteur individuel.
  NEW.date_fin_universelle := (now() AT TIME ZONE 'Europe/Paris')::date + NEW.duree_jours;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_fermeture_date_universelle ON public.batiments_fermes;
CREATE TRIGGER trg_fermeture_date_universelle
BEFORE INSERT ON public.batiments_fermes
FOR EACH ROW EXECUTE FUNCTION public.fermeture_definir_date_universelle();
