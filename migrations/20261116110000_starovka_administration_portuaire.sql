-- Starovka — bureau du Commandant du Port (Fred, 16/11/2026, GAME-DESIGN-REGULATION-PRODUCTION.md).
-- Une pièce de plus au Port Industriel de Starovka ; aucun ordre ni droit nouveau.
DO $starovka$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='ville_a' AND batiment='port-starovka')
  THEN RAISE EXCEPTION 'Starovka : port industriel introuvable'; END IF;

  UPDATE public.navigation_lieux_regles
    SET pieces = pieces || '["administration_portuaire"]'::jsonb
  WHERE pays='soviet' AND ville='ville_a' AND batiment='port-starovka'
    AND NOT pieces ? 'administration_portuaire';

  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='ville_a' AND batiment='port-starovka'
      AND pieces @> '["quai_principal","entrepot","douanes","administration_portuaire"]'::jsonb)
  THEN RAISE EXCEPTION 'Starovka : pièces du port incomplètes'; END IF;
END $starovka$;
