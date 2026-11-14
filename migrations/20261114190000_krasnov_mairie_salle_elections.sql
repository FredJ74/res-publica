-- Krasnov : accès à la salle électorale, sans toucher aux scrutins.
BEGIN;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='ville_b' AND batiment='mairie'
      AND NOT ferme AND pieces ? 'accueil_mairie' AND pieces ? 'bureau_maire_local'
      AND pieces ? 'bureau_maire_adjoint' AND pieces ? 'salle_partis'
  ) THEN RAISE EXCEPTION 'Mairie de Krasnov : pièces initiales absentes'; END IF;
  UPDATE public.navigation_lieux_regles
     SET pieces=pieces || '["salle_elections"]'::jsonb
   WHERE pays='soviet' AND ville='ville_b' AND batiment='mairie'
     AND NOT pieces ? 'salle_elections';
  IF NOT EXISTS (
    SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='ville_b' AND batiment='mairie'
      AND pieces ? 'salle_elections' AND jsonb_array_length(pieces)=5
  ) THEN RAISE EXCEPTION 'Mairie de Krasnov : cinq pièces attendues'; END IF;
END $$;
COMMIT;
