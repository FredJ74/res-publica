-- Appartements présidentiels du Palais du Parti (Novomirsk), pièce ajoutée par roomsExtra dans
-- data.js pour le repas du président de Sovarka (Fred, 07/11/2026) : la navigation serveur ne
-- laisse entrer que dans une pièce référencée.
UPDATE public.navigation_lieux_regles
   SET pieces = CASE WHEN pieces @> '["appartements_president"]'::jsonb THEN pieces
                     ELSE pieces || '["appartements_president"]'::jsonb END
 WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'palais-presidentiel';
DO $v$ BEGIN
  IF NOT public.navigation_piece_referencee_interne('soviet','capitale','palais-presidentiel','appartements_president') THEN
    RAISE EXCEPTION 'appartements_president_non_reference';
  END IF;
END $v$;
