-- Étoile Rouge de Krasnov : boutique du club (Fred, 14/11/2026), comme la boutique du Dynamo (20261110000500).
-- 1. La pièce « boutique » entre dans le graphe intérieur du stade de Krasnov (le serveur refuse les pièces inconnues).
-- 2. club_accessoire_acheter accepte la boutique de Krasnov comme celle de Novomirsk (patch en place, ancrage vérifié).
BEGIN;

UPDATE public.navigation_lieux_regles
   SET pieces = pieces || '["boutique"]'::jsonb
 WHERE pays = 'soviet' AND ville = 'ville_b' AND batiment = 'stade'
   AND jsonb_typeof(pieces) = 'array' AND NOT pieces @> '["boutique"]'::jsonb;

DO $krasnov$
DECLARE d text; avant text; apres text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
      WHERE pays = 'soviet' AND ville = 'ville_b' AND batiment = 'stade' AND pieces @> '["boutique"]'::jsonb)
  THEN RAISE EXCEPTION 'Krasnov : boutique absente du referentiel navigation'; END IF;

  d := pg_get_functiondef('public.club_accessoire_acheter(uuid, text, integer, integer)'::regprocedure);
  IF position('''ville_b''' IN d) = 0 THEN
    avant := 'a.current_city=''capitale'' AND a.current_room=''boutique''';
    apres := 'a.current_city IN (''capitale'',''ville_b'') AND a.current_room=''boutique''';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'club_accessoire_acheter : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
END $krasnov$;

COMMIT;
