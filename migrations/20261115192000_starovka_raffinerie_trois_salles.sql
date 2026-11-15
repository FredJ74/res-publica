-- Starovka — deux salles supplémentaires de la raffinerie (Fred, 15/11/2026).
-- La Direction existante reste accessible, et aucun ordre ni droit nouveau n'est ajouté.
DO $starovka$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='ville_a' AND batiment='usine-principale'
      AND pieces @> '["direction_usine"]'::jsonb)
  THEN RAISE EXCEPTION 'Starovka : direction usine introuvable'; END IF;

  UPDATE public.navigation_lieux_regles
    SET pieces = pieces
      || CASE WHEN pieces ? 'salle_ventes_raffinerie' THEN '[]'::jsonb ELSE '["salle_ventes_raffinerie"]'::jsonb END
      || CASE WHEN pieces ? 'interieur_raffinerie' THEN '[]'::jsonb ELSE '["interieur_raffinerie"]'::jsonb END
  WHERE pays='soviet' AND ville='ville_a' AND batiment='usine-principale';

  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='ville_a' AND batiment='usine-principale'
      AND pieces @> '["direction_usine","salle_ventes_raffinerie","interieur_raffinerie"]'::jsonb)
  THEN RAISE EXCEPTION 'Starovka : 3 salles de raffinerie incomplètes'; END IF;
END $starovka$;