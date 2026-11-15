-- Starovka : stand des accessoires séparé de la buvette, même moteur que Novomirsk/Krasnov.
-- Conversion des images et déclaration locale : data.js. Aucune modification des prix et inventaires.
BEGIN;
UPDATE public.navigation_lieux_regles SET pieces = pieces || '["boutique"]'::jsonb
WHERE pays='soviet' AND ville='ville_a' AND batiment='stade'
AND jsonb_typeof(pieces)='array' AND NOT pieces @> '["boutique"]'::jsonb;

DO $starovka$
DECLARE d text; avant text; apres text;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles
      WHERE pays='soviet' AND ville='ville_a' AND batiment='stade'
      AND pieces @> '["boutique"]'::jsonb) THEN
    RAISE EXCEPTION 'Stade de Starovka : boutique absente de la navigation serveur';
  END IF;
  d := pg_get_functiondef('public.club_accessoire_acheter(uuid,text,integer,integer)'::regprocedure);
  IF position('a.current_city IN (''capitale'',''ville_b'',''ville_a'') AND a.current_room=''boutique''' IN d) = 0 THEN
    avant := 'a.current_city IN (''capitale'',''ville_b'') AND a.current_room=''boutique''';
    apres := 'a.current_city IN (''capitale'',''ville_b'',''ville_a'') AND a.current_room=''boutique''';
    IF (length(d)-length(replace(d,avant,'')))/length(avant) <> 1 THEN
      RAISE EXCEPTION 'Fonction club_accessoire_acheter : garde de ville inattendue';
    END IF;
    EXECUTE replace(d,avant,apres);
  END IF;
END $starovka$;
COMMIT;
