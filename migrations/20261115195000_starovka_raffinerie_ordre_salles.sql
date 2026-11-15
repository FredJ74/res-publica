-- Starovka : salle des ventes en entrée, atelier ensuite, direction en dernier.
-- Réordonne uniquement les pièces du bâtiment local, sans changer les permissions ni ordres.
DO $starovka$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_a' AND batiment='usine-principale'
   AND pieces @> '["salle_ventes_raffinerie","interieur_raffinerie","direction_usine"]'::jsonb)
 THEN RAISE EXCEPTION 'Raffinerie Starovka : pièces incomplètes'; END IF;
 UPDATE public.navigation_lieux_regles
 SET pieces='["salle_ventes_raffinerie","interieur_raffinerie","direction_usine"]'::jsonb
 WHERE pays='soviet' AND ville='ville_a' AND batiment='usine-principale';
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_a' AND batiment='usine-principale'
   AND pieces='["salle_ventes_raffinerie","interieur_raffinerie","direction_usine"]'::jsonb)
 THEN RAISE EXCEPTION 'Raffinerie Starovka : ordre non appliqué'; END IF;
END $starovka$;