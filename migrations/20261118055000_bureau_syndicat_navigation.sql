-- BUREAU DU SYNDICAT NATIONAL (Fred, 18/11/2026, point 7) : la pièce « bureau_syndicat_national » des mairies
-- de Novomirsk, Starovka et Krasnov devient une pièce navigable au serveur (navigation_lieux_regles), comme
-- l'administration portuaire de Starovka (20261116110000). La référence du 31/10 reste inchangée (le
-- générateur outils/generateurs/navigation-lieux.cjs écarte cette pièce). Idempotente.
BEGIN;
UPDATE public.navigation_lieux_regles SET pieces = pieces || '["bureau_syndicat_national"]'::jsonb
 WHERE pays = 'soviet' AND ((ville = 'capitale' AND batiment = 'mairie-capitale') OR (ville IN ('ville_a', 'ville_b') AND batiment = 'mairie'))
   AND NOT pieces ? 'bureau_syndicat_national';
DO $$ BEGIN
  IF (SELECT count(*) FROM public.navigation_lieux_regles
       WHERE pays = 'soviet' AND pieces ? 'bureau_syndicat_national'
         AND ((ville = 'capitale' AND batiment = 'mairie-capitale') OR (ville IN ('ville_a', 'ville_b') AND batiment = 'mairie'))) <> 3
  THEN RAISE EXCEPTION 'bureau_syndicat_navigation : controle structurel en echec'; END IF;
END $$;
COMMIT;
