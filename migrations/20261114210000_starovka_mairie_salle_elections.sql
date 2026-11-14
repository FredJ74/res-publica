-- Starovka : accès à la salle des élections de la mairie (Fred, 14/11/2026), sans toucher aux scrutins.
-- Même modèle que Krasnov (20261114190000). Appliquée sous le nom starovka_mairie_salle_elections_20261114.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='ville_a' AND batiment='mairie'
      AND NOT ferme AND pieces ? 'accueil_mairie' AND pieces ? 'bureau_maire_local'
      AND pieces ? 'bureau_maire_adjoint' AND pieces ? 'salle_partis'
  ) THEN RAISE EXCEPTION 'Mairie de Starovka : pièces initiales absentes'; END IF;
  UPDATE public.navigation_lieux_regles
     SET pieces = pieces || '["salle_elections"]'::jsonb
   WHERE pays='soviet' AND ville='ville_a' AND batiment='mairie'
     AND NOT pieces ? 'salle_elections';
  IF NOT EXISTS (
    SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='ville_a' AND batiment='mairie'
      AND pieces ? 'salle_elections' AND jsonb_array_length(pieces)=5
  ) THEN RAISE EXCEPTION 'Mairie de Starovka : cinq pièces attendues'; END IF;
END $$;
